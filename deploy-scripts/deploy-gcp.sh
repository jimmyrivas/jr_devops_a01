#!/bin/bash

# GCP Deployment Script for User Management Microservice
# Author: Jimmy Rivas (jimmy.rivas.r@gmail.com)
# AI Assistant: Claude (Anthropic)

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
PROJECT_ID="${PROJECT_ID:-your-gcp-project-id}"
REGION="${REGION:-us-central1}"
ZONE="${ZONE:-us-central1-a}"
CLUSTER_NAME="${CLUSTER_NAME:-user-management-gke}"
REPO_NAME="${REPO_NAME:-user-management-repo}"
DB_PASSWORD="${DB_PASSWORD:-}"

print_step() {
    echo -e "${BLUE}==== $1 ====${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

check_prerequisites() {
    print_step "Checking Prerequisites"

    # Check if gcloud is installed
    if ! command -v gcloud &> /dev/null; then
        print_error "gcloud CLI not found. Please install Google Cloud SDK."
        exit 1
    fi

    # Check if terraform is installed
    if ! command -v terraform &> /dev/null; then
        print_error "terraform not found. Please install Terraform."
        exit 1
    fi

    # Check if docker is installed
    if ! command -v docker &> /dev/null; then
        print_error "docker not found. Please install Docker."
        exit 1
    fi

    # Check if logged in to gcloud
    if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q .; then
        print_error "Not authenticated to GCP. Please run 'gcloud auth login'"
        exit 1
    fi

    print_success "All prerequisites met"
}

setup_gcp_project() {
    print_step "Setting up GCP Project"

    # Set the project
    gcloud config set project $PROJECT_ID

    # Enable required APIs
    print_step "Enabling required APIs"
    gcloud services enable \
        container.googleapis.com \
        sqladmin.googleapis.com \
        artifactregistry.googleapis.com \
        cloudbuild.googleapis.com \
        servicenetworking.googleapis.com

    print_success "GCP project setup completed"
}

build_and_push_image() {
    print_step "Building and Pushing Docker Image"

    # Configure Docker for Artifact Registry
    gcloud auth configure-docker ${REGION}-docker.pkg.dev

    # Build the image
    docker build -t ${REGION}-docker.pkg.dev/${PROJECT_ID}/${REPO_NAME}/user-management:latest .

    # Push the image
    docker push ${REGION}-docker.pkg.dev/${PROJECT_ID}/${REPO_NAME}/user-management:latest

    print_success "Docker image built and pushed"
}

deploy_infrastructure() {
    print_step "Deploying Infrastructure with Terraform"

    cd gcp-terraform

    # Initialize Terraform
    terraform init

    # Create terraform.tfvars from environment variables
    cat > terraform.tfvars <<EOF
project_id   = "${PROJECT_ID}"
project_name = "user-management"
region       = "${REGION}"
zone         = "${ZONE}"
app_image    = "${REGION}-docker.pkg.dev/${PROJECT_ID}/${REPO_NAME}/user-management:latest"
db_password  = "${DB_PASSWORD}"
EOF

    # Plan the deployment
    terraform plan

    # Apply the deployment
    terraform apply -auto-approve

    cd ..

    print_success "Infrastructure deployed"
}

configure_kubectl() {
    print_step "Configuring kubectl"

    # Get cluster credentials
    gcloud container clusters get-credentials ${CLUSTER_NAME} --zone ${ZONE} --project ${PROJECT_ID}

    print_success "kubectl configured"
}

wait_for_deployment() {
    print_step "Waiting for deployment to be ready"

    # Wait for the deployment to be ready
    kubectl rollout status deployment/user-service -n user-management --timeout=600s

    print_success "Deployment is ready"
}

run_health_check() {
    print_step "Running Health Check"

    # Port forward to test the service
    kubectl port-forward service/user-service 8080:80 -n user-management &
    PORT_FORWARD_PID=$!

    # Wait a moment for port forward to establish
    sleep 5

    # Test health endpoint
    if curl -f http://localhost:8080/health; then
        print_success "Health check passed"
    else
        print_error "Health check failed"
    fi

    # Clean up port forward
    kill $PORT_FORWARD_PID 2>/dev/null || true
}

show_deployment_info() {
    print_step "Deployment Information"

    cd gcp-terraform

    echo -e "${GREEN}📊 Deployment Summary:${NC}"
    echo "Project ID: $(terraform output -raw project_id)"
    echo "Region: $(terraform output -raw region)"
    echo "Cluster: $(terraform output -raw kubernetes_cluster_name)"
    echo "Namespace: $(terraform output -raw namespace)"
    echo "Service URL: $(terraform output -raw service_url)"
    echo "Load Balancer IP: $(terraform output -raw load_balancer_ip)"

    echo -e "\n${YELLOW}🔧 Useful Commands:${NC}"
    echo "Connect to cluster: $(terraform output -raw gke_connect_command)"
    echo "Configure Docker: $(terraform output -raw docker_configure_command)"
    echo "View pods: kubectl get pods -n user-management"
    echo "View services: kubectl get services -n user-management"
    echo "View logs: kubectl logs deployment/user-service -n user-management"

    cd ..
}

cleanup() {
    print_step "Cleaning up"

    # Kill any remaining port forwards
    pkill -f "kubectl port-forward" 2>/dev/null || true

    print_success "Cleanup completed"
}

main() {
    echo -e "${BLUE}"
    echo "╔═══════════════════════════════════════════════════════════════╗"
    echo "║               GCP Deployment Script                           ║"
    echo "║          User Management Microservice                        ║"
    echo "║                                                               ║"
    echo "║  Author: Jimmy Rivas (jimmy.rivas.r@gmail.com)               ║"
    echo "║  AI Assistant: Claude (Anthropic)                            ║"
    echo "╚═══════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"

    # Validate required environment variables
    if [[ -z "$PROJECT_ID" ]]; then
        print_error "PROJECT_ID environment variable is required"
        echo "Usage: PROJECT_ID=your-project-id DB_PASSWORD=your-password $0"
        exit 1
    fi

    if [[ -z "$DB_PASSWORD" ]]; then
        print_error "DB_PASSWORD environment variable is required"
        echo "Usage: PROJECT_ID=your-project-id DB_PASSWORD=your-password $0"
        exit 1
    fi

    # Set trap for cleanup
    trap cleanup EXIT

    # Execute deployment steps
    check_prerequisites
    setup_gcp_project
    build_and_push_image
    deploy_infrastructure
    configure_kubectl
    wait_for_deployment
    run_health_check
    show_deployment_info

    print_success "🎉 Deployment completed successfully!"
    echo -e "${GREEN}Your microservice is now running on GCP!${NC}"
}

# Execute main function
main "$@"