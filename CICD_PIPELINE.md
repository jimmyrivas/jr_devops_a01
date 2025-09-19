# Documentación Pipeline CI/CD

**Autor**: Jimmy Rivas (jimmy.rivas.r@gmail.com)
**Asistente IA**: Claude (Anthropic)
**Fecha**: Septiembre 2025

## Resumen

Este documento describe el pipeline de Integración Continua y Despliegue Continuo (CI/CD) para el Microservicio de Gestión de Usuarios usando Google Cloud Build.

## Arquitectura del Pipeline

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│  Repositorio    │───▶│  Cloud Build    │───▶│  Cluster GKE    │
│   GitHub        │    │   (CI/CD)       │    │                 │
│                 │    │                 │    │                 │
│ - Código Fuente │    │ - Construir     │    │ - Desplegar     │
│ - Dockerfile    │    │   Imagen        │    │   Pods          │
│ - cloudbuild.yml│    │ - Ejecutar      │    │ - Health Checks │
│                 │    │   Pruebas       │    │ - Rolling       │
│                 │    │ - Subir Registry│    │   Update        │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                               │
                               ▼
                       ┌─────────────────┐
                       │ Artifact Registry│
                       │                 │
                       │ - Imágenes      │
                       │   Docker        │
                       │ - Etiquetas de  │
                       │   Versión       │
                       │ - Escaneo de    │
                       │   Seguridad     │
                       └─────────────────┘
```

## Configuración de Cloud Build

### Pasos del Pipeline

El archivo `cloudbuild.yaml` define los siguientes pasos:

1. **Construir Imagen Docker**: Crear contenedor de aplicación
2. **Subir al Registry**: Almacenar en Artifact Registry
3. **Desplegar con Terraform**: Actualizar infraestructura GKE
4. **Esperar Despliegue**: Asegurar que los pods estén listos
5. **Verificación de Salud**: Validar funcionalidad del servicio

### Análisis del Archivo de Configuración

```yaml
# cloudbuild.yaml
steps:
  # Paso 1: Construir la imagen Docker
  - name: 'gcr.io/cloud-builders/docker'
    args:
      - 'build'
      - '-t'
      - '${_REGION}-docker.pkg.dev/${PROJECT_ID}/${_REPO_NAME}/user-management:${COMMIT_SHA}'
      - '-t'
      - '${_REGION}-docker.pkg.dev/${PROJECT_ID}/${_REPO_NAME}/user-management:latest'
      - '.'
    id: 'build-image'

  # Paso 2: Subir a Artifact Registry
  - name: 'gcr.io/cloud-builders/docker'
    args:
      - 'push'
      - '--all-tags'
      - '${_REGION}-docker.pkg.dev/${PROJECT_ID}/${_REPO_NAME}/user-management'
    id: 'push-image'
    waitFor: ['build-image']

  # Paso 3: Desplegar a GKE usando Terraform
  - name: 'hashicorp/terraform:1.5'
    entrypoint: 'sh'
    args:
      - '-c'
      - |
        cd gcp-terraform
        terraform init
        terraform plan -var="project_id=${PROJECT_ID}" -var="app_image=${_REGION}-docker.pkg.dev/${PROJECT_ID}/${_REPO_NAME}/user-management:${COMMIT_SHA}"
        terraform apply -auto-approve -var="project_id=${PROJECT_ID}" -var="app_image=${_REGION}-docker.pkg.dev/${PROJECT_ID}/${_REPO_NAME}/user-management:${COMMIT_SHA}"
    id: 'deploy-terraform'
    waitFor: ['push-image']
    env:
      - 'TF_VAR_db_password=${_DB_PASSWORD}'

  # Paso 4: Esperar que el despliegue esté listo
  - name: 'gcr.io/cloud-builders/kubectl'
    args:
      - 'rollout'
      - 'status'
      - 'deployment/user-service'
      - '-n'
      - 'user-management'
    env:
      - 'CLOUDSDK_COMPUTE_ZONE=${_ZONE}'
      - 'CLOUDSDK_CONTAINER_CLUSTER=${_CLUSTER_NAME}'
    id: 'wait-deployment'
    waitFor: ['deploy-terraform']

  # Paso 5: Verificación de salud
  - name: 'gcr.io/cloud-builders/curl'
    args:
      - '-f'
      - 'http://user-service.user-management.svc.cluster.local/health'
    id: 'health-check'
    waitFor: ['wait-deployment']
