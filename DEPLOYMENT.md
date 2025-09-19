# Guía de Despliegue - Microservicio de Gestión de Usuarios

**Autor**: Jimmy Rivas (jimmy.rivas.r@gmail.com)
**Asistente IA**: Claude (Anthropic)
**Fecha**: Septiembre 2025

## Resumen del Proyecto

Microservicio de gestión de usuarios desarrollado con Node.js, PostgreSQL y desplegado en Kubernetes usando Terraform. Integra Harbor Registry para gestión de imágenes Docker.

## Prerrequisitos

### Software Requerido
- Docker
- kubectl (configurado con cluster Kubernetes)
- Terraform >= 1.0
- Helm >= 3.0
- Acceso a Harbor Registry (192.168.240.43:30002)

### Verificación del Entorno
```bash
# Verificar cluster Kubernetes
kubectl cluster-info

# Verificar Harbor Registry
curl -k http://192.168.240.43:30002/api/v2.0/health

# Verificar Terraform
terraform version
```

## Construcción y Registro de Imagen

### 1. Construcción de la Imagen Docker
```bash
# Navegar al directorio del proyecto
cd /path/to/jr_devops_a01

# Construir la imagen
docker build -t user-management:latest .

# Verificar construcción
docker images | grep user-management
```

### 2. Configuración de Harbor Registry
```bash
# Login a Harbor (credenciales: admin/password)
docker login 192.168.240.43:30002

# Etiquetar imagen para Harbor
docker tag user-management:latest 192.168.240.43:30002/library/user-management:latest

# Subir imagen a Harbor
docker push 192.168.240.43:30002/library/user-management:latest
```

### 3. Verificación en Harbor
- Acceder a Harbor UI: http://192.168.240.43:30002
- Navegar a Projects → library → user-management
- Verificar que la imagen aparece con tag `latest`

## Despliegue con Terraform (Recomendado)

### 1. Inicialización de Terraform
```bash
cd terraform
terraform init

# Verificar configuración
terraform validate
```

### 2. Revisión del Plan de Despliegue
```bash
terraform plan

# Salida esperada:
# Plan: 7 to add, 0 to change, 0 to destroy
```

### 3. Aplicación del Despliegue
```bash
terraform apply

# Confirmar con 'yes' cuando se solicite
```

### 4. Verificación del Despliegue
```bash
# Verificar recursos creados
kubectl get all -n user-management

# Verificar pods en estado Running
kubectl get pods -n user-management

# Verificar logs del microservicio
kubectl logs deployment/user-service -n user-management
```

## Configuración y Variables

### Variables de Terraform
Archivo: `terraform/variables.tf`

| Variable | Valor por Defecto | Descripción |
|----------|-------------------|-------------|
| `namespace` | `user-management` | Namespace de Kubernetes |
| `app_image` | `192.168.240.43:30002/library/user-management:latest` | Imagen del microservicio |
| `replicas` | `2` | Número de réplicas |
| `db_password` | `password` | Contraseña de PostgreSQL |
| `ingress_host` | `user-service.local` | Host del ingress |

### Personalización de Variables
```bash
# Crear archivo terraform.tfvars
cat > terraform/terraform.tfvars << EOF
namespace = "user-management"
replicas = 3
db_password = "mi_password_seguro"
ingress_host = "usuarios.midominio.com"
EOF

# Aplicar con variables personalizadas
terraform apply -var-file="terraform.tfvars"
```

## Despliegue Manual con kubectl (Alternativo)

### 1. Aplicar Manifiestos Kubernetes
```bash
# Crear namespace
kubectl apply -f k8s/namespace.yaml

# Desplegar PostgreSQL
kubectl apply -f k8s/postgres-secret.yaml
kubectl apply -f k8s/postgres-deployment.yaml

# Desplegar microservicio
kubectl apply -f k8s/user-service-deployment.yaml
```

### 2. Verificación Manual
```bash
kubectl get all -n user-management
kubectl describe deployment user-service -n user-management
```

## Configuración de Acceso

### 1. Configuración de Ingress
```bash
# Agregar host al archivo /etc/hosts
echo "192.168.240.43 user-service.local" | sudo tee -a /etc/hosts
```

### 2. Acceso via Port-Forward (Alternativo)
```bash
# Port-forward del servicio
kubectl port-forward service/user-service 8080:80 -n user-management

# El servicio estará disponible en http://localhost:8080
```

## Testing de la API

### 1. Health Check
```bash
# Via ingress
curl http://user-service.local/health

# Via port-forward
curl http://localhost:8080/health

# Respuesta esperada:
# {"status":"OK","timestamp":"2025-09-19T..."}
```

