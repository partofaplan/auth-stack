#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Keycloak Auth Stack Deployment${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Create namespace
echo -e "${YELLOW}Creating namespace...${NC}"
kubectl create namespace keycloak 2>/dev/null || echo "Namespace already exists"
echo ""

# Deploy PostgreSQL
echo -e "${YELLOW}Deploying PostgreSQL...${NC}"

# Create PostgreSQL secret
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: postgresql-secret
  namespace: keycloak
type: Opaque
stringData:
  postgres-password: "postgres123"
  password: "keycloak123"
  username: "keycloak"
  database: "keycloak"
EOF

# Create PostgreSQL PVC
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: postgresql-data
  namespace: keycloak
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 8Gi
EOF

# Create PostgreSQL StatefulSet
cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: postgresql
  namespace: keycloak
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
              - exec pg_isready -U keycloak -d keycloak -h 127.0.0.1 -p 5432
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
                exec pg_isready -U keycloak -d keycloak -h 127.0.0.1 -p 5432
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

# Create PostgreSQL Service
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: postgresql
  namespace: keycloak
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

echo -e "${GREEN}PostgreSQL deployed${NC}"
echo ""

# Wait for PostgreSQL to be ready
echo -e "${YELLOW}Waiting for PostgreSQL to be ready...${NC}"
kubectl wait --for=condition=ready pod -l app=postgresql -n keycloak --timeout=120s

# Fix PostgreSQL password for SCRAM-SHA-256
echo -e "${YELLOW}Configuring PostgreSQL authentication...${NC}"
kubectl exec postgresql-0 -n keycloak -- psql -U keycloak -d keycloak -c "ALTER USER keycloak WITH PASSWORD 'keycloak123';" > /dev/null 2>&1
echo -e "${GREEN}PostgreSQL ready${NC}"
echo ""

# Deploy Keycloak
echo -e "${YELLOW}Deploying Keycloak...${NC}"

# Create Keycloak secret
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Secret
metadata:
  name: keycloak-secret
  namespace: keycloak
type: Opaque
stringData:
  admin-password: "admin123"
  db-password: "keycloak123"
EOF

# Create Keycloak ServiceAccount
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: keycloak
  namespace: keycloak
EOF

# Create Keycloak RBAC
cat <<EOF | kubectl apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: keycloak
  namespace: keycloak
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "list"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: keycloak
  namespace: keycloak
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: keycloak
subjects:
- kind: ServiceAccount
  name: keycloak
  namespace: keycloak
EOF

# Create Keycloak StatefulSet
cat <<'EOF' | kubectl apply -f -
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: keycloak
  namespace: keycloak
  labels:
    app: keycloak