```

## Configuración del Pipeline

### 1. Prerrequisitos

```bash
# Habilitar APIs requeridas
gcloud services enable cloudbuild.googleapis.com
gcloud services enable sourcerepo.googleapis.com
gcloud services enable containeranalysis.googleapis.com

# Otorgar permisos a Cloud Build
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:$(gcloud projects describe $PROJECT_ID --format='value(projectNumber)')@cloudbuild.gserviceaccount.com" \
  --role="roles/container.developer"

gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:$(gcloud projects describe $PROJECT_ID --format='value(projectNumber)')@cloudbuild.gserviceaccount.com" \
  --role="roles/editor"
```

### 2. Crear Trigger de Build

#### Creación Manual de Trigger
```bash
# Crear trigger para rama main
gcloud builds triggers create github \
  --repo-name=jr_devops_a01 \
  --repo-owner=tu-usuario-github \
  --branch-pattern="^main$" \
  --build-config=cloudbuild.yaml \
  --substitutions=_REGION=us-central1,_ZONE=us-central1-a,_REPO_NAME=user-management-repo,_CLUSTER_NAME=user-management-gke,_DB_PASSWORD=tu-contraseña-segura
```

#### Usando Cloud Console
1. Ir a Cloud Build > Triggers
2. Hacer clic en "Crear Trigger"
3. Seleccionar "GitHub" como fuente
4. Conectar tu repositorio
5. Configurar patrón de rama: `^main$`
6. Establecer archivo de configuración de build: `cloudbuild.yaml`
7. Agregar variables de sustitución

### 3. Variables de Sustitución

| Variable | Descripción | Valor de Ejemplo |
|----------|-------------|------------------|
| `_REGION` | Región GCP | `us-central1` |
| `_ZONE` | Zona GCP | `us-central1-a` |
| `_REPO_NAME` | Repositorio Artifact Registry | `user-management-repo` |
| `_CLUSTER_NAME` | Nombre del cluster GKE | `user-management-gke` |
| `_DB_PASSWORD` | Contraseña de base de datos | `tu-contraseña-segura` |

## Características del Pipeline

### Estrategia de Etiquetado de Imágenes

```yaml
# Se crean dos etiquetas para cada build:
# 1. Etiqueta específica de commit para trazabilidad
- '${_REGION}-docker.pkg.dev/${PROJECT_ID}/${_REPO_NAME}/user-management:${COMMIT_SHA}'
# 2. Etiqueta latest para referencia fácil
- '${_REGION}-docker.pkg.dev/${PROJECT_ID}/${_REPO_NAME}/user-management:latest'
```

### Características de Seguridad

1. **Escaneo de Vulnerabilidades**: Escaneo automático de imágenes de contenedores
2. **Gestión de Secretos**: Variables de entorno para datos sensibles
3. **Integración IAM**: Permisos de cuenta de servicio
4. **Seguridad de Red**: Despliegue en cluster privado

### Estrategia de Despliegue

- **Actualizaciones Rolling**: Despliegues sin tiempo de inactividad
- **Health Checks**: Validación automática antes del enrutamiento de tráfico
- **Capacidad de Rollback**: Reversión rápida a versiones anteriores
- **Gestión de Recursos**: Límites de CPU y memoria

## Ejecución del Pipeline

### Eventos de Trigger

El pipeline se ejecuta automáticamente en:
- Push a la rama `main`
- Merge de pull request a la rama `main`
- Trigger manual a través de Cloud Console

### Pasos de Ejecución

1. **Checkout del Código**: Código recuperado de GitHub
2. **Fase de Build**: Creación de imagen Docker (~2-3 minutos)
3. **Fase de Pruebas**: Health checks integrados
4. **Fase de Push**: Subida de imagen al registry (~1-2 minutos)
5. **Fase de Deploy**: Actualización de infraestructura Terraform (~3-5 minutos)
6. **Fase de Validación**: Health check y estado de rollout (~1 minuto)

**Tiempo Total del Pipeline**: ~7-11 minutos

### Logs de Build y Monitoreo

```bash
# Ver builds recientes
gcloud builds list --limit=10

