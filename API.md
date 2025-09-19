# API Documentation - User Management Microservice

**Autor**: Jimmy Rivas (jimmy.rivas.r@gmail.com)
**Asistente de Desarrollo**: Claude (Anthropic)
**Versión API**: 1.0
**Base URL**: `http://user-service.local` o `http://localhost:3000` (desarrollo)

## 📋 Resumen de la API

La API de gestión de usuarios proporciona operaciones CRUD completas para la administración de usuarios. Está construida con Node.js, Express y PostgreSQL, con validación de datos y manejo robusto de errores.

## 🔧 Configuración

### URLs de Acceso
- **Producción**: `http://user-service.local` (requiere configuración de /etc/hosts)
- **Desarrollo Local**: `http://localhost:3000`
- **Port-Forward**: `kubectl port-forward service/user-service 8080:80 -n user-management`

### Headers Requeridos
```
Content-Type: application/json
```

## 📚 Endpoints

### 1. Health Check

Verifica el estado del servicio.

**Endpoint**: `GET /health`

**Descripción**: Endpoint de monitoreo para verificar que el servicio está funcionando correctamente.

#### Request
```bash
curl -X GET http://user-service.local/health
```

#### Response
```json
{
  "status": "OK",
  "timestamp": "2025-09-19T16:30:00.000Z"
}
```

**Status Codes:**
- `200 OK`: Servicio funcionando correctamente

---

### 2. Crear Usuario

Crea un nuevo usuario en el sistema.

**Endpoint**: `POST /users`

**Descripción**: Registra un nuevo usuario con nombre y email únicos.

#### Request
```bash
curl -X POST http://user-service.local/users \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Jimmy Rivas",
    "email": "jimmy.rivas.r@gmail.com"
  }'
```

#### Request Body
```json
{
  "name": "string (required, min: 2, max: 100)",
  "email": "string (required, valid email format)"
}
```

#### Response Success (201 Created)
```json
{
  "id": 1,
  "name": "Jimmy Rivas",
  "email": "jimmy.rivas.r@gmail.com",
  "created_at": "2025-09-19T16:30:00.000Z"
}
```

#### Response Error (400 Bad Request)
```json
{
  "error": "\"name\" is required"
}
```

#### Response Error (409 Conflict)
```json
{
  "error": "Email already exists"
}
```

**Status Codes:**
- `201 Created`: Usuario creado exitosamente
- `400 Bad Request`: Datos de entrada inválidos
- `409 Conflict`: Email ya existe en el sistema
- `500 Internal Server Error`: Error del servidor

**Validaciones:**
- `name`: Requerido, mínimo 2 caracteres, máximo 100 caracteres
- `email`: Requerido, formato de email válido, único en el sistema

---

### 3. Obtener Usuario por ID

Obtiene los datos de un usuario específico.

**Endpoint**: `GET /users/:id`

**Descripción**: Recupera la información completa de un usuario por su ID único.

#### Request
```bash
curl -X GET http://user-service.local/users/1
```

#### Path Parameters
- `id` (integer, required): ID único del usuario

#### Response Success (200 OK)
```json
{
  "id": 1,
  "name": "Jimmy Rivas",
  "email": "jimmy.rivas.r@gmail.com",
  "created_at": "2025-09-19T16:30:00.000Z"
}
```

#### Response Error (404 Not Found)
```json
{
  "error": "User not found"
}
```

**Status Codes:**
- `200 OK`: Usuario encontrado
- `404 Not Found`: Usuario no existe
- `500 Internal Server Error`: Error del servidor

---

### 4. Actualizar Usuario

Actualiza los datos de un usuario existente.

**Endpoint**: `PUT /users/:id`

**Descripción**: Modifica el nombre y/o email de un usuario existente.

#### Request
```bash
curl -X PUT http://user-service.local/users/1 \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Jimmy Rivas Updated",
    "email": "jimmy.rivas.updated@gmail.com"
  }'
```

#### Path Parameters
- `id` (integer, required): ID único del usuario a actualizar

#### Request Body
```json
{
  "name": "string (required, min: 2, max: 100)",
  "email": "string (required, valid email format)"
}
```

