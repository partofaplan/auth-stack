# Keycloak Helm Chart - Summary

## What Was Created

A complete, production-ready Keycloak Helm chart with Rancher integration support.

## Directory Structure

```
auth-stack/
├── keycloak-helm-chart/          # Main Helm chart directory
│   ├── Chart.yaml                # Chart metadata and dependencies
│   ├── values.yaml               # Default configuration
│   ├── values-production.yaml    # Production-optimized configuration
│   ├── values-rancher.yaml       # Rancher-specific configuration
│   ├── .helmignore               # Helm ignore patterns
│   ├── NOTES.txt                 # Post-install notes
│   ├── README.md                 # Chart documentation
│   ├── app-readme.md             # Rancher catalog description
│   ├── rancher-questions.yaml    # Rancher UI questions
│   ├── install.sh                # Interactive installation script
│   ├── validate.sh               # Chart validation script
│   ├── charts/                   # Dependencies (populated by helm dependency update)
│   └── templates/                # Kubernetes manifest templates
│       ├── _helpers.tpl          # Template helper functions
│       ├── statefulset.yaml      # Keycloak StatefulSet
│       ├── service.yaml          # Services (ClusterIP + Headless)
│       ├── ingress.yaml          # Ingress resource
│       ├── configmap.yaml        # Configuration
│       ├── secret.yaml           # Secrets
│       ├── serviceaccount.yaml   # Service Account
│       ├── rbac.yaml             # RBAC Role/RoleBinding
│       ├── servicemonitor.yaml   # Prometheus ServiceMonitor
│       └── poddisruptionbudget.yaml  # Pod Disruption Budget
├── DEPLOYMENT-GUIDE.md           # Comprehensive deployment guide
├── README.md                     # Repository overview
└── CHART-SUMMARY.md              # This file
```

## Key Features

### 1. High Availability
- StatefulSet with configurable replicas (default: 2)
- Pod anti-affinity rules for node distribution
- Pod Disruption Budget for controlled updates
- JGroups clustering for session replication
- Headless service for pod discovery

### 2. Database
- Integrated PostgreSQL (Bitnami chart)
- External database support
- Persistent storage with configurable StorageClass
- Optional read replicas
- Backup examples in deployment guide

### 3. Security
- RBAC with minimal permissions
- ServiceAccount per deployment
- Security contexts (runAsNonRoot, drop capabilities)
- Secret management with external secret support
- Optional Network Policy

### 4. Networking
- Ingress support (NGINX, Traefik)
- TLS/SSL with cert-manager integration
- Configurable proxy mode (edge, reencrypt, passthrough)
- Service mesh ready

### 5. Rancher Integration
- Project labels and annotations
- Rancher catalog questions for UI deployment
- Longhorn storage class support
- Traefik ingress configuration
- ServiceMonitor for Rancher monitoring
- Compatible with Rancher authentication

### 6. Monitoring
- Prometheus metrics endpoint (/metrics)
- ServiceMonitor for Prometheus Operator
- Health, readiness, and startup probes
- Configurable probe settings

### 7. Scalability
- Horizontal Pod Autoscaling (optional)
- Resource requests and limits
- Configurable replica count
- Persistent storage per pod

## Quick Start

### Prerequisites
```bash
# Required
- Kubernetes 1.19+
- Helm 3.2.0+
- kubectl configured

# Optional
- cert-manager (for TLS)
- Rancher 2.5+ (for Rancher features)
- Prometheus Operator (for monitoring)
```

### Installation

#### Option 1: Interactive Script
```bash
cd keycloak-helm-chart
./install.sh
```

#### Option 2: Manual Installation
```bash
cd keycloak-helm-chart

# Update dependencies
helm dependency update

# Install
helm install keycloak . \
  --namespace keycloak \
  --create-namespace \
  --set keycloak.auth.adminPassword="YourSecurePassword" \
  --set postgresql.auth.password="YourDBPassword" \
  --set keycloak.configuration.hostname="keycloak.yourdomain.com"
```

#### Option 3: Production Deployment
```bash
helm install keycloak ./keycloak-helm-chart \
  -f keycloak-helm-chart/values-production.yaml \
  --set keycloak.auth.adminPassword="SecurePassword" \
  --set postgresql.auth.password="DBPassword" \
  --set keycloak.configuration.hostname="keycloak.production.com" \
  --namespace keycloak-prod \
  --create-namespace
```

