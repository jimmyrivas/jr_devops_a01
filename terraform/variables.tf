variable "namespace" {
  description = "Kubernetes namespace for the user management microservice"
  type        = string
  default     = "user-management"
}

variable "app_image" {
  description = "Docker image for the user microservice"
  type        = string
  default     = "192.168.240.43:30002/library/user-management:latest"
}

variable "replicas" {
  description = "Number of replicas for the user microservice"
  type        = number
  default     = 2
}

variable "db_user" {
  description = "PostgreSQL username"
  type        = string
  default     = "postgres"
}

variable "db_password" {
  description = "PostgreSQL password"
  type        = string
  default     = "password"
  sensitive   = true
}

variable "db_name" {
  description = "PostgreSQL database name"
  type        = string
  default     = "users_db"
}

variable "enable_ingress" {
  description = "Enable ingress for external access"
  type        = bool
  default     = true
}

variable "ingress_host" {
  description = "Host for the ingress"
  type        = string
  default     = "user-service.local"
}