#### Response Success (200 OK)
```json
{
  "id": 1,
  "name": "Jimmy Rivas Updated",
  "email": "jimmy.rivas.updated@gmail.com",
  "created_at": "2025-09-19T16:30:00.000Z"
}
```

#### Response Error (404 Not Found)
```json
{
  "error": "User not found"
}
```

#### Response Error (409 Conflict)
```json
{
  "error": "Email already exists"
}
```

**Status Codes:**
- `200 OK`: Usuario actualizado exitosamente
- `400 Bad Request`: Datos de entrada inválidos
- `404 Not Found`: Usuario no existe
- `409 Conflict`: Email ya existe en el sistema
- `500 Internal Server Error`: Error del servidor

**Validaciones:**
- `name`: Requerido, mínimo 2 caracteres, máximo 100 caracteres
- `email`: Requerido, formato de email válido, único en el sistema

---

### 5. Eliminar Usuario

Elimina un usuario del sistema.

**Endpoint**: `DELETE /users/:id`

**Descripción**: Elimina permanentemente un usuario del sistema.

#### Request
```bash
curl -X DELETE http://user-service.local/users/1
```

#### Path Parameters
- `id` (integer, required): ID único del usuario a eliminar

#### Response Success (200 OK)
```json
{
  "message": "User deleted successfully"
}
```

#### Response Error (404 Not Found)
```json
{
  "error": "User not found"
}
```

**Status Codes:**
- `200 OK`: Usuario eliminado exitosamente
- `404 Not Found`: Usuario no existe
- `500 Internal Server Error`: Error del servidor

## 🔍 Ejemplos de Uso Completos

### Flujo de Trabajo Típico

#### 1. Verificar Estado del Servicio
```bash
curl http://user-service.local/health
# Respuesta: {"status":"OK","timestamp":"..."}
```

#### 2. Crear Múltiples Usuarios
```bash
# Usuario 1
curl -X POST http://user-service.local/users \
  -H "Content-Type: application/json" \
  -d '{"name": "Jimmy Rivas", "email": "jimmy.rivas.r@gmail.com"}'

# Usuario 2
curl -X POST http://user-service.local/users \
  -H "Content-Type: application/json" \
  -d '{"name": "Ana García", "email": "ana.garcia@example.com"}'

# Usuario 3
curl -X POST http://user-service.local/users \
  -H "Content-Type: application/json" \
  -d '{"name": "Carlos López", "email": "carlos.lopez@example.com"}'
```

#### 3. Consultar Usuarios Creados
```bash
# Obtener primer usuario
curl http://user-service.local/users/1

# Obtener segundo usuario
curl http://user-service.local/users/2

# Obtener tercer usuario
curl http://user-service.local/users/3
```

#### 4. Actualizar Usuario
```bash
curl -X PUT http://user-service.local/users/2 \
  -H "Content-Type: application/json" \
  -d '{"name": "Ana García Martínez", "email": "ana.garcia.martinez@example.com"}'
```

#### 5. Eliminar Usuario
```bash
curl -X DELETE http://user-service.local/users/3
```

### Script de Testing Automatizado

```bash
#!/bin/bash
# test-api.sh - Script de prueba completo

BASE_URL="http://user-service.local"

echo "🔍 1. Health Check"
curl -s $BASE_URL/health | jq .

echo -e "\n👤 2. Crear Usuario"
USER_RESPONSE=$(curl -s -X POST $BASE_URL/users \
  -H "Content-Type: application/json" \
  -d '{"name": "Test User", "email": "test@example.com"}')
echo $USER_RESPONSE | jq .

USER_ID=$(echo $USER_RESPONSE | jq -r .id)

echo -e "\n📖 3. Obtener Usuario (ID: $USER_ID)"
curl -s $BASE_URL/users/$USER_ID | jq .

echo -e "\n✏️ 4. Actualizar Usuario"
curl -s -X PUT $BASE_URL/users/$USER_ID \
  -H "Content-Type: application/json" \
  -d '{"name": "Test User Updated", "email": "test.updated@example.com"}' | jq .

echo -e "\n🗑️ 5. Eliminar Usuario"
curl -s -X DELETE $BASE_URL/users/$USER_ID | jq .

echo -e "\n✅ Testing completed!"
```

