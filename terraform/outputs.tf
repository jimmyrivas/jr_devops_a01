output "namespace" {
  description = "The namespace where the microservice is deployed"
  value       = kubernetes_namespace.user_management.metadata[0].name
}

output "service_name" {
  description = "The name of the user service"
  value       = kubernetes_service.user_service.metadata[0].name
}

output "ingress_host" {
  description = "The ingress host for external access"
  value       = var.enable_ingress ? var.ingress_host : "Ingress disabled"
}

output "postgres_service" {
  description = "PostgreSQL service name"
  value       = "${helm_release.postgresql.name}-postgresql"
}