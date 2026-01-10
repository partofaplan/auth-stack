# Keycloak Deployment Guide for Kubernetes with Rancher

This guide will walk you through deploying Keycloak to Kubernetes using Helm, with special considerations for Rancher integration.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Quick Start](#quick-start)
3. [Rancher Deployment](#rancher-deployment)
4. [Production Deployment](#production-deployment)
5. [Post-Deployment Configuration](#post-deployment-configuration)
6. [Troubleshooting](#troubleshooting)

## Prerequisites

### Required
- Kubernetes cluster (1.19+)
- Helm 3.2.0+
- kubectl configured to access your cluster
- Persistent volume provisioner

### Optional (for full features)
- cert-manager (for automatic TLS certificates)
- Rancher 2.5+ (for Rancher integration)
- Prometheus Operator (for monitoring)

### Verify Prerequisites

```bash
# Check Kubernetes version
kubectl version --short

# Check Helm version
helm version --short

# Check if cert-manager is installed (optional)
kubectl get pods -n cert-manager

# Check available storage classes
kubectl get storageclass
```

## Quick Start

### 1. Clone or Navigate to Chart Directory

```bash
cd keycloak-helm-chart
```

### 2. Update Helm Dependencies

```bash
helm dependency update
```

This will download the PostgreSQL subchart from Bitnami.

### 3. Create Secrets

Instead of passing passwords via command line, create secrets:

```bash
# Create namespace
kubectl create namespace keycloak

# Create admin secret
kubectl create secret generic keycloak-admin-secret \
  --from-literal=password='YourSecureAdminPassword123!' \
  -n keycloak

# Create PostgreSQL secret
kubectl create secret generic keycloak-postgresql \
  --from-literal=password='YourSecureDBPassword123!' \
  -n keycloak
```

### 4. Create Custom Values File

```bash
cat > my-values.yaml <<EOF
keycloak:
  replicas: 2
  auth:
    adminUser: admin
    existingSecret: "keycloak-admin-secret"
  configuration:
    hostname: keycloak.yourdomain.com

postgresql:
  auth:
    existingSecret: "keycloak-postgresql"

ingress:
  enabled: true
  className: "nginx"
  hosts:
    - host: keycloak.yourdomain.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: keycloak-tls
      hosts:
        - keycloak.yourdomain.com
EOF
```

### 5. Install the Chart

```bash
helm install keycloak . \
  -f my-values.yaml \
  --namespace keycloak
```

### 6. Verify Deployment

```bash
# Watch pods starting
kubectl get pods -n keycloak -w

# Check all resources
kubectl get all -n keycloak

# Check ingress
kubectl get ingress -n keycloak
```

## Rancher Deployment

### Method 1: Using Rancher UI (Recommended)

1. **Navigate to Apps & Marketplace**
   - In Rancher UI, go to your cluster
   - Click on "Apps & Marketplace" → "Charts"

2. **Add Custom Catalog (if chart is in a repo)**
   - Go to "Cluster Tools" → "Catalogs"
   - Add your Helm repository

3. **Install from Catalog**
   - Search for "Keycloak"
   - Click "Install"
   - Fill in the form (powered by `rancher-questions.yaml`)
   - Click "Install"

### Method 2: Using Helm with Rancher-specific Values

```bash
# Get your Rancher project ID
kubectl get projects -A

# Create values file for Rancher
cat > rancher-values.yaml <<EOF
keycloak:
  replicas: 2
  auth:
    adminUser: admin
    adminPassword: "YourSecurePassword123!"
  configuration:
    hostname: keycloak.yourdomain.com

postgresql:
  auth:
    password: "YourDBPassword123!"
  primary:
    persistence:
      storageClass: "longhorn"  # Rancher's Longhorn storage

persistence:
  storageClass: "longhorn"

ingress:
  enabled: true
  className: "traefik"  # Rancher's default ingress
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
  hosts:
    - host: keycloak.yourdomain.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: keycloak-tls
      hosts:
        - keycloak.yourdomain.com

rancher:
  projectId: "c-m-xxxxx:p-xxxxx"  # Your Rancher project ID
  monitoring:
    enabled: true
    serviceMonitor:
      enabled: true
EOF

# Install with Rancher values
helm install keycloak . \
  -f rancher-values.yaml \
  --namespace keycloak \
  --create-namespace
```

### Method 3: Using Pre-configured Rancher Values

```bash
# Use the provided values-rancher.yaml
helm install keycloak . \
  -f values-rancher.yaml \
  --set keycloak.auth.adminPassword="YourPassword" \
  --set postgresql.auth.password="YourDBPassword" \
  --set keycloak.configuration.hostname="keycloak.yourdomain.com" \
  --set rancher.projectId="c-m-xxxxx:p-xxxxx" \
  --namespace keycloak \
  --create-namespace
```

### Rancher Monitoring Integration

After deployment, if you have Rancher monitoring enabled:

1. **View Metrics in Rancher**
   - Go to your cluster in Rancher
   - Navigate to "Monitoring"
   - Search for "keycloak" in Grafana dashboards

2. **ServiceMonitor**
   - The chart automatically creates a ServiceMonitor
   - Prometheus will scrape metrics from `/metrics` endpoint
   - Metrics available at: `http://keycloak:8080/metrics`

3. **Custom Grafana Dashboard**
   - Import Keycloak Grafana dashboards
   - Dashboard IDs: 10441, 11665 (from grafana.com)

## Production Deployment

### 1. Use Production Values

```bash
# Use the provided production values
helm install keycloak . \
  -f values-production.yaml \
  --set keycloak.configuration.hostname="keycloak.production.com" \
  --namespace keycloak-prod \
  --create-namespace
```

### 2. Production Checklist

- [ ] Use strong, randomly generated passwords
- [ ] Store secrets in external secret management (Vault, AWS Secrets Manager, etc.)
- [ ] Enable TLS with cert-manager
- [ ] Configure resource limits appropriately
- [ ] Enable Pod Disruption Budget
- [ ] Configure backup for PostgreSQL
- [ ] Set up monitoring and alerting
- [ ] Configure log aggregation
- [ ] Test disaster recovery procedures
- [ ] Enable horizontal pod autoscaling
- [ ] Configure network policies
- [ ] Review and harden security contexts

### 3. External Secrets Example

```bash
# Install External Secrets Operator (if not already installed)
helm repo add external-secrets https://charts.external-secrets.io
helm install external-secrets external-secrets/external-secrets -n external-secrets --create-namespace

# Create SecretStore (example for AWS Secrets Manager)
cat <<EOF | kubectl apply -f -
apiVersion: external-secrets.io/v1beta1
kind: SecretStore
metadata:
  name: aws-secrets
  namespace: keycloak
spec:
  provider:
    aws:
      service: SecretsManager
      region: us-west-2
      auth:
        jwt:
          serviceAccountRef:
            name: external-secrets-sa
EOF

# Create ExternalSecret
cat <<EOF | kubectl apply -f -
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: keycloak-admin-secret
  namespace: keycloak
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: aws-secrets
    kind: SecretStore
  target:
    name: keycloak-admin-secret
  data:
  - secretKey: password
    remoteRef:
      key: keycloak/admin-password
EOF
```

### 4. PostgreSQL Backup Configuration

```bash
# Create a CronJob for PostgreSQL backups
cat <<EOF | kubectl apply -f -
apiVersion: batch/v1
kind: CronJob
metadata:
  name: keycloak-db-backup
  namespace: keycloak
spec:
  schedule: "0 2 * * *"  # Daily at 2 AM
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: backup
            image: postgres:14
            env:
            - name: PGPASSWORD
              valueFrom:
                secretKeyRef:
                  name: keycloak-postgresql
                  key: password
            command:
            - /bin/sh
            - -c
            - |
              pg_dump -h keycloak-postgresql -U keycloak keycloak | \
              gzip > /backup/keycloak-\$(date +%Y%m%d-%H%M%S).sql.gz
            volumeMounts:
            - name: backup
              mountPath: /backup
          restartPolicy: OnFailure
          volumes:
          - name: backup
            persistentVolumeClaim:
              claimName: keycloak-backup-pvc
EOF
```

## Post-Deployment Configuration

### 1. Access Keycloak Admin Console

```bash
# Get the admin password (if not using external secret)
kubectl get secret keycloak-admin-secret -n keycloak -o jsonpath='{.data.password}' | base64 -d

# Access via ingress
echo "Access Keycloak at: https://$(kubectl get ingress keycloak -n keycloak -o jsonpath='{.spec.rules[0].host}')"

# Or use port-forward for testing
kubectl port-forward svc/keycloak 8080:8080 -n keycloak
# Then access at: http://localhost:8080
```

### 2. Initial Configuration

1. **Log in to Admin Console**
   - URL: `https://keycloak.yourdomain.com`
   - Username: `admin` (or your configured username)
   - Password: Your admin password

2. **Create a Realm**
   - Click "Add realm"
   - Name it (e.g., "myrealm")
   - Click "Create"

3. **Create a Client**
   - Go to "Clients" → "Create"
   - Client ID: your-app-id
   - Client Protocol: openid-connect
   - Root URL: https://your-app.com

4. **Create Users**
   - Go to "Users" → "Add user"
   - Fill in details
   - Set credentials under "Credentials" tab

### 3. Configure Rancher Authentication (Optional)

To use Keycloak for Rancher authentication:

1. **In Keycloak**:
   - Create a new client for Rancher
   - Client ID: `rancher`
   - Client Protocol: `openid-connect`
   - Access Type: `confidential`
   - Valid Redirect URIs: `https://your-rancher.com/*`
   - Copy the client secret from Credentials tab

2. **In Rancher**:
   - Go to "Security" → "Authentication"
   - Select "Keycloak (OIDC)"
   - Fill in:
     - Endpoints: `https://keycloak.yourdomain.com/realms/master`
     - Client ID: `rancher`
     - Client Secret: (from Keycloak)
   - Test and enable

## Troubleshooting

### Pods Not Starting

```bash
# Check pod status
kubectl get pods -n keycloak

# Describe pod
kubectl describe pod keycloak-0 -n keycloak

# Check logs
kubectl logs keycloak-0 -n keycloak

# Check previous logs if pod is restarting
kubectl logs keycloak-0 -n keycloak --previous
```

### Database Connection Issues

```bash
# Check PostgreSQL pod
kubectl get pods -n keycloak | grep postgresql

# Test database connectivity from Keycloak pod
kubectl exec -it keycloak-0 -n keycloak -- sh
nc -zv keycloak-postgresql 5432

# Check PostgreSQL logs
kubectl logs keycloak-postgresql-0 -n keycloak
```

### Ingress Not Working

```bash
# Check ingress resource
kubectl get ingress -n keycloak
kubectl describe ingress keycloak -n keycloak

# Check ingress controller
kubectl get pods -n ingress-nginx  # or traefik

# Test internal service
kubectl run -it --rm debug --image=busybox --restart=Never -- wget -O- http://keycloak.keycloak.svc.cluster.local:8080
```

### Certificate Issues

```bash
# Check certificate
kubectl get certificate -n keycloak
kubectl describe certificate keycloak-tls -n keycloak

# Check cert-manager logs
kubectl logs -n cert-manager deployment/cert-manager

# Check certificate request
kubectl get certificaterequest -n keycloak
```

### Clustering Issues

```bash
# Check if pods can communicate
kubectl exec -it keycloak-0 -n keycloak -- sh
nc -zv keycloak-1.keycloak-headless 7600

# Check JGroups in logs
kubectl logs keycloak-0 -n keycloak | grep -i jgroups
```

### Performance Issues

```bash
# Check resource usage
kubectl top pods -n keycloak

# Increase resources
helm upgrade keycloak . \
  --reuse-values \
  --set keycloak.resources.limits.cpu=3000m \
  --set keycloak.resources.limits.memory=3Gi \
  -n keycloak
```

## Upgrade Guide

```bash
# Update dependencies
helm dependency update

# Test upgrade (dry-run)
helm upgrade keycloak . \
  --dry-run \
  --reuse-values \
  -n keycloak

# Perform upgrade
helm upgrade keycloak . \
  --reuse-values \
  -n keycloak

# Rollback if needed
helm rollback keycloak -n keycloak
```

## Backup and Restore

### Backup

```bash
# Backup Keycloak database
kubectl exec keycloak-postgresql-0 -n keycloak -- \
  pg_dump -U keycloak keycloak > keycloak-backup-$(date +%Y%m%d).sql

# Backup Helm values
helm get values keycloak -n keycloak > keycloak-values-backup.yaml
```

### Restore

```bash
# Restore database
kubectl exec -i keycloak-postgresql-0 -n keycloak -- \
  psql -U keycloak keycloak < keycloak-backup-20240101.sql

# Restart Keycloak pods
kubectl rollout restart statefulset/keycloak -n keycloak
```

## Uninstall

```bash
# Uninstall Helm release
helm uninstall keycloak -n keycloak

# Delete PVCs (if you want to delete data)
kubectl delete pvc -l app.kubernetes.io/instance=keycloak -n keycloak

# Delete namespace
kubectl delete namespace keycloak
```

## Additional Resources

- [Keycloak Official Documentation](https://www.keycloak.org/documentation)
- [Keycloak Server Administration Guide](https://www.keycloak.org/docs/latest/server_admin/)
- [Rancher Documentation](https://rancher.com/docs/)
- [Helm Documentation](https://helm.sh/docs/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
