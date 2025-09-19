variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "project_name" {
  description = "The name of the project (used for resource naming)"
  type        = string
  default     = "user-management"
}

variable "region" {
  description = "The GCP region"
  type        = string
  default     = "us-central1"
}

variable "zone" {
  description = "The GCP zone"
  type        = string
  default     = "us-central1-a"
}

variable "namespace" {
  description = "Kubernetes namespace for the user management microservice"
  type        = string
  default     = "user-management"
}

variable "app_image" {
  description = "Docker image for the user microservice"
  type        = string
  default     = "gcr.io/PROJECT_ID/user-management:latest"
}

variable "replicas" {
  description = "Number of replicas for the user microservice"
  type        = number
  default     = 2
}

# GKE Configuration
variable "gke_num_nodes" {
  description = "Number of GKE nodes"
  type        = number
  default     = 2
}

variable "gke_machine_type" {
  description = "Machine type for GKE nodes"
  type        = string
  default     = "e2-medium"
}

variable "gke_preemptible" {
  description = "Use preemptible instances for cost savings"
  type        = bool
  default     = false
}

# Database Configuration
variable "db_tier" {
  description = "The tier for the Cloud SQL instance"
  type        = string
  default     = "db-f1-micro"
}

variable "db_user" {
  description = "PostgreSQL username"
  type        = string
  default     = "postgres"
}

variable "db_password" {
  description = "PostgreSQL password"
  type        = string
  sensitive   = true
}

variable "db_name" {
  description = "PostgreSQL database name"
  type        = string
  default     = "users_db"
}

variable "db_deletion_protection" {
  description = "Enable deletion protection for the database"
  type        = bool
  default     = true
}

# Networking Configuration
variable "enable_ingress" {
  description = "Enable ingress for external access"
  type        = bool
  default     = true
}

variable "domain_name" {
  description = "Domain name for the ingress (must be owned and configured)"
  type        = string
  default     = "user-service.example.com"
}