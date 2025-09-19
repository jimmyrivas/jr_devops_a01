# Terraform Infrastructure - User Management Microservice

**Autor**: Jimmy Rivas (jimmy.rivas.r@gmail.com)
**Asistente de Desarrollo**: Claude (Anthropic)
**Terraform Version**: >= 1.0
**Providers**: Kubernetes, Helm

## 📋 Resumen

Este directorio contiene la configuración de Terraform para desplegar el microservicio de gestión de usuarios en Kubernetes. La infraestructura incluye PostgreSQL (via Helm), el microservicio containerizado, servicios, ingress y toda la configuración necesaria para un despliegue completo.

## 🏗️ Arquitectura de la Infraestructura

```
┌─────────────────────────────────────────────────────────┐
│                    Kubernetes Cluster                   │
├─────────────────────────────────────────────────────────┤
│  Namespace: user-management                             │
│                                                         │
│  ┌─────────────────┐  ┌─────────────────┐              │
│  │   PostgreSQL    │  │  User Service   │              │
│  │   StatefulSet   │  │   Deployment    │              │
│  │   (Helm Chart)  │  │   (2 replicas)  │              │
│  └─────────────────┘  └─────────────────┘              │
│           │                     │                       │
│  ┌─────────────────┐  ┌─────────────────┐              │
│  │  PostgreSQL     │  │  User Service   │              │
│  │   Service       │  │    Service      │              │
│  └─────────────────┘  └─────────────────┘              │
│                               │                         │
│                    ┌─────────────────┐                 │
│                    │     Ingress     │                 │
│                    │   (Traefik)     │                 │
│                    └─────────────────┘                 │
└─────────────────────────────────────────────────────────┘
```

## 📁 Estructura de Archivos

```
terraform/
├── main.tf           # Recursos principales de Kubernetes
├── variables.tf      # Variables de configuración
├── outputs.tf        # Outputs del despliegue
└── README.md         # Esta documentación
```

## 🚀 Quick Start

### 1. Prerrequisitos
```bash
# Verificar Terraform
terraform version

# Verificar kubectl
kubectl cluster-info

# Verificar Helm
helm version

# Verificar Harbor Registry
curl -k http://192.168.240.43:30002/api/v2.0/health
```

### 2. Inicialización
```bash
cd terraform
terraform init
```

### 3. Planificación
```bash
terraform plan
```

### 4. Aplicación
```bash
terraform apply
```

### 5. Verificación
```bash
kubectl get all -n user-management
```

## 🔧 Variables de Configuración

### Variables Principales

| Variable | Tipo | Default | Descripción |
|----------|------|---------|-------------|
| `namespace` | string | `"user-management"` | Namespace de Kubernetes |
| `app_image` | string | `"192.168.240.43:30002/library/user-management:latest"` | Imagen del microservicio |
| `replicas` | number | `2` | Número de réplicas del microservicio |
| `db_user` | string | `"postgres"` | Usuario de PostgreSQL |
| `db_password` | string | `"password"` | Contraseña de PostgreSQL (sensitive) |
| `db_name` | string | `"users_db"` | Nombre de la base de datos |
| `enable_ingress` | bool | `true` | Habilitar ingress para acceso externo |
| `ingress_host` | string | `"user-service.local"` | Host del ingress |

### Personalización con terraform.tfvars

```hcl
# terraform.tfvars
namespace = "mi-namespace"
replicas = 3
db_password = "mi_password_super_seguro"
ingress_host = "usuarios.midominio.com"
enable_ingress = true
```

### Variables de Entorno
```bash
# Configurar variables sensibles
export TF_VAR_db_password="mi_password_seguro"

# Aplicar con variables de entorno
terraform apply
```

## 📦 Recursos Creados

### 1. Namespace
```hcl
resource "kubernetes_namespace" "user_management" {
  metadata {
    name = var.namespace
  }
}
```

### 2. PostgreSQL (Helm Chart)
```hcl
resource "helm_release" "postgresql" {
  name       = "postgresql"
  repository = "https://charts.bitnami.com/bitnami"
  chart      = "postgresql"
  version    = "12.10.0"
  namespace  = kubernetes_namespace.user_management.metadata[0].name
}
```

### 3. Secrets Management
```hcl
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
}
```

### 4. ConfigMap
```hcl
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
```

### 5. Deployment del Microservicio
```hcl
resource "kubernetes_deployment" "user_service" {
  metadata {
    name      = "user-service"
    namespace = kubernetes_namespace.user_management.metadata[0].name
  }

  spec {
    replicas = var.replicas
    # ... configuración completa del deployment
  }
}
```

### 6. Service
```hcl
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
  }
}
```

### 7. Ingress (Opcional)
```hcl
resource "kubernetes_ingress_v1" "user_service" {
  count = var.enable_ingress ? 1 : 0

  metadata {
    name      = "user-service-ingress"
    namespace = kubernetes_namespace.user_management.metadata[0].name
    annotations = {
      "kubernetes.io/ingress.class" = "traefik"
    }
  }
  # ... configuración del ingress
}
```

## 🔍 Outputs

```hcl
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
```

