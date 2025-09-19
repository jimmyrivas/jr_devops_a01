terraform {
  required_version = ">= 1.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
  }
}

# Configure the Google Cloud Provider
provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}

# Data source for getting GKE cluster credentials
data "google_container_cluster" "primary" {
  name     = google_container_cluster.primary.name
  location = var.zone
  depends_on = [google_container_cluster.primary]
}

# Configure Kubernetes provider
provider "kubernetes" {
  host                   = "https://${data.google_container_cluster.primary.endpoint}"
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(data.google_container_cluster.primary.master_auth.0.cluster_ca_certificate)
}

# Get access token for authentication
data "google_client_config" "default" {}

# Enable required APIs
resource "google_project_service" "container_api" {
  service = "container.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "sql_api" {
  service = "sqladmin.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "artifactregistry_api" {
  service = "artifactregistry.googleapis.com"
  disable_on_destroy = false
}

# Create VPC network
resource "google_compute_network" "vpc_network" {
  name                    = "${var.project_name}-vpc"
  auto_create_subnetworks = false
}

# Create subnet
resource "google_compute_subnetwork" "subnet" {
  name          = "${var.project_name}-subnet"
  ip_cidr_range = "10.0.0.0/24"
  region        = var.region
  network       = google_compute_network.vpc_network.id

  secondary_ip_range {
    range_name    = "pods"
    ip_cidr_range = "10.1.0.0/16"
  }

  secondary_ip_range {
    range_name    = "services"
    ip_cidr_range = "10.2.0.0/16"
  }
}

# Create Artifact Registry repository
resource "google_artifact_registry_repository" "user_management_repo" {
  location      = var.region
  repository_id = "${var.project_name}-repo"
  description   = "Docker repository for user management microservice"
  format        = "DOCKER"

  depends_on = [google_project_service.artifactregistry_api]
}

# Create GKE cluster
resource "google_container_cluster" "primary" {
  name     = "${var.project_name}-gke"
  location = var.zone

  # We can't create a cluster with no node pool defined, but we want to only use
  # separately managed node pools. So we create the smallest possible default
  # node pool and immediately delete it.
  remove_default_node_pool = true
  initial_node_count       = 1

  network    = google_compute_network.vpc_network.name
  subnetwork = google_compute_subnetwork.subnet.name

  ip_allocation_policy {
    cluster_secondary_range_name  = "pods"
    services_secondary_range_name = "services"
  }

  # Enable network policy for security
  network_policy {
    enabled = true
  }

  # Enable workload identity
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  depends_on = [
    google_project_service.container_api,
    google_compute_subnetwork.subnet
  ]
}

# Create GKE node pool
resource "google_container_node_pool" "primary_nodes" {
  name       = "${var.project_name}-node-pool"
  location   = var.zone
  cluster    = google_container_cluster.primary.name
  node_count = var.gke_num_nodes

  node_config {
    preemptible  = var.gke_preemptible
    machine_type = var.gke_machine_type

    # Google recommends custom service accounts that have cloud-platform scope and permissions granted via IAM Roles.
    service_account = google_service_account.gke_service_account.email
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]

    # Enable workload identity
    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    tags = ["gke-node", "${var.project_name}-gke"]

    metadata = {
      disable-legacy-endpoints = "true"
    }
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  depends_on = [google_container_cluster.primary]
}

# Create service account for GKE nodes
resource "google_service_account" "gke_service_account" {
  account_id   = "${var.project_name}-gke-sa"
  display_name = "GKE Service Account for ${var.project_name}"
}

# Bind necessary roles to the service account
resource "google_project_iam_member" "gke_service_account_roles" {
  for_each = toset([
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
    "roles/monitoring.viewer",
    "roles/stackdriver.resourceMetadata.writer",
    "roles/artifactregistry.reader"
  ])

  project = var.project_id
  role    = each.value
  member  = "serviceAccount:${google_service_account.gke_service_account.email}"
}

# Create Cloud SQL instance
resource "google_sql_database_instance" "postgres" {
  name             = "${var.project_name}-postgres"
  database_version = "POSTGRES_15"
  region           = var.region

  settings {
    tier = var.db_tier

    ip_configuration {
      ipv4_enabled                                  = false
      private_network                               = google_compute_network.vpc_network.id
      enable_private_path_for_google_cloud_services = true
    }

    backup_configuration {
      enabled    = true
      start_time = "02:00"
    }

    maintenance_window {
      day  = 7
      hour = 3
    }

    database_flags {
      name  = "log_checkpoints"
      value = "on"
    }

    database_flags {
      name  = "log_connections"
      value = "on"
    }

    database_flags {
      name  = "log_disconnections"
      value = "on"
    }
  }

  deletion_protection = var.db_deletion_protection

  depends_on = [
    google_project_service.sql_api,
    google_service_networking_connection.private_vpc_connection
  ]
}

# Create private VPC connection for Cloud SQL
resource "google_compute_global_address" "private_ip_address" {
  name          = "${var.project_name}-private-ip"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.vpc_network.id
}