## ⚠️ Manejo de Errores

### Tipos de Errores

#### Errores de Validación (400 Bad Request)
```json
{
  "error": "\"email\" must be a valid email"
}
```

#### Errores de Conflicto (409 Conflict)
```json
{
  "error": "Email already exists"
}
```

#### Errores de Recurso No Encontrado (404 Not Found)
```json
{
  "error": "User not found"
}
```

#### Errores Internos del Servidor (500 Internal Server Error)
```json
{
  "error": "Internal server error"
}
```

### Buenas Prácticas para Clientes

1. **Verificar Status Codes**: Siempre verificar el código de estado HTTP antes de procesar la respuesta
2. **Manejo de Errores**: Implementar manejo específico para cada tipo de error
3. **Retry Logic**: Implementar reintentos para errores 5xx
4. **Timeout**: Configurar timeouts apropiados para las peticiones
5. **Logging**: Registrar errores para debugging y monitoreo

## 🔒 Consideraciones de Seguridad

### Validación de Entrada
- Todos los datos de entrada son validados usando Joi
- Los emails deben ser únicos en el sistema
- Los nombres tienen longitud mínima y máxima

### Manejo Seguro de Errores
- No se exponen detalles internos del sistema en los errores
- Los errores de base de datos se abstraen apropiadamente
- Los stack traces no se exponen en producción

### Recomendaciones de Implementación
- Implementar autenticación y autorización según necesidades
- Usar HTTPS en producción
- Implementar rate limiting para prevenir abuso
- Agregar logging y monitoreo de seguridad

## 📊 Esquema de Base de Datos

### Tabla: users

| Campo | Tipo | Constraints | Descripción |
|-------|------|-------------|-------------|
| id | SERIAL | PRIMARY KEY | ID único del usuario (auto-incremental) |
| name | VARCHAR(100) | NOT NULL | Nombre completo del usuario |
| email | VARCHAR(255) | UNIQUE, NOT NULL | Email único del usuario |
| created_at | TIMESTAMP | DEFAULT CURRENT_TIMESTAMP | Fecha y hora de creación |

### SQL de Creación
```sql
CREATE TABLE IF NOT EXISTS users (
  id SERIAL PRIMARY KEY,
  name VARCHAR(100) NOT NULL,
  email VARCHAR(255) UNIQUE NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

## 🚀 Testing y Desarrollo

### Configuración de Desarrollo Local
```bash
# Instalar dependencias
npm install

# Ejecutar con docker-compose
docker-compose up -d

# Verificar servicios
docker-compose ps

# Ver logs
docker-compose logs -f user-service
```

### Variables de Entorno para Testing
```bash
export API_BASE_URL="http://localhost:3000"
export DB_HOST="localhost"
export DB_PORT="5432"
export DB_NAME="users_db"
export DB_USER="postgres"
export DB_PASSWORD="password"
```

### Herramientas Recomendadas
- **Postman**: Para testing manual de la API
- **curl**: Para scripts automatizados
- **jq**: Para procesamiento de respuestas JSON
- **Artillery**: Para testing de carga
- **Newman**: Para ejecutar colecciones de Postman en CI/CD

## 📈 Monitoreo y Observabilidad

### Logs de la Aplicación
```bash
# Logs en tiempo real
kubectl logs -f deployment/user-service -n user-management

# Logs con filtros
kubectl logs deployment/user-service -n user-management | grep ERROR
```

### Métricas de Health Check
- El endpoint `/health` debe responder en <100ms
- Status 200 indica servicio saludable
- Incluye timestamp para verificar disponibilidad

### Métricas Recomendadas para Implementar
- Latencia promedio por endpoint
- Tasa de errores por tipo
- Número de usuarios activos
- Uso de base de datos
- Throughput de requests por segundo

## 📞 Soporte y Contacto

**Desarrollador**: Jimmy Rivas
**Email**: jimmy.rivas.r@gmail.com
**Asistente de Desarrollo**: Claude (Anthropic)

Para reportar bugs, solicitar features o hacer preguntas sobre la API, contactar al desarrollador principal.