## 🛠️ Operaciones Comunes

### Actualizar Imagen del Microservicio
```bash
# Opción 1: Modificar variables.tf y aplicar
terraform apply

# Opción 2: Override con variable
terraform apply -var="app_image=192.168.240.43:30002/library/user-management:v2.0"
```

### Escalar Replicas
```bash
terraform apply -var="replicas=5"
```

### Cambiar Host del Ingress
```bash
terraform apply -var="ingress_host=api.midominio.com"
```

### Deshabilitar Ingress
```bash
terraform apply -var="enable_ingress=false"
```

## 🔒 Consideraciones de Seguridad

### Secrets Management
- Las contraseñas se manejan como variables sensibles
- Los secrets de Kubernetes se crean automáticamente
- No se exponen credenciales en logs de Terraform

### Configuración Segura
```hcl
variable "db_password" {
  description = "PostgreSQL password"
  type        = string
  default     = "password"
  sensitive   = true  # Marca como sensible
}
```

### Buenas Prácticas
- Usar variables de entorno para secrets
- No commitear archivos terraform.tfvars con credenciales
- Usar backend remoto para el estado de Terraform
- Implementar RBAC en Kubernetes

## 📊 Monitoreo y Logging

### Health Checks Configurados
```hcl
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
```

### Resource Limits
```hcl
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
```

## 🔧 Troubleshooting

### Verificar Estado de Terraform
```bash
# Ver estado actual
terraform show

# Ver recursos creados
terraform state list

# Obtener información específica
terraform state show kubernetes_deployment.user_service
```

### Problemas Comunes

#### 1. Error de Conexión a Kubernetes
```bash
# Verificar conectividad
kubectl cluster-info

# Verificar contexto
kubectl config current-context

# Listar contextos disponibles
kubectl config get-contexts
```

#### 2. Error de Helm Chart
```bash
# Verificar repositorios de Helm
helm repo list

# Actualizar repositorios
helm repo update

# Verificar chart específico
helm search repo postgresql
```

#### 3. Error de Imagen en Harbor
```bash
# Verificar imagen en Harbor
docker pull 192.168.240.43:30002/library/user-management:latest

# Verificar conectividad a Harbor
curl -k http://192.168.240.43:30002/api/v2.0/health
```

### Comandos de Diagnóstico
```bash
# Logs de Terraform
export TF_LOG=DEBUG
terraform apply

# Verificar recursos en Kubernetes
kubectl get all -n user-management
kubectl describe deployment user-service -n user-management
kubectl get events -n user-management

# Verificar configuración
kubectl describe configmap user-service-config -n user-management
kubectl describe secret postgres-secret -n user-management
```

## 🗑️ Limpieza

### Destruir Infraestructura Completa
```bash
terraform destroy
```

### Destruir Recursos Específicos
```bash
# Destruir solo el ingress
terraform destroy -target=kubernetes_ingress_v1.user_service

# Destruir solo el deployment
terraform destroy -target=kubernetes_deployment.user_service
```

### Verificar Limpieza
```bash
# Verificar que el namespace fue eliminado
kubectl get namespaces | grep user-management

# Verificar que no quedan recursos
kubectl get all -n user-management
```

## 🔄 Actualizaciones y Versionado

### Actualizar Providers
```bash
# Actualizar providers
terraform init -upgrade

# Verificar versiones
terraform version
```

### Versionado de Infraestructura
```hcl
terraform {
  required_version = ">= 1.0"

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
```

## 🚀 CI/CD Integration

### GitHub Actions Example
```yaml
name: Deploy Infrastructure
on:
  push:
    branches: [main]
    paths: ['terraform/**']

jobs:
  terraform:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: hashicorp/setup-terraform@v2
      - name: Terraform Init
        run: terraform init
        working-directory: ./terraform
      - name: Terraform Plan
        run: terraform plan
        working-directory: ./terraform
      - name: Terraform Apply
        run: terraform apply -auto-approve
        working-directory: ./terraform
        env:
          TF_VAR_db_password: ${{ secrets.DB_PASSWORD }}
```

### Pipeline Checklist
- [ ] Validar sintaxis de Terraform
- [ ] Ejecutar plan y revisar cambios
- [ ] Aplicar solo después de aprobación
- [ ] Verificar deployment en Kubernetes
- [ ] Ejecutar tests de la API
- [ ] Notificar resultado del deployment

## 📞 Soporte

**Desarrollador**: Jimmy Rivas
**Email**: jimmy.rivas.r@gmail.com
**Asistente de Desarrollo**: Claude (Anthropic)

Para consultas sobre la infraestructura de Terraform o problemas de despliegue, contactar al desarrollador principal.

## 📚 Referencias

- [Terraform Kubernetes Provider](https://registry.terraform.io/providers/hashicorp/kubernetes/latest/docs)
- [Terraform Helm Provider](https://registry.terraform.io/providers/hashicorp/helm/latest/docs)
- [Bitnami PostgreSQL Helm Chart](https://github.com/bitnami/charts/tree/main/bitnami/postgresql)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Harbor Registry Documentation](https://goharbor.io/docs/)