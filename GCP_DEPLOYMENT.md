# Guía de Despliegue en Google Cloud Platform (GCP)

**Autor**: Jimmy Rivas (jimmy.rivas.r@gmail.com)
**Asistente IA**: Claude (Anthropic)
**Fecha**: Septiembre 2025

## Tabla de Contenidos

1. [Prerrequisitos](#prerrequisitos)
2. [Configuración del Proyecto GCP](#configuración-del-proyecto-gcp)
3. [Resumen de Infraestructura](#resumen-de-infraestructura)
4. [Despliegue Paso a Paso](#despliegue-paso-a-paso)
5. [Cambios de Configuración](#cambios-de-configuración)
6. [Monitoreo y Mantenimiento](#monitoreo-y-mantenimiento)
7. [Optimización de Costos](#optimización-de-costos)
8. [Solución de Problemas](#solución-de-problemas)

## Prerrequisitos

### Herramientas Requeridas
- **Google Cloud SDK (gcloud)**: Última versión
- **Terraform**: >= 1.5.0
- **Docker**: Para construcción local de imágenes
- **kubectl**: Para gestión de Kubernetes

### Servicios GCP a Habilitar
```bash
gcloud services enable \
  container.googleapis.com \
  sqladmin.googleapis.com \
  artifactregistry.googleapis.com \
  cloudbuild.googleapis.com \
  servicenetworking.googleapis.com
```

### Permisos Requeridos
Tu cuenta GCP necesita los siguientes roles IAM:
- **Editor de Proyecto** o **Propietario**
- **Administrador de Kubernetes Engine**
- **Administrador de Cloud SQL**
- **Administrador de Artifact Registry**
- **Editor de Cloud Build**

## Configuración del Proyecto GCP

### 1. Crear y Configurar Proyecto
```bash
# Crear nuevo proyecto (opcional)
gcloud projects create tu-project-id --name="Proyecto Gestión de Usuarios"

# Establecer proyecto actual
gcloud config set project tu-project-id

# Habilitar facturación (requerido para la mayoría de servicios)
# Nota: Esto debe hacerse a través de la Consola GCP
```

### 2. Configuración de Autenticación
```bash
# Autenticar con GCP
gcloud auth login

# Establecer credenciales por defecto de aplicación
gcloud auth application-default login

# Verificar autenticación
gcloud auth list
```

## Resumen de Infraestructura

### Componentes de Arquitectura

```
┌─────────────────────────────────────────────────────────────┐
│                  Google Cloud Platform                     │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐│
│  │   Cloud Build   │  │ Artifact Registry│  │  Load Balancer  ││
│  │   (CI/CD)       │  │  (Imágenes de   │  │   (Ingress)     ││
│  │                 │  │  Contenedores)  │  │                 ││
│  └─────────────────┘  └─────────────────┘  └─────────────────┘│
│           │                     │                     │       │
│           ▼                     ▼                     ▼       │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │              Google Kubernetes Engine (GKE)               ││
│  │  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────┐ ││
│  │  │ Servicio Usuario│  │   ConfigMaps    │  │   Secrets   │ ││
│  │  │   (Deployment)  │  │                 │  │             │ ││
│  │  └─────────────────┘  └─────────────────┘  └─────────────┘ ││
│  └─────────────────────────────────────────────────────────────┘│
│                              │                                 │
│                              ▼                                 │
│  ┌─────────────────────────────────────────────────────────────┐│
│  │                   Cloud SQL (PostgreSQL)                   ││
│  │                    Red Privada                             ││
│  └─────────────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────────────┘
```

### Especificaciones de Recursos

| Componente | Configuración | Propósito |
|-----------|---------------|-----------|
| **Cluster GKE** | 2 nodos, e2-medium | Orquestación de contenedores |
| **Cloud SQL** | db-f1-micro PostgreSQL | Base de datos backend |
| **Artifact Registry** | Repositorio Docker | Almacenamiento de imágenes de contenedores |
| **Load Balancer** | HTTP(S) Global | Acceso externo |
| **Cloud Build** | Pipeline CI/CD | Despliegue automatizado |

## Despliegue Paso a Paso

### Paso 1: Configuración de Variables de Entorno

Crear archivo de configuración de despliegue:

```bash
# Crear archivo de entorno de despliegue
cat > gcp-deploy.env <<EOF
# Configuración GCP
export PROJECT_ID="tu-gcp-project-id"
export REGION="us-central1"
export ZONE="us-central1-a"
export CLUSTER_NAME="user-management-gke"
export REPO_NAME="user-management-repo"

# Configuración Base de Datos
export DB_PASSWORD="tu-contraseña-segura"

# Configuración Aplicación
export DOMAIN_NAME="user-service.tudominio.com"  # Opcional
EOF

# Cargar variables de entorno
source gcp-deploy.env
```

### Paso 2: Script de Despliegue Automatizado

Usar el script de despliegue proporcionado:

```bash
# Hacer el script ejecutable
chmod +x deploy-scripts/deploy-gcp.sh

# Ejecutar despliegue
PROJECT_ID=$PROJECT_ID DB_PASSWORD=$DB_PASSWORD ./deploy-scripts/deploy-gcp.sh
```

### Paso 3: Proceso de Despliegue Manual

Si prefieres el despliegue manual:

#### 3.1 Construir y Subir Imagen de Contenedor

```bash
# Configurar Docker para Artifact Registry
gcloud auth configure-docker ${REGION}-docker.pkg.dev

# Construir y etiquetar imagen
docker build -t ${REGION}-docker.pkg.dev/${PROJECT_ID}/${REPO_NAME}/user-management:latest .

# Subir a Artifact Registry
docker push ${REGION}-docker.pkg.dev/${PROJECT_ID}/${REPO_NAME}/user-management:latest
```

#### 3.2 Desplegar Infraestructura con Terraform

```bash
# Navegar al directorio Terraform GCP
cd gcp-terraform

# Inicializar Terraform
terraform init

# Crear terraform.tfvars
cat > terraform.tfvars <<EOF
project_id   = "${PROJECT_ID}"
project_name = "user-management"
region       = "${REGION}"
zone         = "${ZONE}"
app_image    = "${REGION}-docker.pkg.dev/${PROJECT_ID}/${REPO_NAME}/user-management:latest"
db_password  = "${DB_PASSWORD}"
EOF

# Planificar despliegue
terraform plan

# Aplicar despliegue
terraform apply -auto-approve
```

#### 3.3 Configurar kubectl y Verificar Despliegue

```bash
# Obtener credenciales del cluster
gcloud container clusters get-credentials ${CLUSTER_NAME} --zone ${ZONE} --project ${PROJECT_ID}

# Verificar estado del despliegue
kubectl get pods -n user-management
kubectl get services -n user-management

# Esperar a que el despliegue esté listo
kubectl rollout status deployment/user-service -n user-management

# Verificar logs
kubectl logs deployment/user-service -n user-management
```

### Paso 4: Verificación de Salud y Validación

```bash
# Obtener IP externa (si ingress está habilitado)
kubectl get ingress -n user-management

# Port forward para pruebas (alternativa)
kubectl port-forward service/user-service 8080:80 -n user-management &

# Probar endpoint de salud
curl http://localhost:8080/health

# Probar endpoints de API
curl -X POST http://localhost:8080/users \
  -H "Content-Type: application/json" \
  -d '{"name":"Juan Pérez","email":"juan@ejemplo.com"}'
```

## Cambios de Configuración

### Cambios en la Aplicación para GCP

La aplicación ha sido actualizada para soportar Cloud SQL de GCP:

```javascript
// Conexión PostgreSQL mejorada con soporte para Cloud SQL
const pool = new Pool({
  host: process.env.DB_HOST || 'localhost',
  port: process.env.DB_PORT || 5432,
  database: process.env.DB_NAME || 'users_db',
  user: process.env.DB_USER || 'postgres',
  password: process.env.DB_PASSWORD || 'password',
  // Configuración de conexión GCP Cloud SQL
  ...(process.env.DB_SOCKET_PATH && {
    host: process.env.DB_SOCKET_PATH,
    ssl: false
  }),
  // Configuraciones de pool de conexiones para producción
  max: 20,
  idleTimeoutMillis: 30000,
  connectionTimeoutMillis: 2000,
});
```

### Archivos de Configuración Clave

| Archivo | Propósito | Cambios |
|---------|-----------|---------|
| `gcp-terraform/main.tf` | Infraestructura GCP | Configuración completa GKE + Cloud SQL |
| `gcp-terraform/variables.tf` | Variables de configuración | Parámetros específicos de GCP |
| `cloudbuild.yaml` | Pipeline CI/CD | Construcción y despliegue automatizado |
| `deploy-scripts/deploy-gcp.sh` | Automatización de despliegue | Despliegue extremo a extremo |
| `src/app.js` | Código de aplicación | Conectividad Cloud SQL |

### Variables de Entorno para GCP

```bash
# Conexión Base de Datos (establecida por Terraform)
DB_HOST=10.x.x.x  # IP privada de instancia Cloud SQL
DB_PORT=5432
DB_NAME=users_db
DB_USER=postgres
DB_PASSWORD=tu-contraseña-segura

# Configuración Aplicación
PORT=3000
NODE_ENV=production
```

## Monitoreo y Mantenimiento

### Configuración de Monitoreo GCP

```bash
# Habilitar APIs de monitoreo
gcloud services enable monitoring.googleapis.com
gcloud services enable logging.googleapis.com

# Ver logs
gcloud logging read "resource.type=k8s_container AND resource.labels.namespace_name=user-management"

# Monitorear recursos
gcloud compute instances list
gcloud sql instances list
gcloud container clusters list
```

### Comandos Útiles

```bash
# Conectar al cluster
gcloud container clusters get-credentials user-management-gke --zone us-central1-a --project tu-project-id

# Escalar despliegue
kubectl scale deployment user-service --replicas=3 -n user-management

# Actualizar despliegue
kubectl set image deployment/user-service user-service=nueva-imagen:tag -n user-management

# Verificar uso de recursos
kubectl top pods -n user-management
kubectl top nodes
```

### Respaldo y Recuperación

```bash
# Crear respaldo de Cloud SQL
gcloud sql backups create --instance=postgres-instance

# Listar respaldos
gcloud sql backups list --instance=postgres-instance

# Restaurar desde respaldo
gcloud sql backups restore BACKUP_ID --restore-instance=postgres-instance
```

## Optimización de Costos

### Optimización de Recursos

1. **Cluster GKE**:
   - Usar nodos preemptibles para desarrollo: `gke_preemptible = true`
   - Habilitar auto-escalado del cluster
   - Usar tipos de máquina apropiados

2. **Cloud SQL**:
   - Usar tier apropiado para la carga de trabajo
   - Habilitar respaldos automatizados con política de retención
   - Considerar réplicas de lectura para cargas pesadas de lectura

3. **Red**:
   - Usar discos persistentes regionales
   - Optimizar tráfico de salida

### Monitoreo de Costos

```bash
# Habilitar exportación de facturación
gcloud services enable bigquery.googleapis.com

# Monitorear costos
gcloud alpha billing budgets list
```

### Desarrollo vs Producción

```bash
# Entorno de desarrollo (optimizado para costos)
gke_num_nodes    = 1
gke_machine_type = "e2-micro"
gke_preemptible  = true
db_tier          = "db-f1-micro"

# Entorno de producción (optimizado para rendimiento)
gke_num_nodes    = 3
gke_machine_type = "e2-medium"
gke_preemptible  = false
db_tier          = "db-n1-standard-1"
```

## Solución de Problemas

### Problemas Comunes

#### 1. Errores ImagePullBackOff
```bash
# Verificar si la imagen existe en Artifact Registry
gcloud artifacts docker images list ${REGION}-docker.pkg.dev/${PROJECT_ID}/${REPO_NAME}

# Verificar autenticación
gcloud auth configure-docker ${REGION}-docker.pkg.dev

# Verificar eventos del pod
kubectl describe pod <nombre-pod> -n user-management
```

#### 2. Problemas de Conexión a Base de Datos
```bash
# Verificar estado de instancia Cloud SQL
gcloud sql instances describe postgres-instance

# Verificar conectividad de red
kubectl exec -it deployment/user-service -n user-management -- nc -zv $DB_HOST 5432

# Verificar logs de base de datos
gcloud sql instances describe postgres-instance --format="value(serverCaCert.instance)"
```

#### 3. Problemas de Descubrimiento de Servicios
```bash
# Verificar endpoints de servicios
kubectl get endpoints -n user-management

# Verificar resolución DNS
kubectl exec -it deployment/user-service -n user-management -- nslookup user-service.user-management.svc.cluster.local
```

#### 4. Problemas de Ingress y Load Balancer
```bash
# Verificar estado de ingress
kubectl describe ingress user-service-ingress -n user-management

# Verificar asignación de IP externa
kubectl get ingress -n user-management

# Verificar estado de certificado SSL (si usa certificados gestionados)
gcloud compute ssl-certificates describe user-service-ssl --global
```

### Comandos de Depuración

```bash
# Obtener información completa del cluster
kubectl cluster-info
kubectl get all -n user-management

# Verificar cuotas de recursos
kubectl describe quota -n user-management

# Ver eventos del cluster
kubectl get events --sort-by=.metadata.creationTimestamp -n user-management

# Depurar red
kubectl exec -it deployment/user-service -n user-management -- /bin/sh
```

### Ajuste de Rendimiento

```bash
# Verificar uso de recursos
kubectl top pods -n user-management
kubectl describe hpa -n user-management

# Monitorear métricas de aplicación
kubectl exec -it deployment/user-service -n user-management -- curl localhost:3000/health

# Rendimiento de base de datos
gcloud sql instances describe postgres-instance --format="table(settings.tier,settings.dataDiskSizeGb,settings.dataDiskType)"
```

## Consideraciones de Seguridad

### Seguridad de Red
- Cluster GKE privado con redes autorizadas
- Cloud SQL solo con IP privada
- Red nativa VPC
- Políticas de red para comunicación pod-a-pod

### Gestión de Identidad y Acceso
- Workload Identity para pods GKE
- Cuentas de servicio con permisos mínimos
- Gestión de secretos con Google Secret Manager

### Protección de Datos
- Cifrado en reposo para Cloud SQL
- Cifrado en tránsito con TLS
- Actualizaciones regulares de seguridad para imágenes base

## Migración de Local a GCP

### Migración de Datos
```bash
# Exportar datos de PostgreSQL local
pg_dump -h localhost -U postgres users_db > users_backup.sql

# Importar a Cloud SQL
gcloud sql import sql postgres-instance gs://tu-bucket/users_backup.sql --database=users_db
```

### Configuración DNS y Dominio
```bash
# Actualizar registros DNS para apuntar al Load Balancer GCP
# Obtener IP externa
kubectl get ingress user-service-ingress -n user-management -o jsonpath='{.status.loadBalancer.ingress[0].ip}'

# Configurar registro A: user-service.tudominio.com -> IP_EXTERNA
```

### Configuración de Integración Continua
```bash
# Conectar repositorio a Cloud Build
gcloud builds triggers create github \
  --repo-name=tu-repo \
  --repo-owner=tu-usuario \
  --branch-pattern="^main$" \
  --build-config=cloudbuild.yaml
```

## Próximos Pasos

1. **Configurar monitoreo y alertas** usando Google Cloud Monitoring
2. **Configurar respaldos automatizados** para Cloud SQL
3. **Implementar logging apropiado** con logs estructurados
4. **Configurar entorno de desarrollo** con proyecto GCP separado
5. **Configurar dominio y certificados SSL** para acceso en producción
6. **Implementar auto-escalado horizontal de pods** basado en métricas
7. **Configurar procedimientos de recuperación ante desastres**

## Recursos Adicionales

- [Documentación Google Kubernetes Engine](https://cloud.google.com/kubernetes-engine/docs)
- [Cloud SQL para PostgreSQL](https://cloud.google.com/sql/docs/postgres)
- [Documentación Artifact Registry](https://cloud.google.com/artifact-registry/docs)
- [Documentación Cloud Build](https://cloud.google.com/build/docs)
- [Proveedor Terraform Google Cloud](https://registry.terraform.io/providers/hashicorp/google/latest)

---

**Autor**: Jimmy Rivas (jimmy.rivas.r@gmail.com)
**Asistente IA**: Claude (Anthropic)
**Última Actualización**: Septiembre 2025