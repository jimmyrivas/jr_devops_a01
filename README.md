# Microservicio de Gestión de Usuarios

**Autor**: Jimmy Rivas (jimmy.rivas.r@gmail.com)
**Asistente de Desarrollo**: Claude (Anthropic)
**Proyecto**: DevOps Evaluation A01
**Estado**: ✅ **COMPLETADO Y FUNCIONAL**

## 📋 Descripción del Proyecto

Microservicio completo de gestión de usuarios desarrollado con Node.js y PostgreSQL, desplegado en Kubernetes utilizando Terraform como Infrastructure as Code. El proyecto integra Harbor Registry para gestión de imágenes Docker y cumple con todos los requisitos de la evaluación DevOps.

### 🎯 Objetivos Cumplidos

- ✅ **Microservicio Node.js** con API REST completa
- ✅ **Base de datos PostgreSQL** con persistencia
- ✅ **Containerización** con Docker y Dockerfile optimizado
- ✅ **Orchestración** con Kubernetes y Helm
- ✅ **Infrastructure as Code** con Terraform
- ✅ **Container Registry** integrado con Harbor
- ✅ **Documentación completa** de despliegue y uso

## 🚀 Quick Start

### Opciones de Despliegue

#### 🏠 **Despliegue Local (Kubernetes + Harbor)**
```bash
# 1. Clonar y construir
git clone <repository>
cd jr_devops_a01
docker build -t user-management:latest .

# 2. Subir a Harbor
docker tag user-management:latest 192.168.240.43:30002/library/user-management:latest
docker push 192.168.240.43:30002/library/user-management:latest

# 3. Desplegar con Terraform
cd terraform
terraform init
terraform apply

# 4. Verificar despliegue
kubectl get all -n user-management
```

#### ☁️ **Despliegue en Google Cloud Platform (GCP)**
```bash
# 1. Configurar GCP
gcloud config set project your-project-id
gcloud auth login

# 2. Despliegue automatizado
PROJECT_ID=your-project-id DB_PASSWORD=secure-password ./deploy-scripts/deploy-gcp.sh

# 3. Verificar despliegue
gcloud container clusters get-credentials user-management-gke --zone us-central1-a
kubectl get all -n user-management
```

### Prerrequisitos

#### Para Despliegue Local
- Docker
- kubectl configurado
- Terraform >= 1.0
- Acceso a Harbor Registry (192.168.240.43:30002)

#### Para Despliegue en GCP
- Google Cloud SDK (gcloud)
- Terraform >= 1.5
- Docker
- Cuenta GCP con billing habilitado

## 🛠️ Stack Tecnológico

| Componente | Tecnología | Versión/Detalles |
|------------|------------|------------------|
| **Backend** | Node.js + Express | 18-alpine |
| **Base de Datos** | PostgreSQL | 15.4 (Helm Chart) |
| **Containerización** | Docker | Multi-stage build |
| **Orchestración** | Kubernetes | v1.31.8 |
| **IaC** | Terraform | Provider Kubernetes + Helm |
| **Registry** | Harbor | 192.168.240.43:30002 |
| **Ingress** | Traefik | user-service.local |

## 📁 Estructura del Proyecto

