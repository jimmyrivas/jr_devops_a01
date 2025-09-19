terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.11"
    }
  }
}

provider "kubernetes" {
  config_path = "~/.kube/config"
}

provider "helm" {
  kubernetes {
    config_path = "~/.kube/config"
  }
}

# Namespace for the user management microservice
resource "kubernetes_namespace" "user_management" {
  metadata {
    name = var.namespace
  }
}

# Secret for PostgreSQL credentials
resource "kubernetes_secret" "postgres_secret" {
  metadata {
    name      = "postgres-secret"
    namespace = kubernetes_namespace.user_management.metadata[0].name
  }

  data = {
    username = var.db_user
    password = var.db_password
    database = var.db_name
  }

  type = "Opaque"
}

# PostgreSQL deployment using Helm
resource "helm_release" "postgresql" {
  name       = "postgresql"
  repository = "https://charts.bitnami.com/bitnami"
  chart      = "postgresql"
  version    = "12.10.0"
  namespace  = kubernetes_namespace.user_management.metadata[0].name

  set {
    name  = "auth.postgresPassword"
    value = var.db_password
  }

  set {
    name  = "auth.database"
    value = var.db_name
  }

  set {
    name  = "primary.persistence.size"
    value = "1Gi"
  }
}

# ConfigMap for application configuration
resource "kubernetes_config_map" "app_config" {
  metadata {
    name      = "user-service-config"
    namespace = kubernetes_namespace.user_management.metadata[0].name
  }

  data = {
    DB_HOST = "${helm_release.postgresql.name}-postgresql"
    DB_PORT = "5432"
    DB_NAME = var.db_name
  }
}

# Deployment for the user microservice
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

  depends_on = [helm_release.postgresql]
}

# Service for the user microservice
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

# Ingress for external access
resource "kubernetes_ingress_v1" "user_service" {
  count = var.enable_ingress ? 1 : 0

  metadata {
    name      = "user-service-ingress"
    namespace = kubernetes_namespace.user_management.metadata[0].name
    annotations = {
      "kubernetes.io/ingress.class" = "traefik"
    }
  }

  spec {
    rule {
      host = var.ingress_host

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
}