# Ver logs de build específico
gcloud builds log BUILD_ID

# Monitorear build en tiempo real
gcloud builds log BUILD_ID --stream
```

## Pipelines Específicos por Ambiente

### Ambiente de Desarrollo

```yaml
# cloudbuild-dev.yaml
substitutions:
  _REGION: 'us-central1'
  _ZONE: 'us-central1-a'
  _REPO_NAME: 'user-management-repo-dev'
  _CLUSTER_NAME: 'user-management-dev'
  _DB_PASSWORD: 'dev-password'
```

### Ambiente de Producción

```yaml
# cloudbuild-prod.yaml
substitutions:
  _REGION: 'us-central1'
  _ZONE: 'us-central1-a'
  _REPO_NAME: 'user-management-repo'
  _CLUSTER_NAME: 'user-management-gke'
  _DB_PASSWORD: 'contraseña-producción-segura'
```

## Características Avanzadas del Pipeline

### Builds Paralelos

```yaml
# Múltiples pasos pueden ejecutarse en paralelo
steps:
  - name: 'pruebas-unitarias'
    id: 'test'
  - name: 'construir-imagen'
    id: 'build'
  - name: 'desplegar'
    waitFor: ['test', 'build']  # Espera a que ambos se completen
```

### Despliegues Condicionales

```yaml
# Desplegar solo en rama main
steps:
  - name: 'desplegar'
    entrypoint: 'bash'
    args:
      - '-c'
      - |
        if [ "$BRANCH_NAME" = "main" ]; then
          echo "Desplegando a producción"
          # Comandos de despliegue aquí
        else
          echo "Saltando despliegue para rama: $BRANCH_NAME"
        fi
```

### Notificaciones

```yaml
# Agregar notificaciones Slack/email
options:
  logging: CLOUD_LOGGING_ONLY
  notification:
    slack:
      webhook_url: ${_SLACK_WEBHOOK}
```

## Integración de Pruebas

### Pruebas Unitarias en Pipeline

```yaml
# Agregar paso de pruebas antes del build
steps:
  - name: 'node:16-alpine'
    entrypoint: 'npm'
    args: ['test']
    id: 'unit-tests'

  - name: 'build'
    waitFor: ['unit-tests']
```

### Pruebas de Integración

```yaml
# Agregar pruebas de integración después del despliegue
steps:
  - name: 'integration-tests'
    entrypoint: 'bash'
    args:
      - '-c'
      - |
        kubectl port-forward service/user-service 8080:80 -n user-management &
        sleep 10
        curl -f http://localhost:8080/health
        npm run integration-tests
    waitFor: ['deploy-terraform']
```

## Procedimientos de Rollback

### Rollback Automático

```bash
# Rollback al despliegue anterior
kubectl rollout undo deployment/user-service -n user-management

# Rollback a revisión específica
kubectl rollout undo deployment/user-service --to-revision=2 -n user-management
```

### Rollback Manual vía Cloud Build

```yaml
# Crear trigger de rollback
steps:
  - name: 'gcr.io/cloud-builders/kubectl'
    args:
      - 'rollout'
      - 'undo'
      - 'deployment/user-service'
      - '-n'
      - 'user-management'
    env:
      - 'CLOUDSDK_COMPUTE_ZONE=${_ZONE}'
      - 'CLOUDSDK_CONTAINER_CLUSTER=${_CLUSTER_NAME}'
```

## Optimización de Rendimiento

### Optimización de Build

```yaml
# Usar kaniko para builds más rápidos
- name: 'gcr.io/kaniko-project/executor:latest'
  args:
    - --dockerfile=Dockerfile
    - --destination=${_REGION}-docker.pkg.dev/${PROJECT_ID}/${_REPO_NAME}/user-management:${COMMIT_SHA}
    - --cache=true