```
jr_devops_a01/
├── src/
│   └── app.js                 # Aplicación Node.js principal
├── terraform/                # Terraform para Kubernetes local
│   ├── main.tf               # Recursos de Kubernetes
│   ├── variables.tf          # Variables de configuración
│   └── outputs.tf            # Outputs del despliegue
├── gcp-terraform/            # Terraform para Google Cloud Platform
│   ├── main.tf               # Recursos GKE, Cloud SQL, Artifact Registry
│   ├── variables.tf          # Variables de configuración GCP
│   ├── outputs.tf            # Outputs del despliegue GCP
│   └── terraform.tfvars.example # Ejemplo de variables
├── deploy-scripts/           # Scripts de despliegue automatizado
│   └── deploy-gcp.sh         # Script de despliegue para GCP
├── k8s/
│   ├── namespace.yaml        # Namespace user-management
│   ├── postgres-*.yaml       # Despliegue de PostgreSQL
│   └── user-service-*.yaml   # Despliegue del microservicio
├── Dockerfile                # Imagen Docker optimizada
├── docker-compose.yml        # Stack para desarrollo local
├── cloudbuild.yaml           # Pipeline CI/CD para Cloud Build
├── package.json              # Dependencias Node.js
├── DEPLOYMENT.md             # Guía completa de despliegue local
├── GCP_DEPLOYMENT.md         # Guía completa de despliegue GCP
├── CICD_PIPELINE.md          # Documentación pipeline CI/CD
└── README.md                 # Este archivo
```

## 🔌 API Endpoints

| Método | Endpoint | Descripción | Ejemplo |
|--------|----------|-------------|---------|
| **GET** | `/health` | Health check | `curl http://user-service.local/health` |
| **POST** | `/users` | Crear usuario | `curl -X POST -H "Content-Type: application/json" -d '{"name":"Jimmy","email":"jimmy.rivas.r@gmail.com"}' http://user-service.local/users` |
| **GET** | `/users/:id` | Obtener usuario | `curl http://user-service.local/users/1` |
| **PUT** | `/users/:id` | Actualizar usuario | `curl -X PUT -H "Content-Type: application/json" -d '{"name":"Jimmy Updated","email":"new@email.com"}' http://user-service.local/users/1` |
| **DELETE** | `/users/:id` | Eliminar usuario | `curl -X DELETE http://user-service.local/users/1` |

## 🏗️ Arquitectura de Despliegue

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Harbor        │    │   Kubernetes    │    │   PostgreSQL    │
│   Registry      │    │   Cluster       │    │   Database      │
│                 │    │                 │    │                 │
│ 📦 Images       │───▶│ 🚀 Pods (2x)    │───▶│ 🗄️ Data        │
│ Versioning      │    │ Auto-scaling    │    │ Persistence     │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         ▲                       ▲                       ▲
         │                       │                       │
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Docker        │    │   Terraform     │    │   Helm          │
│   Build         │    │   IaC           │    │   Charts        │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## 🔧 Configuración de Desarrollo

### Desarrollo Local con Docker Compose
```bash
# Ejecutar stack completo localmente
docker-compose up -d

# Ver logs
docker-compose logs -f

# Limpiar
docker-compose down -v
```

### Variables de Entorno
```bash
# Microservicio
DB_HOST=postgresql-postgresql
DB_PORT=5432
DB_NAME=users_db
DB_USER=postgres
DB_PASSWORD=password
```

### Testing Local
```bash
# Health check
curl http://localhost:3000/health

# Crear usuario de prueba
curl -X POST http://localhost:3000/users \
  -H "Content-Type: application/json" \
  -d '{"name": "Test User", "email": "test@example.com"}'
```

## 🌐 Acceso a Servicios

### Producción (Kubernetes)
- **API**: http://user-service.local (configurar /etc/hosts)
- **Harbor Registry**: http://192.168.240.43:30002
- **Port-Forward**: `kubectl port-forward service/user-service 8080:80 -n user-management`

### Desarrollo (Docker Compose)
- **API**: http://localhost:3000
- **PostgreSQL**: localhost:5432

### GCP (Google Cloud Platform)
- **API**: https://your-domain.com (con SSL gestionado)
- **Load Balancer IP**: Obtenido con `kubectl get ingress -n user-management`
- **Cloud SQL**: Conexión privada desde GKE
- **Artifact Registry**: `us-central1-docker.pkg.dev/project-id/user-management-repo`

## 📊 Monitoreo y Logs

