#!/bin/bash

# Simple Keycloak Installation Script
# This script bypasses helm dependency update and uses direct values

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo "=========================================="
echo "  Keycloak Simple Installer"
echo "=========================================="
echo ""

# Get user input
read -p "Enter namespace (default: keycloak): " NAMESPACE
NAMESPACE=${NAMESPACE:-keycloak}

read -p "Enter Helm release name (default: keycloak): " RELEASE_NAME
RELEASE_NAME=${RELEASE_NAME:-keycloak}

read -p "Enter Keycloak hostname (e.g., keycloak.example.com): " HOSTNAME
while [[ -z "$HOSTNAME" ]]; do
    echo -e "${YELLOW}Hostname is required!${NC}"
    read -p "Enter Keycloak hostname: " HOSTNAME
done

read -sp "Enter admin password: " ADMIN_PASSWORD
echo ""
while [[ -z "$ADMIN_PASSWORD" ]]; do
    echo -e "${YELLOW}Admin password is required!${NC}"
    read -sp "Enter admin password: " ADMIN_PASSWORD
    echo ""
done

read -sp "Enter database password: " DB_PASSWORD
echo ""
while [[ -z "$DB_PASSWORD" ]]; do
    echo -e "${YELLOW}Database password is required!${NC}"
    read -sp "Enter database password: " DB_PASSWORD
    echo ""
done

read -p "Enter number of replicas (default: 2): " REPLICAS
REPLICAS=${REPLICAS:-2}

read -p "Enter ingress class (nginx/traefik, default: nginx): " INGRESS_CLASS
INGRESS_CLASS=${INGRESS_CLASS:-nginx}

echo ""
echo "Configuration:"
echo "  Namespace: $NAMESPACE"
echo "  Release: $RELEASE_NAME"
echo "  Hostname: $HOSTNAME"
echo "  Replicas: $REPLICAS"
echo "  Ingress Class: $INGRESS_CLASS"
echo ""

read -p "Proceed? (y/n): " CONFIRM
if [[ "$CONFIRM" != "y" && "$CONFIRM" != "Y" ]]; then
    echo "Installation cancelled."
    exit 0
fi

echo ""
echo "Installing..."

# Create namespace
echo -e "${GREEN}[1/4]${NC} Creating namespace..."
kubectl create namespace "$NAMESPACE" 2>/dev/null || echo "  Namespace already exists"

# Create secrets
echo -e "${GREEN}[2/4]${NC} Creating secrets..."
kubectl create secret generic keycloak-admin-secret \
    --from-literal=password="$ADMIN_PASSWORD" \
    -n "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

kubectl create secret generic "$RELEASE_NAME-postgresql" \
    --from-literal=password="$DB_PASSWORD" \
    -n "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -

# Add Bitnami repo
echo -e "${GREEN}[3/4]${NC} Adding PostgreSQL Helm repository..."
helm repo add bitnami https://charts.bitnami.com/bitnami 2>/dev/null || true
helm repo update

# Install chart
echo -e "${GREEN}[4/4]${NC} Installing Keycloak..."
helm install "$RELEASE_NAME" . \
    --namespace "$NAMESPACE" \
    --set keycloak.replicas="$REPLICAS" \
    --set keycloak.auth.adminUser=admin \
    --set keycloak.auth.existingSecret=keycloak-admin-secret \
    --set keycloak.configuration.hostname="$HOSTNAME" \
    --set ingress.className="$INGRESS_CLASS" \
    --set ingress.hosts[0].host="$HOSTNAME" \
    --set ingress.hosts[0].paths[0].path="/" \
    --set ingress.hosts[0].paths[0].pathType="Prefix" \
    --set ingress.tls[0].secretName=keycloak-tls \
    --set ingress.tls[0].hosts[0]="$HOSTNAME" \
    --set postgresql.enabled=true \
    --set postgresql.auth.existingSecret="$RELEASE_NAME-postgresql"

echo ""
echo -e "${GREEN}=========================================="
echo "  Installation Complete!"
echo "==========================================${NC}"
echo ""
echo "Access Details:"
echo "  URL: https://$HOSTNAME"
echo "  Admin Username: admin"
echo "  Admin Password: <the password you entered>"
echo ""
echo "Checking pod status..."
kubectl get pods -n "$NAMESPACE"
echo ""
echo "To view logs:"
echo "  kubectl logs -f statefulset/$RELEASE_NAME -n $NAMESPACE"
echo ""
echo "To port-forward (for local testing):"
echo "  kubectl port-forward svc/$RELEASE_NAME 8080:8080 -n $NAMESPACE"
echo ""
