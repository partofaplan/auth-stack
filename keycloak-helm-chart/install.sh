#!/bin/bash

# Keycloak Helm Chart Installation Script
# This script helps you quickly deploy Keycloak to Kubernetes

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Functions
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo ""
    echo "=========================================="
    echo "$1"
    echo "=========================================="
    echo ""
}

# Check prerequisites
check_prerequisites() {
    print_header "Checking Prerequisites"

    # Check kubectl
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl not found. Please install kubectl first."
        exit 1
    fi
    print_info "kubectl: $(kubectl version --client --short 2>/dev/null || kubectl version --client)"

    # Check helm
    if ! command -v helm &> /dev/null; then
        print_error "helm not found. Please install Helm 3 first."
        exit 1
    fi
    print_info "helm: $(helm version --short)"

    # Check cluster connection
    if ! kubectl cluster-info &> /dev/null; then
        print_error "Cannot connect to Kubernetes cluster. Please check your kubeconfig."
        exit 1
    fi
    print_info "Kubernetes cluster: Connected"
}

# Get user input
get_user_input() {
    print_header "Configuration"

    # Namespace
    read -p "Enter namespace (default: keycloak): " NAMESPACE
    NAMESPACE=${NAMESPACE:-keycloak}

    # Release name
    read -p "Enter Helm release name (default: keycloak): " RELEASE_NAME
    RELEASE_NAME=${RELEASE_NAME:-keycloak}

    # Hostname
    read -p "Enter Keycloak hostname (e.g., keycloak.example.com): " HOSTNAME
    while [[ -z "$HOSTNAME" ]]; do
        print_warn "Hostname is required!"
        read -p "Enter Keycloak hostname: " HOSTNAME
    done

    # Admin password
    read -sp "Enter admin password (will be hidden): " ADMIN_PASSWORD
    echo ""
    while [[ -z "$ADMIN_PASSWORD" ]]; do
        print_warn "Admin password is required!"
        read -sp "Enter admin password: " ADMIN_PASSWORD
        echo ""
    done

    # Database password
    read -sp "Enter database password (will be hidden): " DB_PASSWORD
    echo ""
    while [[ -z "$DB_PASSWORD" ]]; do
        print_warn "Database password is required!"
        read -sp "Enter database password: " DB_PASSWORD
        echo ""
    done

    # Number of replicas
    read -p "Enter number of Keycloak replicas (default: 2): " REPLICAS
    REPLICAS=${REPLICAS:-2}

    # Deployment profile
    echo ""
    echo "Select deployment profile:"
    echo "1) Development (default values)"
    echo "2) Production (values-production.yaml)"
    echo "3) Rancher (values-rancher.yaml)"
    read -p "Enter choice [1-3] (default: 1): " PROFILE
    PROFILE=${PROFILE:-1}

    VALUES_FILE=""
    case $PROFILE in
        2)
            VALUES_FILE="-f values-production.yaml"
            print_info "Using production profile"
            ;;
        3)
            VALUES_FILE="-f values-rancher.yaml"
            print_info "Using Rancher profile"
            # Ask for Rancher project ID
            read -p "Enter Rancher project ID (format: c-xxxxx:p-xxxxx, optional): " RANCHER_PROJECT_ID
            ;;
        *)
            VALUES_FILE="-f values.yaml"
            print_info "Using development profile"
            ;;
    esac

    # Ingress class
    read -p "Enter ingress class (nginx/traefik, default: nginx): " INGRESS_CLASS
    INGRESS_CLASS=${INGRESS_CLASS:-nginx}

    # Storage class
    read -p "Enter storage class (leave empty for default): " STORAGE_CLASS

    echo ""
    print_info "Configuration summary:"
    echo "  Namespace: $NAMESPACE"
    echo "  Release: $RELEASE_NAME"
    echo "  Hostname: $HOSTNAME"
    echo "  Replicas: $REPLICAS"
    echo "  Ingress Class: $INGRESS_CLASS"
    echo "  Storage Class: ${STORAGE_CLASS:-default}"
    echo ""

    read -p "Proceed with installation? (y/n): " CONFIRM
    if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
        print_warn "Installation cancelled."
        exit 0
    fi
}