### Comandos Útiles
```bash
# Estado del despliegue
kubectl get all -n user-management

# Logs del microservicio
kubectl logs -f deployment/user-service -n user-management

# Logs de PostgreSQL
kubectl logs statefulset/postgresql -n user-management

# Eventos del namespace
kubectl get events -n user-management

# Métricas de recursos
kubectl top pods -n user-management
```

### Health Checks Configurados
- **Liveness Probe**: `/health` cada 10s (delay: 30s)
- **Readiness Probe**: `/health` cada 5s (delay: 5s)
- **Límites de Recursos**: CPU 500m, Memory 512Mi

## 🔒 Seguridad

### Medidas Implementadas
- ✅ **Secrets Management**: Credenciales de DB en Kubernetes Secrets
- ✅ **Non-root User**: Container ejecuta como usuario `node`
- ✅ **Resource Limits**: Límites de CPU y memoria configurados
- ✅ **Input Validation**: Validación con Joi para todos los endpoints
- ✅ **Error Handling**: Manejo seguro de errores sin exposición de datos

### Configuración de Seguridad
```bash
# Verificar configuración de seguridad
kubectl describe secret postgres-secret -n user-management
kubectl describe deployment user-service -n user-management | grep -A5 "Security Context"
```

## 🚀 Despliegue en Producción

### Checklist Pre-Despliegue
- [ ] Cluster Kubernetes disponible y configurado
- [ ] Harbor Registry accesible
- [ ] Terraform y kubectl instalados
- [ ] Variables de entorno configuradas
- [ ] Imagen construida y subida a Harbor

### Proceso de Despliegue
1. **Build & Push**: Construir imagen y subirla a Harbor
2. **Infrastructure**: Aplicar configuración de Terraform
3. **Verification**: Verificar que todos los pods estén Running
4. **Testing**: Ejecutar tests de API para confirmar funcionalidad
5. **Monitoring**: Configurar alertas y monitoreo

### Rollback
```bash
# Ver historial de deployments
kubectl rollout history deployment/user-service -n user-management

# Rollback a versión anterior
kubectl rollout undo deployment/user-service -n user-management
```

## 📝 Documentación Adicional

### 📖 Guías de Despliegue
- **[DEPLOYMENT.md](./DEPLOYMENT.md)**: Guía completa de despliegue local (Kubernetes + Harbor)
- **[GCP_DEPLOYMENT.md](./GCP_DEPLOYMENT.md)**: Guía completa de despliegue en Google Cloud Platform
- **[CICD_PIPELINE.md](./CICD_PIPELINE.md)**: Configuración y uso del pipeline CI/CD

### 🔧 Configuración
- **[CLAUDE.md](./CLAUDE.md)**: Configuración para Claude Code
- **[requerimientos.md](./requerimientos.md)**: Requisitos originales del proyecto

### 🚀 Opciones de Despliegue
1. **Local Development**: Docker Compose para desarrollo rápido
2. **Local Production**: Kubernetes + Harbor Registry + Terraform
3. **Cloud Production**: GCP con GKE + Cloud SQL + Artifact Registry + CI/CD

## 🤝 Contribución y Soporte

### Desarrollador Principal
**Jimmy Rivas**
📧 jimmy.rivas.r@gmail.com
🔗 [GitHub](https://github.com/jimmyrivas)

### Asistente de Desarrollo
**Claude (Anthropic)**
🤖 Asistente IA para desarrollo y documentación

### Reportar Issues
Para reportar problemas o solicitar mejoras:
1. Revisar la documentación en DEPLOYMENT.md
2. Verificar logs con comandos de troubleshooting
3. Contactar al desarrollador principal con detalles del problema

## 📜 Licencia

Este proyecto fue desarrollado como parte de una evaluación DevOps y está disponible para fines educativos y de evaluación.

---

**Estado del Proyecto**: ✅ Completado y desplegado exitosamente
**Última Actualización**: Septiembre 2025
**Desarrollado con**: Node.js, Docker, Kubernetes, Terraform, Harbor Registry
