#!/bin/bash

# Keycloak Installation Script with External PostgreSQL Database
# This script installs Keycloak using an external PostgreSQL database

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

print_header() {
    echo ""
    echo -e "${BLUE}=========================================="
    echo "  $1"
    echo "==========================================${NC}"
    echo ""
}

print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header "Keycloak Installer with External Database"

echo "This installer will deploy Keycloak using an external PostgreSQL database."
echo "Make sure your database is accessible and has the keycloak database created."
echo ""

# Get user input
print_header "Configuration"

read -p "Enter namespace (default: keycloak): " NAMESPACE
NAMESPACE=${NAMESPACE:-keycloak}

read -p "Enter Helm release name (default: keycloak): " RELEASE_NAME
RELEASE_NAME=${RELEASE_NAME:-keycloak}

print_info "Database Configuration"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

read -p "PostgreSQL hostname: " DB_HOST
while [[ -z "$DB_HOST" ]]; do
    print_warn "Database hostname is required!"
    read -p "PostgreSQL hostname: " DB_HOST
done

read -p "PostgreSQL port (default: 5432): " DB_PORT
DB_PORT=${DB_PORT:-5432}

read -p "Database name (default: keycloak): " DB_NAME
DB_NAME=${DB_NAME:-keycloak}

read -p "Database username (default: keycloak): " DB_USER
DB_USER=${DB_USER:-keycloak}

read -sp "Database password: " DB_PASSWORD
echo ""
while [[ -z "$DB_PASSWORD" ]]; do
    print_warn "Database password is required!"
    read -sp "Database password: " DB_PASSWORD
    echo ""
done

echo ""
print_info "Keycloak Configuration"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

read -p "Keycloak hostname (e.g., keycloak.example.com): " HOSTNAME
while [[ -z "$HOSTNAME" ]]; do
    print_warn "Hostname is required!"
    read -p "Keycloak hostname: " HOSTNAME
done

read -sp "Keycloak admin password: " ADMIN_PASSWORD
echo ""
while [[ -z "$ADMIN_PASSWORD" ]]; do
    print_warn "Admin password is required!"
    read -sp "Keycloak admin password: " ADMIN_PASSWORD
    echo ""
done

read -p "Number of Keycloak replicas (default: 2): " REPLICAS
REPLICAS=${REPLICAS:-2}

read -p "Ingress class (nginx/traefik, default: nginx): " INGRESS_CLASS
INGRESS_CLASS=${INGRESS_CLASS:-nginx}

read -p "Storage class (leave empty for default): " STORAGE_CLASS

# Rancher options
echo ""
read -p "Is this a Rancher deployment? (y/n, default: n): " IS_RANCHER
if [[ "$IS_RANCHER" == "y" || "$IS_RANCHER" == "Y" ]]; then
    read -p "Enter Rancher project ID (format: c-xxxxx:p-xxxxx, optional): " RANCHER_PROJECT_ID
fi

echo ""
print_header "Configuration Summary"
echo "Namespace:          $NAMESPACE"
echo "Release:            $RELEASE_NAME"
echo "Hostname:           $HOSTNAME"
echo "Replicas:           $REPLICAS"
echo "Ingress Class:      $INGRESS_CLASS"
echo "Storage Class:      ${STORAGE_CLASS:-default}"
echo ""
echo "Database Host:      $DB_HOST"
echo "Database Port:      $DB_PORT"
echo "Database Name:      $DB_NAME"
echo "Database User:      $DB_USER"
echo ""

read -p "Proceed with installation? (y/n): " CONFIRM
if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
    print_warn "Installation cancelled."
    exit 0
fi

# Test database connectivity
print_header "Testing Database Connectivity"

print_info "Checking if PostgreSQL is reachable..."
if command -v nc &> /dev/null; then
    if nc -z -w5 "$DB_HOST" "$DB_PORT" 2>/dev/null; then
        print_info "✓ Database host is reachable on port $DB_PORT"
    else
        print_warn "⚠ Cannot reach database host. Installation will continue, but may fail if database is not accessible."
        read -p "Continue anyway? (y/n): " CONTINUE
        if [[ "$CONTINUE" != "y" && "$CONTINUE" != "Y" ]]; then
            exit 1
        fi
    fi