#### Option 4: Rancher Deployment
```bash
helm install keycloak ./keycloak-helm-chart \
  -f keycloak-helm-chart/values-rancher.yaml \
  --set keycloak.auth.adminPassword="SecurePassword" \
  --set postgresql.auth.password="DBPassword" \
  --set keycloak.configuration.hostname="keycloak.rancher.local" \
  --set rancher.projectId="c-m-xxxxx:p-xxxxx" \
  --namespace keycloak \
  --create-namespace
```

## Configuration Files

### values.yaml (Default)
- Development/testing configuration
- 2 replicas
- NGINX ingress
- Default storage classes
- All features enabled

### values-production.yaml
- Production-optimized settings
- 3 replicas with required anti-affinity
- Enhanced resource limits
- PostgreSQL with read replicas
- Autoscaling enabled
- Security hardening

### values-rancher.yaml
- Rancher-specific configuration
- Traefik ingress (Rancher default)
- Longhorn storage class
- Rancher monitoring enabled
- Project ID support

## Rancher Integration

### Rancher Catalog
The chart includes `rancher-questions.yaml` which provides:
- UI form for easy deployment
- Input validation
- Default values
- Conditional fields
- Password fields (hidden input)

### Rancher Monitoring
- ServiceMonitor automatically created
- Metrics endpoint: `/metrics`
- Integration with Rancher's Prometheus
- Grafana dashboard compatible

### Rancher Storage
- Longhorn storage class support
- Configured in `values-rancher.yaml`
- Persistent volumes for both Keycloak and PostgreSQL

## Validation

Before deployment, you can validate the chart:
```bash
cd keycloak-helm-chart
./validate.sh
```

This checks:
- Chart structure
- Helm syntax
- Template rendering
- Kubernetes manifest validity
- YAML syntax
- Dependencies

## Accessing Keycloak

After installation:

1. **Via Ingress** (if enabled):
   ```
   https://your-configured-hostname
   ```

2. **Via Port-Forward** (for testing):
   ```bash
   kubectl port-forward svc/keycloak 8080:8080 -n keycloak
   # Access at: http://localhost:8080
   ```

3. **Get Admin Password**:
   ```bash
   kubectl get secret keycloak-admin-secret -n keycloak \
     -o jsonpath='{.data.password}' | base64 -d
   ```

## Common Operations

### Scale
```bash
helm upgrade keycloak ./keycloak-helm-chart \
  --reuse-values \
  --set keycloak.replicas=3 \
  -n keycloak
```

### Upgrade
```bash
cd keycloak-helm-chart
helm dependency update
helm upgrade keycloak . --reuse-values -n keycloak
```

### Backup Database
```bash
kubectl exec keycloak-postgresql-0 -n keycloak -- \
  pg_dump -U keycloak keycloak > backup.sql
```

### View Logs
```bash
kubectl logs -f statefulset/keycloak -n keycloak
```

## Documentation

- **[README.md](README.md)**: Repository overview
- **[DEPLOYMENT-GUIDE.md](DEPLOYMENT-GUIDE.md)**: Comprehensive deployment guide
- **[keycloak-helm-chart/README.md](keycloak-helm-chart/README.md)**: Chart-specific documentation

## Next Steps

1. **Customize Configuration**
   - Review `values.yaml`
   - Set appropriate hostnames
   - Configure TLS certificates
   - Set resource limits

2. **Deploy to Dev/Test**
   - Use default values
   - Test basic functionality
   - Verify ingress and TLS

3. **Deploy to Production**
   - Use `values-production.yaml`
   - Set strong passwords
   - Enable monitoring
   - Configure backups

4. **Rancher Integration**
   - Use `values-rancher.yaml`
   - Set Rancher project ID
   - Configure Longhorn storage
   - Enable monitoring

5. **Configure Keycloak**
   - Create realms
   - Add clients
   - Configure users
   - Set up identity providers

## Support

- **Chart Issues**: Create an issue in this repository
- **Keycloak Issues**: https://www.keycloak.org/community
- **Rancher Issues**: https://forums.rancher.com/

## Version Information

- Chart Version: 1.0.0
- Keycloak Version: 24.0.1
- PostgreSQL Chart: 12.x (Bitnami)
- Kubernetes: 1.19+
- Helm: 3.2.0+
