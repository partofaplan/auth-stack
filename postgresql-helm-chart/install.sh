#!/bin/bash

# PostgreSQL Quick Install Script

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}=========================================="
echo "  PostgreSQL Database Installer"
echo "==========================================${NC}"
echo ""

# Check if Chart.yaml exists
if [[ ! -f "Chart.yaml" ]]; then
    echo -e "${RED}Error: Chart.yaml not found.${NC}"
    echo "Please run this script from the postgresql-helm-chart directory."
    echo ""
    echo "Current directory: $(pwd)"
    echo "Expected directory: .../auth-stack/postgresql-helm-chart"
    exit 1
fi

# Clean macOS extended attributes if on macOS
if [[ "$OSTYPE" == "darwin"* ]]; then
    xattr -cr . 2>/dev/null || true
fi

# Get configuration
read -p "Enter namespace (default: postgres): " NAMESPACE
NAMESPACE=${NAMESPACE:-postgres}

read -p "Enter release name (default: postgres): " RELEASE_NAME
RELEASE_NAME=${RELEASE_NAME:-postgres}

read -p "Database name (default: keycloak): " DB_NAME
DB_NAME=${DB_NAME:-keycloak}

read -p "Database username (default: keycloak): " DB_USER
DB_USER=${DB_USER:-keycloak}

read -sp "Database password: " DB_PASSWORD
echo ""
while [[ -z "$DB_PASSWORD" ]]; do
    echo -e "${YELLOW}Password is required!${NC}"
    read -sp "Database password: " DB_PASSWORD
    echo ""
done

read -sp "PostgreSQL superuser password: " POSTGRES_PASSWORD
echo ""
while [[ -z "$POSTGRES_PASSWORD" ]]; do
    echo -e "${YELLOW}Superuser password is required!${NC}"
    read -sp "PostgreSQL superuser password: " POSTGRES_PASSWORD
    echo ""
done

read -p "Storage size (default: 8Gi): " STORAGE_SIZE
STORAGE_SIZE=${STORAGE_SIZE:-8Gi}

read -p "Storage class (leave empty for default): " STORAGE_CLASS

echo ""
echo -e "${GREEN}Configuration:${NC}"
echo "  Namespace: $NAMESPACE"
echo "  Release: $RELEASE_NAME"
echo "  Database: $DB_NAME"
echo "  Username: $DB_USER"
echo "  Storage: $STORAGE_SIZE"
echo "  Storage Class: ${STORAGE_CLASS:-default}"
echo ""

read -p "Install PostgreSQL? (y/n): " CONFIRM
if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
    echo "Installation cancelled."
    exit 0
fi

# Create namespace
echo -e "${GREEN}Creating namespace...${NC}"
kubectl create namespace "$NAMESPACE" 2>/dev/null || echo "Namespace already exists"

# Build helm command
HELM_CMD="helm install $RELEASE_NAME . \
    --namespace $NAMESPACE \
    --set postgresql.auth.database=$DB_NAME \
    --set postgresql.auth.username=$DB_USER \
    --set postgresql.auth.password='$DB_PASSWORD' \
    --set postgresql.auth.postgresPassword='$POSTGRES_PASSWORD' \
    --set persistence.size=$STORAGE_SIZE"

if [[ -n "$STORAGE_CLASS" ]]; then
    HELM_CMD="$HELM_CMD --set persistence.storageClass=$STORAGE_CLASS"
fi

# Install
echo -e "${GREEN}Installing PostgreSQL...${NC}"
eval "$HELM_CMD"

# Wait for pod
echo ""
echo -e "${GREEN}Waiting for PostgreSQL to be ready...${NC}"
kubectl wait --for=condition=ready pod \
    -l app.kubernetes.io/name=postgresql \
    -n "$NAMESPACE" \
    --timeout=120s 2>&1 || {
    echo -e "${YELLOW}Timeout waiting. Checking status...${NC}"
    kubectl get pods -n "$NAMESPACE"
}

echo ""
echo -e "${GREEN}=========================================="
echo "  PostgreSQL Installation Complete!"
echo "==========================================${NC}"
echo ""
echo "Connection Details:"
echo "  Host: ${RELEASE_NAME}-postgresql.${NAMESPACE}.svc.cluster.local"
echo "  Port: 5432"
echo "  Database: $DB_NAME"
echo "  Username: $DB_USER"
echo ""
echo "To connect from within Kubernetes:"
echo "  psql -h ${RELEASE_NAME}-postgresql.${NAMESPACE}.svc.cluster.local -U $DB_USER -d $DB_NAME"
echo ""
echo "To connect from local machine:"
echo "  kubectl port-forward svc/${RELEASE_NAME}-postgresql 5432:5432 -n $NAMESPACE"
echo "  psql -h localhost -U $DB_USER -d $DB_NAME"
echo ""
echo "Use with Keycloak:"
echo "  cd ../keycloak-helm-chart"
echo "  ./install-external-db.sh"
echo ""
echo "  Enter these details when prompted:"
echo "    Host: ${RELEASE_NAME}-postgresql.${NAMESPACE}.svc.cluster.local"
echo "    Port: 5432"
echo "    Database: $DB_NAME"
echo "    Username: $DB_USER"
echo "    Password: <your password>"
echo ""