else
    print_warn "netcat (nc) not available, skipping connectivity check"
fi

# Create namespace
print_header "Creating Namespace"
if kubectl get namespace "$NAMESPACE" &> /dev/null; then
    print_warn "Namespace $NAMESPACE already exists"
else
    kubectl create namespace "$NAMESPACE"
    print_info "Namespace $NAMESPACE created"
fi

# Create secrets
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

# Database secret
if kubectl get secret keycloak-db-secret -n "$NAMESPACE" &> /dev/null; then
    print_warn "Database secret already exists, skipping creation"
else
    kubectl create secret generic keycloak-db-secret \
        --from-literal=password="$DB_PASSWORD" \
        -n "$NAMESPACE"
    print_info "Database secret created"
fi

# Build Helm command
print_header "Installing Keycloak"

HELM_CMD="helm install $RELEASE_NAME . \
    -f values-external-db.yaml \
    --namespace $NAMESPACE \
    --set keycloak.replicas=$REPLICAS \
    --set keycloak.auth.adminUser=admin \
    --set keycloak.auth.existingSecret=keycloak-admin-secret \
    --set keycloak.configuration.hostname=$HOSTNAME \
    --set keycloak.configuration.database.hostname=$DB_HOST \
    --set keycloak.configuration.database.port=$DB_PORT \
    --set keycloak.configuration.database.database=$DB_NAME \
    --set keycloak.configuration.database.username=$DB_USER \
    --set keycloak.configuration.database.existingSecret=keycloak-db-secret \
    --set ingress.className=$INGRESS_CLASS \
    --set ingress.hosts[0].host=$HOSTNAME \
    --set ingress.hosts[0].paths[0].path=/ \
    --set ingress.hosts[0].paths[0].pathType=Prefix \
    --set ingress.tls[0].secretName=keycloak-tls \
    --set ingress.tls[0].hosts[0]=$HOSTNAME"

# Add storage class if specified
if [[ -n "$STORAGE_CLASS" ]]; then
    HELM_CMD="$HELM_CMD --set persistence.storageClass=$STORAGE_CLASS"
fi

# Add Rancher project ID if specified
if [[ -n "$RANCHER_PROJECT_ID" ]]; then
    HELM_CMD="$HELM_CMD --set rancher.projectId=$RANCHER_PROJECT_ID"
fi

print_info "Running Helm install..."
eval "$HELM_CMD"

print_info "Helm chart installed successfully"

# Wait for deployment
print_header "Waiting for Deployment"

print_info "Waiting for pods to be ready (this may take a few minutes)..."
kubectl wait --for=condition=ready pod \
    -l app.kubernetes.io/name=keycloak \
    -n "$NAMESPACE" \
    --timeout=600s 2>&1 || {
    print_warn "Timeout waiting for pods. Checking status..."
    kubectl get pods -n "$NAMESPACE"
}

echo ""
print_header "Deployment Status"
kubectl get pods -n "$NAMESPACE"

# Print access information
print_header "Access Information"

echo "Keycloak has been deployed with external database!"
echo ""
echo "Access Details:"
echo "  URL: https://$HOSTNAME"
echo "  Admin Username: admin"
echo "  Admin Password: <the password you entered>"
echo ""
echo "Database Connection:"
echo "  Host: $DB_HOST:$DB_PORT"
echo "  Database: $DB_NAME"
echo "  User: $DB_USER"
echo ""
echo "Useful commands:"
echo "  View pods:     kubectl get pods -n $NAMESPACE"
echo "  View logs:     kubectl logs -f statefulset/$RELEASE_NAME -n $NAMESPACE"
echo "  View ingress:  kubectl get ingress -n $NAMESPACE"
echo "  Port-forward:  kubectl port-forward svc/$RELEASE_NAME 8080:8080 -n $NAMESPACE"
echo ""
echo "Troubleshooting:"
echo "  If pods are not starting, check database connectivity:"
echo "    kubectl exec -it ${RELEASE_NAME}-0 -n $NAMESPACE -- sh"
echo "    nc -zv $DB_HOST $DB_PORT"
echo ""
echo "To uninstall:"
echo "  helm uninstall $RELEASE_NAME -n $NAMESPACE"
echo ""

print_info "Installation complete!"