resource "google_service_networking_connection" "private_vpc_connection" {
  network                 = google_compute_network.vpc_network.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_address.name]
}

# Create database
resource "google_sql_database" "database" {
  name     = var.db_name
  instance = google_sql_database_instance.postgres.name
}

# Create database user
resource "google_sql_user" "user" {
  name     = var.db_user
  instance = google_sql_database_instance.postgres.name
  password = var.db_password
}

# Create Kubernetes namespace
resource "kubernetes_namespace" "user_management" {
  metadata {
    name = var.namespace
  }

  depends_on = [google_container_node_pool.primary_nodes]
}

# Create Kubernetes secret for database credentials
resource "kubernetes_secret" "postgres_secret" {
  metadata {
    name      = "postgres-secret"
    namespace = kubernetes_namespace.user_management.metadata[0].name
  }

  data = {
    username = var.db_user
    password = var.db_password
    database = var.db_name
    host     = google_sql_database_instance.postgres.private_ip_address
  }

  type = "Opaque"
}

# Create ConfigMap for application configuration
resource "kubernetes_config_map" "app_config" {
  metadata {
    name      = "user-service-config"
    namespace = kubernetes_namespace.user_management.metadata[0].name
  }

  data = {
    DB_HOST = google_sql_database_instance.postgres.private_ip_address
    DB_PORT = "5432"
    DB_NAME = var.db_name
  }
}

# Create Deployment for the user microservice
resource "kubernetes_deployment" "user_service" {
  metadata {
    name      = "user-service"
    namespace = kubernetes_namespace.user_management.metadata[0].name
    labels = {
      app = "user-service"
    }
  }

  spec {
    replicas = var.replicas

    selector {
      match_labels = {
        app = "user-service"
      }
    }

    template {
      metadata {
        labels = {
          app = "user-service"
        }
      }

      spec {
        container {
          image = var.app_image
          name  = "user-service"
          image_pull_policy = "Always"

          port {
            container_port = 3000
          }

          env_from {
            config_map_ref {
              name = kubernetes_config_map.app_config.metadata[0].name
            }
          }

          env {
            name = "DB_USER"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.postgres_secret.metadata[0].name
                key  = "username"
              }
            }
          }

          env {
            name = "DB_PASSWORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.postgres_secret.metadata[0].name
                key  = "password"
              }
            }
          }

          liveness_probe {
            http_get {
              path = "/health"
              port = 3000
            }
            initial_delay_seconds = 30
            period_seconds        = 10
          }

          readiness_probe {
            http_get {
              path = "/health"
              port = 3000
            }
            initial_delay_seconds = 5
            period_seconds        = 5
          }

          resources {
            limits = {
              cpu    = "500m"
              memory = "512Mi"
            }
            requests = {
              cpu    = "250m"
              memory = "256Mi"
            }
          }
        }
      }
    }
  }

  depends_on = [
    kubernetes_secret.postgres_secret,
    kubernetes_config_map.app_config
  ]
}

# Create Service for the user microservice
resource "kubernetes_service" "user_service" {
  metadata {
    name      = "user-service"
    namespace = kubernetes_namespace.user_management.metadata[0].name
  }

  spec {
    selector = {
      app = kubernetes_deployment.user_service.metadata[0].labels.app
    }

    port {
      port        = 80
      target_port = 3000
    }

    type = "ClusterIP"
  }
}

# Create Ingress for external access
resource "kubernetes_ingress_v1" "user_service" {
  count = var.enable_ingress ? 1 : 0

  metadata {
    name      = "user-service-ingress"
    namespace = kubernetes_namespace.user_management.metadata[0].name
    annotations = {
      "kubernetes.io/ingress.class"                = "gce"
      "kubernetes.io/ingress.global-static-ip-name" = google_compute_global_address.user_service_ip[0].name
      "networking.gke.io/managed-certificates"     = kubernetes_manifest.ssl_certificate[0].manifest.metadata.name
    }
  }

  spec {
    rule {
      host = var.domain_name

      http {
        path {
          path      = "/"
          path_type = "Prefix"

          backend {
            service {
              name = kubernetes_service.user_service.metadata[0].name
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }

  depends_on = [kubernetes_service.user_service]
}

# Create global static IP for the load balancer
resource "google_compute_global_address" "user_service_ip" {
  count = var.enable_ingress ? 1 : 0
  name  = "${var.project_name}-ip"
}

# Create managed SSL certificate
resource "kubernetes_manifest" "ssl_certificate" {
  count = var.enable_ingress ? 1 : 0

  manifest = {
    apiVersion = "networking.gke.io/v1"
    kind       = "ManagedCertificate"
    metadata = {
      name      = "user-service-ssl"
      namespace = kubernetes_namespace.user_management.metadata[0].name
    }
    spec = {
      domains = [var.domain_name]
    }
  }

  depends_on = [kubernetes_namespace.user_management]
}