```

### Tipos de Máquina

```yaml
# Usar máquinas de mayor rendimiento para builds
options:
  machineType: 'E2_HIGHCPU_8'  # 8 vCPUs para builds más rápidos
  diskSizeGb: '100'
```

## Mejores Prácticas de Seguridad

### Gestión de Secretos

```bash
# Almacenar secretos en Secret Manager
gcloud secrets create db-password --data-file=password.txt

# Referenciar en Cloud Build
env:
  - 'DB_PASSWORD'
secretEnv: ['DB_PASSWORD']
availableSecrets:
  secretManager:
    - versionName: projects/$PROJECT_ID/secrets/db-password/versions/latest
      env: 'DB_PASSWORD'
```

### Seguridad de Imágenes

```yaml
# Agregar escaneo de seguridad
steps:
  - name: 'gcr.io/cloud-builders/gcloud'
    args:
      - 'alpha'
      - 'container'
      - 'images'
      - 'scan'
      - '${_REGION}-docker.pkg.dev/${PROJECT_ID}/${_REPO_NAME}/user-management:${COMMIT_SHA}'
```

## Monitoreo y Alertas

### Métricas de Build

```bash
# Crear política de alertas para builds fallidos
gcloud alpha monitoring policies create build-failure-policy.yaml
```

### Análisis de Logs

```bash
# Consultar logs de build
gcloud logging read "resource.type=build AND severity>=ERROR" --limit=50
```

## Solución de Problemas

### Problemas Comunes

#### 1. Errores de Permisos
```bash
# Otorgar permisos necesarios a la cuenta de servicio Cloud Build
PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID --format='value(projectNumber)')
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="serviceAccount:${PROJECT_NUMBER}@cloudbuild.gserviceaccount.com" \
  --role="roles/container.developer"
```

#### 2. Problemas de Estado de Terraform
```bash
# Inicializar estado de Terraform en Cloud Storage
gsutil mb gs://${PROJECT_ID}-terraform-state
```

#### 3. Problemas de Timeout
```yaml
# Aumentar timeout
timeout: '1200s'  # 20 minutos
```

### Comandos de Depuración

```bash
# Verificar estado de trigger de build
gcloud builds triggers list

# Ver historial de builds
gcloud builds list --ongoing

# Depurar build específico
gcloud builds describe BUILD_ID
```

## Optimización de Costos

### Costos de Build

- Usar tipos de máquina apropiados para la complejidad del build
- Optimizar capas Docker para builds más rápidos
- Usar caché de build cuando sea posible
- Establecer valores de timeout razonables

### Costos de Almacenamiento

- Implementar políticas de retención de imágenes
- Limpiar builds antiguos regularmente
- Usar builds Docker multi-etapa

## Mejoras Futuras

1. **Pipelines multi-ambiente** (dev, staging, prod)
2. **Despliegues blue-green** para tiempo de inactividad cero
3. **Despliegues canary** para rollouts graduales
4. **Integración de escaneo de seguridad** con herramientas de terceros
5. **Pruebas de rendimiento** en el pipeline
6. **Pruebas de infraestructura** con herramientas como Terratest

## Comandos de Gestión del Pipeline

### Gestión de Triggers

```bash
# Listar todos los triggers
gcloud builds triggers list

# Crear trigger desde archivo
gcloud builds triggers import --source=trigger-config.yaml

# Actualizar trigger existente
gcloud builds triggers update TRIGGER_ID --build-config=cloudbuild-new.yaml

# Eliminar trigger
gcloud builds triggers delete TRIGGER_ID
```

### Gestión de Builds

```bash
# Ejecutar build manual
gcloud builds submit --config cloudbuild.yaml .

# Cancelar build en ejecución
gcloud builds cancel BUILD_ID

# Ver detalles de build
gcloud builds describe BUILD_ID --format="table(id,status,startTime,finishTime)"
```

### Monitoreo Avanzado

```bash
# Filtrar builds por estado
gcloud builds list --filter="status=FAILURE" --limit=10