### 2. Operaciones CRUD de Usuarios

#### Crear Usuario
```bash
curl -X POST http://user-service.local/users \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Jimmy Rivas",
    "email": "jimmy.rivas.r@gmail.com"
  }'

# Respuesta esperada:
# {"id":1,"name":"Jimmy Rivas","email":"jimmy.rivas.r@gmail.com","created_at":"..."}
```

#### Obtener Usuario
```bash
curl http://user-service.local/users/1

# Respuesta esperada:
# {"id":1,"name":"Jimmy Rivas","email":"jimmy.rivas.r@gmail.com","created_at":"..."}
```

#### Actualizar Usuario
```bash
curl -X PUT http://user-service.local/users/1 \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Jimmy Rivas Updated",
    "email": "jimmy.rivas.updated@gmail.com"
  }'
```

#### Eliminar Usuario
```bash
curl -X DELETE http://user-service.local/users/1

# Respuesta esperada:
# {"message":"User deleted successfully"}
```

## Monitoreo y Logs

### 1. Logs del Microservicio
```bash
# Logs en tiempo real
kubectl logs -f deployment/user-service -n user-management

# Logs de un pod específico
kubectl logs user-service-xxxx-yyyy -n user-management
```

### 2. Logs de PostgreSQL
```bash
kubectl logs statefulset/postgresql -n user-management
```

### 3. Estado de los Recursos
```bash
# Estado general
kubectl get all -n user-management

# Eventos del namespace
kubectl get events -n user-management

# Descripción detallada de pods
kubectl describe pods -n user-management
```

## Troubleshooting

### Problemas Comunes

#### 1. ImagePullBackOff
```bash
# Verificar imagen en Harbor
docker pull 192.168.240.43:30002/library/user-management:latest

# Verificar configuración del deployment
kubectl describe deployment user-service -n user-management
```

#### 2. Error de Conexión a Base de Datos
```bash
# Verificar PostgreSQL
kubectl get pods -n user-management | grep postgresql

# Verificar configuración de conexión
kubectl describe configmap user-service-config -n user-management

# Verificar secretos
kubectl describe secret postgres-secret -n user-management
```

#### 3. Problemas de Red/Ingress
```bash
# Verificar ingress
kubectl get ingress -n user-management

# Test directo al servicio
kubectl exec -it deployment/user-service -n user-management -- curl localhost:3000/health
```

### Comandos de Diagnóstico
```bash
# Información completa del cluster
kubectl cluster-info dump

# Recursos por namespace
kubectl get all --all-namespaces

# Logs del sistema
kubectl logs -n kube-system deployment/coredns
```

## Limpieza y Rollback

### 1. Eliminar Despliegue Completo
```bash
# Con Terraform
cd terraform
terraform destroy

# Con kubectl
kubectl delete namespace user-management
```

### 2. Rollback a Versión Anterior
```bash
# Ver historial de deployments
kubectl rollout history deployment/user-service -n user-management

# Rollback a versión anterior
kubectl rollout undo deployment/user-service -n user-management
```

### 3. Actualización de Imagen
```bash
# Actualizar imagen en deployment
kubectl set image deployment/user-service user-service=192.168.240.43:30002/library/user-management:v2.0 -n user-management

# Verificar estado del rollout
kubectl rollout status deployment/user-service -n user-management
```

## Información Técnica

### Arquitectura del Sistema
```
[Internet] → [Ingress] → [Service] → [Pods] → [PostgreSQL]
                              ↓
                         [Harbor Registry]
```

### Recursos Kubernetes Creados
- **Namespace**: user-management
- **StatefulSet**: postgresql (1 réplica)
- **Deployment**: user-service (2 réplicas)
- **Services**: postgresql, user-service
- **ConfigMap**: user-service-config
- **Secret**: postgres-secret
- **Ingress**: user-service-ingress
- **PVC**: PostgreSQL data storage

### Endpoints de la API
| Método | Endpoint | Descripción |
|--------|----------|-------------|
| GET | `/health` | Health check del servicio |
| POST | `/users` | Crear nuevo usuario |
| GET | `/users/:id` | Obtener usuario por ID |
| PUT | `/users/:id` | Actualizar usuario existente |
| DELETE | `/users/:id` | Eliminar usuario |

## Contacto y Soporte

**Desarrollador**: Jimmy Rivas
**Email**: jimmy.rivas.r@gmail.com
**Asistente de Desarrollo**: Claude (Anthropic)

Para reportar problemas o solicitar mejoras, contactar al desarrollador principal.