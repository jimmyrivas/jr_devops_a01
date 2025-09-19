output "project_id" {
  description = "GCP project ID"
  value       = var.project_id
}

output "region" {
  description = "GCP region"
  value       = var.region
}

output "zone" {
  description = "GCP zone"
  value       = var.zone
}

output "kubernetes_cluster_name" {
  description = "GKE Cluster Name"
  value       = google_container_cluster.primary.name
}

output "kubernetes_cluster_host" {
  description = "GKE Cluster Host"
  value       = google_container_cluster.primary.endpoint
  sensitive   = true
}

output "artifact_registry_repository" {
  description = "Artifact Registry repository URL"
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.user_management_repo.repository_id}"
}

output "database_instance_name" {
  description = "The name of the database instance"
  value       = google_sql_database_instance.postgres.name
}

output "database_private_ip" {
  description = "The private IP address of the database instance"
  value       = google_sql_database_instance.postgres.private_ip_address
}

output "database_connection_name" {
  description = "The connection name of the database instance"
  value       = google_sql_database_instance.postgres.connection_name
}

output "load_balancer_ip" {
  description = "The external IP address of the load balancer"
  value       = var.enable_ingress ? google_compute_global_address.user_service_ip[0].address : "Not created"
}

output "service_url" {
  description = "The URL of the deployed service"
  value       = var.enable_ingress ? "https://${var.domain_name}" : "Ingress disabled"
}

output "namespace" {
  description = "The Kubernetes namespace where the microservice is deployed"
  value       = kubernetes_namespace.user_management.metadata[0].name
}

output "service_name" {
  description = "The name of the Kubernetes service"
  value       = kubernetes_service.user_service.metadata[0].name
}

# Instructions for connecting to the cluster
output "gke_connect_command" {
  description = "Command to connect to the GKE cluster"
  value       = "gcloud container clusters get-credentials ${google_container_cluster.primary.name} --zone ${var.zone} --project ${var.project_id}"
}

# Instructions for configuring Docker for Artifact Registry
output "docker_configure_command" {
  description = "Command to configure Docker for Artifact Registry"
  value       = "gcloud auth configure-docker ${var.region}-docker.pkg.dev"
}