# Obtener métricas de tiempo de build
gcloud builds list --format="table(id,startTime,finishTime,status)" --limit=20

# Monitorear uso de recursos
gcloud builds list --format="csv(id,timing.BUILD.startTime,timing.BUILD.endTime)" --limit=50
```

## Documentación de Configuración

### Archivo cloudbuild.yaml Completo

```yaml
# Pipeline CI/CD para Microservicio de Gestión de Usuarios
# Autor: Jimmy Rivas (jimmy.rivas.r@gmail.com)
# Asistente IA: Claude (Anthropic)

steps:
  # Paso 1: Construir imagen Docker
  - name: 'gcr.io/cloud-builders/docker'
    args:
      - 'build'
      - '-t'
      - '${_REGION}-docker.pkg.dev/${PROJECT_ID}/${_REPO_NAME}/user-management:${COMMIT_SHA}'
      - '-t'
      - '${_REGION}-docker.pkg.dev/${PROJECT_ID}/${_REPO_NAME}/user-management:latest'
      - '.'
    id: 'build-image'

  # Paso 2: Subir imagen a Artifact Registry
  - name: 'gcr.io/cloud-builders/docker'
    args:
      - 'push'
      - '--all-tags'
      - '${_REGION}-docker.pkg.dev/${PROJECT_ID}/${_REPO_NAME}/user-management'
    id: 'push-image'
    waitFor: ['build-image']

  # Paso 3: Desplegar a GKE usando Terraform
  - name: 'hashicorp/terraform:1.5'
    entrypoint: 'sh'
    args:
      - '-c'
      - |
        cd gcp-terraform
        terraform init
        terraform plan -var="project_id=${PROJECT_ID}" -var="app_image=${_REGION}-docker.pkg.dev/${PROJECT_ID}/${_REPO_NAME}/user-management:${COMMIT_SHA}"
        terraform apply -auto-approve -var="project_id=${PROJECT_ID}" -var="app_image=${_REGION}-docker.pkg.dev/${PROJECT_ID}/${_REPO_NAME}/user-management:${COMMIT_SHA}"
    id: 'deploy-terraform'
    waitFor: ['push-image']
    env:
      - 'TF_VAR_db_password=${_DB_PASSWORD}'

  # Paso 4: Esperar que el despliegue esté listo
  - name: 'gcr.io/cloud-builders/kubectl'
    args:
      - 'rollout'
      - 'status'
      - 'deployment/user-service'
      - '-n'
      - 'user-management'
    env:
      - 'CLOUDSDK_COMPUTE_ZONE=${_ZONE}'
      - 'CLOUDSDK_CONTAINER_CLUSTER=${_CLUSTER_NAME}'
    id: 'wait-deployment'
    waitFor: ['deploy-terraform']

  # Paso 5: Verificación de salud
  - name: 'gcr.io/cloud-builders/curl'
    args:
      - '-f'
      - 'http://user-service.user-management.svc.cluster.local/health'
    id: 'health-check'
    waitFor: ['wait-deployment']

# Variables de sustitución
substitutions:
  _REGION: 'us-central1'
  _ZONE: 'us-central1-a'
  _REPO_NAME: 'user-management-repo'
  _CLUSTER_NAME: 'user-management-gke'
  _DB_PASSWORD: 'tu-contraseña-segura'

# Opciones
options:
  logging: CLOUD_LOGGING_ONLY
  machineType: 'E2_MEDIUM'
  substitution_option: 'ALLOW_LOOSE'

# Timeout
timeout: '1200s'

# Imágenes a subir al registry
images:
  - '${_REGION}-docker.pkg.dev/${PROJECT_ID}/${_REPO_NAME}/user-management:${COMMIT_SHA}'
  - '${_REGION}-docker.pkg.dev/${PROJECT_ID}/${_REPO_NAME}/user-management:latest'
```

---

**Autor**: Jimmy Rivas (jimmy.rivas.r@gmail.com)
**Asistente IA**: Claude (Anthropic)
**Última Actualización**: Septiembre 2025