spec:
  serviceName: keycloak-headless
  replicas: 2
  selector:
    matchLabels:
      app: keycloak
  template:
    metadata:
      labels:
        app: keycloak
    spec:
      serviceAccountName: keycloak
      securityContext:
        fsGroup: 1000
        runAsUser: 1000
        runAsNonRoot: true
      initContainers:
      - name: keycloak-build
        image: quay.io/keycloak/keycloak:24.0.1
        imagePullPolicy: IfNotPresent
        securityContext:
          allowPrivilegeEscalation: false
          capabilities:
            drop:
              - ALL
        args:
          - build
          - --db=postgres
          - --health-enabled=true
          - --metrics-enabled=true
          - --cache=ispn
          - --cache-stack=kubernetes
        env:
        - name: KC_DB
          value: "postgres"
        volumeMounts:
        - name: keycloak-data
          mountPath: /opt/keycloak/data
      containers:
      - name: keycloak
        image: quay.io/keycloak/keycloak:24.0.1
        imagePullPolicy: IfNotPresent
        securityContext:
          allowPrivilegeEscalation: false
          capabilities:
            drop:
              - ALL
        args:
          - start
        env:
        - name: KEYCLOAK_ADMIN
          value: "admin"
        - name: KEYCLOAK_ADMIN_PASSWORD
          valueFrom:
            secretKeyRef:
              name: keycloak-secret
              key: admin-password
        - name: KC_DB
          value: "postgres"
        - name: KC_DB_URL_HOST
          value: "postgresql.keycloak.svc.cluster.local"
        - name: KC_DB_URL_PORT
          value: "5432"
        - name: KC_DB_URL_DATABASE
          value: "keycloak"
        - name: KC_DB_USERNAME
          value: "keycloak"
        - name: KC_DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: keycloak-secret
              key: db-password
        - name: KC_HOSTNAME
          value: "keycloak.local"
        - name: KC_HOSTNAME_STRICT
          value: "false"
        - name: KC_HOSTNAME_STRICT_HTTPS
          value: "false"
        - name: KC_PROXY_HEADERS
          value: "xforwarded"
        - name: KC_HTTP_ENABLED
          value: "true"
        - name: KC_HEALTH_ENABLED
          value: "true"
        - name: KC_METRICS_ENABLED
          value: "true"
        - name: KC_CACHE
          value: "ispn"
        - name: KC_CACHE_STACK
          value: "kubernetes"
        - name: JAVA_OPTS_APPEND
          value: "-Djgroups.dns.query=keycloak-headless.keycloak.svc.cluster.local"
        ports:
        - name: http
          containerPort: 8080
          protocol: TCP
        - name: jgroups
          containerPort: 7600
          protocol: TCP
        livenessProbe:
          httpGet:
            path: /health/live
            port: 8080
          initialDelaySeconds: 60
          periodSeconds: 10
          timeoutSeconds: 5
          failureThreshold: 6
        readinessProbe:
          httpGet:
            path: /health/ready
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 10
          timeoutSeconds: 5
          failureThreshold: 6
        startupProbe:
          httpGet:
            path: /health/started
            port: 8080
          initialDelaySeconds: 30
          periodSeconds: 10
          timeoutSeconds: 5
          failureThreshold: 30
        resources:
          requests:
            cpu: 500m
            memory: 512Mi
          limits:
            cpu: 2000m
            memory: 2Gi
        volumeMounts:
        - name: keycloak-data
          mountPath: /opt/keycloak/data
  volumeClaimTemplates:
  - metadata:
      name: keycloak-data
    spec:
      accessModes: [ "ReadWriteOnce" ]
      resources:
        requests:
          storage: 1Gi
EOF

# Create Keycloak Services
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: keycloak
  namespace: keycloak
  labels:
    app: keycloak
spec:
  type: ClusterIP
  ports:
  - name: http
    port: 8080
    targetPort: http
    protocol: TCP
  selector:
    app: keycloak
---
apiVersion: v1
kind: Service
metadata:
  name: keycloak-headless
  namespace: keycloak
  labels:
    app: keycloak
spec:
  clusterIP: None
  ports:
  - name: http
    port: 8080
    targetPort: http
    protocol: TCP
  - name: jgroups
    port: 7600
    targetPort: jgroups
    protocol: TCP
  selector:
    app: keycloak
EOF

# Create Keycloak Ingress
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: keycloak
  namespace: keycloak
  annotations:
    traefik.ingress.kubernetes.io/router.entrypoints: web
spec:
  ingressClassName: traefik
  rules:
  - host: keycloak.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: keycloak
            port:
              number: 8080
EOF

# Create PodDisruptionBudget
cat <<EOF | kubectl apply -f -
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: keycloak
  namespace: keycloak
spec:
  minAvailable: 1
  selector:
    matchLabels:
      app: keycloak
EOF

echo -e "${GREEN}Keycloak deployed${NC}"
echo ""

# Wait for Keycloak to be ready
echo -e "${YELLOW}Waiting for Keycloak pods to be ready (this may take 2-3 minutes)...${NC}"
kubectl wait --for=condition=ready pod -l app=keycloak -n keycloak --timeout=300s

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Deployment Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "Access Keycloak at: ${GREEN}http://keycloak.local/admin/${NC}"
echo ""
echo -e "Admin credentials:"
echo -e "  Username: ${GREEN}admin${NC}"
echo -e "  Password: ${GREEN}admin123${NC}"
echo ""
echo -e "Database credentials:"
echo -e "  Database: ${GREEN}keycloak${NC}"
echo -e "  Username: ${GREEN}keycloak${NC}"
echo -e "  Password: ${GREEN}keycloak123${NC}"
echo ""
echo -e "View resources:"
echo -e "  ${YELLOW}kubectl get all,pvc,ingress -n keycloak${NC}"
echo ""
echo -e "View logs:"
echo -e "  ${YELLOW}kubectl logs -f keycloak-0 -n keycloak${NC}"
echo ""