# Update Helm dependencies
update_dependencies() {
    print_header "Updating Helm Dependencies"

    # Check if Chart.yaml exists
    if [[ ! -f "Chart.yaml" ]]; then
        print_error "Chart.yaml not found. Please run this script from the keycloak-helm-chart directory."
        exit 1
    fi

    # Remove macOS extended attributes that may cause issues
    if [[ "$OSTYPE" == "darwin"* ]]; then
        xattr -cr . 2>/dev/null || true
        print_info "Cleaned macOS extended attributes"
    fi

    # Update dependencies
    if helm dependency update 2>&1 | tee /tmp/helm-dep-update.log; then
        print_info "Dependencies updated successfully"
    else
        print_error "Failed to update dependencies. See error above."
        cat /tmp/helm-dep-update.log
        print_warn "You may need to run 'helm dependency update' manually before installing."
        read -p "Continue anyway? (y/n): " CONTINUE
        if [[ "$CONTINUE" != "y" && "$CONTINUE" != "Y" ]]; then
            exit 1
        fi
    fi
}

# Create namespace
create_namespace() {
    print_header "Creating Namespace"
    if kubectl get namespace "$NAMESPACE" &> /dev/null; then
        print_warn "Namespace $NAMESPACE already exists"
    else
        kubectl create namespace "$NAMESPACE"
        print_info "Namespace $NAMESPACE created"
    fi
}

# Create secrets
create_secrets() {
    print_header "Creating Secrets"

    # Admin secret
    if kubectl get secret keycloak-admin-secret -n "$NAMESPACE" &> /dev/null; then
        print_warn "Admin secret already exists, skipping creation"
    else
        kubectl create secret generic keycloak-admin-secret \
            --from-literal=password="$ADMIN_PASSWORD" \
            -n "$NAMESPACE"
        print_info "Admin secret created"
    fi

    # Database secret (only if using built-in PostgreSQL)
    if kubectl get secret "$RELEASE_NAME-postgresql" -n "$NAMESPACE" &> /dev/null; then
        print_warn "Database secret already exists, skipping creation"
    else
        kubectl create secret generic "$RELEASE_NAME-postgresql" \
            --from-literal=password="$DB_PASSWORD" \
            -n "$NAMESPACE"
        print_info "Database secret created"
    fi
}

# Install chart
install_chart() {
    print_header "Installing Keycloak Helm Chart"

    HELM_CMD="helm install $RELEASE_NAME . $VALUES_FILE \
        --namespace $NAMESPACE \
        --set keycloak.replicas=$REPLICAS \
        --set keycloak.auth.adminUser=admin \
        --set keycloak.auth.existingSecret=keycloak-admin-secret \
        --set keycloak.configuration.hostname=$HOSTNAME \
        --set ingress.className=$INGRESS_CLASS \
        --set postgresql.auth.existingSecret=$RELEASE_NAME-postgresql"

    # Add storage class if specified
    if [[ -n "$STORAGE_CLASS" ]]; then
        HELM_CMD="$HELM_CMD \
            --set persistence.storageClass=$STORAGE_CLASS \
            --set postgresql.primary.persistence.storageClass=$STORAGE_CLASS"
    fi

    # Add Rancher project ID if specified
    if [[ -n "$RANCHER_PROJECT_ID" ]]; then
        HELM_CMD="$HELM_CMD --set rancher.projectId=$RANCHER_PROJECT_ID"
    fi

    print_info "Running: $HELM_CMD"
    eval "$HELM_CMD"

    print_info "Helm chart installed successfully"
}

# Wait for deployment
wait_for_deployment() {
    print_header "Waiting for Deployment"

    print_info "Waiting for pods to be ready (this may take a few minutes)..."
    kubectl wait --for=condition=ready pod \
        -l app.kubernetes.io/name=keycloak \
        -n "$NAMESPACE" \
        --timeout=600s || true

    echo ""
    print_info "Deployment status:"
    kubectl get pods -n "$NAMESPACE"
}

# Print access information
print_access_info() {
    print_header "Access Information"

    echo "Keycloak has been deployed!"
    echo ""
    echo "Access Details:"
    echo "  URL: https://$HOSTNAME"
    echo "  Admin Username: admin"
    echo "  Admin Password: <the password you entered>"
    echo ""
    echo "Useful commands:"
    echo "  View pods:     kubectl get pods -n $NAMESPACE"
    echo "  View logs:     kubectl logs -f statefulset/$RELEASE_NAME -n $NAMESPACE"
    echo "  View ingress:  kubectl get ingress -n $NAMESPACE"
    echo "  Port-forward:  kubectl port-forward svc/$RELEASE_NAME 8080:8080 -n $NAMESPACE"
    echo ""
    echo "To uninstall:"
    echo "  helm uninstall $RELEASE_NAME -n $NAMESPACE"
    echo ""

    print_info "For more information, see README.md and DEPLOYMENT-GUIDE.md"
}

# Main installation flow
main() {
    print_header "Keycloak Helm Chart Installer"

    check_prerequisites
    get_user_input
    update_dependencies
    create_namespace
    create_secrets
    install_chart
    wait_for_deployment
    print_access_info

    print_info "Installation complete!"
}

# Run main function
main
