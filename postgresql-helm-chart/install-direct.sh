#!/bin/bash

# PostgreSQL Direct Install Script
# This script installs PostgreSQL using kubectl directly, bypassing Helm issues

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}=========================================="
echo "  PostgreSQL Direct Installer"
echo "  (No Helm chart needed)"
echo "==========================================${NC}"
echo ""

# Get configuration
read -p "Enter namespace (default: postgres): " NAMESPACE
NAMESPACE=${NAMESPACE:-postgres}

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
echo -e "${GREEN}[1/5] Creating namespace...${NC}"
kubectl create namespace "$NAMESPACE" 2>/dev/null || echo "  Namespace already exists"

# Create secret
echo -e "${GREEN}[2/5] Creating secret...${NC}"
kubectl create secret generic postgresql-secret \
    --from-literal=postgres-password="$POSTGRES_PASSWORD" \
    --from-literal=password="$DB_PASSWORD" \
    --from-literal=username="$DB_USER" \
    --from-literal=database="$DB_NAME" \
    -n "$NAMESPACE" \
    --dry-run=client -o yaml | kubectl apply -f -

# Create PVC
echo -e "${GREEN}[3/5] Creating persistent volume claim...${NC}"
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: postgresql-data
  namespace: $NAMESPACE
spec:
  accessModes:
    - ReadWriteOnce
  ${STORAGE_CLASS:+storageClassName: $STORAGE_CLASS}
  resources:
    requests:
      storage: $STORAGE_SIZE
EOF

# Create StatefulSet
echo -e "${GREEN}[4/5] Creating PostgreSQL StatefulSet...${NC}"
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: postgresql
  namespace: $NAMESPACE
  labels:
    app: postgresql
spec:
  serviceName: postgresql
  replicas: 1
  selector:
    matchLabels:
      app: postgresql
  template:
    metadata:
      labels:
        app: postgresql
    spec:
      securityContext:
        fsGroup: 999
      containers:
      - name: postgresql
        image: postgres:16.2
        imagePullPolicy: IfNotPresent
        securityContext:
          runAsUser: 999
          runAsNonRoot: true
        env:
        - name: POSTGRES_USER
          valueFrom:
            secretKeyRef:
              name: postgresql-secret
              key: username
        - name: POSTGRES_PASSWORD
          valueFrom:
            secretKeyRef:
              name: postgresql-secret
              key: password
        - name: POSTGRES_DB
          valueFrom:
            secretKeyRef:
              name: postgresql-secret
              key: database
        - name: POSTGRES_POSTGRES_PASSWORD
          valueFrom:
            secretKeyRef:
              name: postgresql-secret
              key: postgres-password
        - name: PGDATA
          value: /var/lib/postgresql/data/pgdata
        ports:
        - name: postgresql
          containerPort: 5432
          protocol: TCP
        livenessProbe:
          exec:
            command:
              - /bin/sh
              - -c
              - exec pg_isready -U $DB_USER -d $DB_NAME -h 127.0.0.1 -p 5432
          initialDelaySeconds: 30
          periodSeconds: 10
          timeoutSeconds: 5
          failureThreshold: 6
        readinessProbe:
          exec:
            command:
              - /bin/sh
              - -c
              - -e
              - |
                exec pg_isready -U $DB_USER -d $DB_NAME -h 127.0.0.1 -p 5432
                [ -f /var/lib/postgresql/data/pgdata/postmaster.pid ]
          initialDelaySeconds: 5
          periodSeconds: 10
          timeoutSeconds: 5
          failureThreshold: 6
        resources:
          requests:
            cpu: 250m
            memory: 256Mi
          limits:
            cpu: 1000m
            memory: 1Gi
        volumeMounts:
        - name: data
          mountPath: /var/lib/postgresql/data
      volumes:
      - name: data
        persistentVolumeClaim:
          claimName: postgresql-data
EOF

# Create Service
echo -e "${GREEN}[5/5] Creating PostgreSQL service...${NC}"
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: postgresql
  namespace: $NAMESPACE
  labels:
    app: postgresql
spec:
  type: ClusterIP
  ports:
  - name: postgresql
    port: 5432
    targetPort: postgresql
    protocol: TCP
  selector:
    app: postgresql
EOF

# Wait for pod
echo ""
echo -e "${GREEN}Waiting for PostgreSQL to be ready...${NC}"
kubectl wait --for=condition=ready pod \
    -l app=postgresql \
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
echo "  Host: postgresql.${NAMESPACE}.svc.cluster.local"
echo "  Port: 5432"
echo "  Database: $DB_NAME"
echo "  Username: $DB_USER"
echo ""
echo "To connect from within Kubernetes:"
echo "  psql -h postgresql.${NAMESPACE}.svc.cluster.local -U $DB_USER -d $DB_NAME"
echo ""
echo "To connect from local machine:"
echo "  kubectl port-forward svc/postgresql 5432:5432 -n $NAMESPACE"
echo "  psql -h localhost -U $DB_USER -d $DB_NAME"
echo ""
echo "Use with Keycloak:"
echo "  cd ../keycloak-helm-chart"
echo "  ./install-external-db.sh"
echo ""
echo "  Enter these details when prompted:"
echo "    Host: postgresql.${NAMESPACE}.svc.cluster.local"
echo "    Port: 5432"
echo "    Database: $DB_NAME"
echo "    Username: $DB_USER"
echo "    Password: <your password>"
echo ""
echo "To uninstall:"
echo "  kubectl delete statefulset postgresql -n $NAMESPACE"
echo "  kubectl delete service postgresql -n $NAMESPACE"
echo "  kubectl delete pvc postgresql-data -n $NAMESPACE"
echo "  kubectl delete secret postgresql-secret -n $NAMESPACE"
echo "  kubectl delete namespace $NAMESPACE"
echo ""
