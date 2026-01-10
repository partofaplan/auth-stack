# Authentication Stack for Kubernetes

This repository contains production-ready Helm charts for deploying a complete authentication stack on Kubernetes with built-in Rancher integration support.

## What's Included

### 1. Keycloak (Identity and Access Management)
Open-source IAM solution with:
- Single Sign-On (SSO)
- Identity Brokering and Social Login
- User Federation (LDAP/Active Directory)
- Standard Protocols (OpenID Connect, OAuth 2.0, SAML 2.0)
- Fine-grained Authorization

**Features**:
- High availability and clustering support
- Multiple deployment options (bundled or external database)
- Ingress with TLS support
- Rancher monitoring and project integration
- Production-ready defaults
- Horizontal Pod Autoscaling (optional)

### 2. PostgreSQL Database (Minimal & Standalone)
Lightweight PostgreSQL chart for Keycloak:
- Single-instance deployment
- Persistent storage
- Pre-configured for Keycloak
- Simple and easy to manage

## Quick Start Options

### Option 1: Complete Stack (PostgreSQL + Keycloak) ⭐

Deploy everything together:

```bash
# Step 1: Deploy PostgreSQL
cd postgresql-helm-chart
./install.sh

# Step 2: Deploy Keycloak
cd ../keycloak-helm-chart
./install-external-db.sh
# Enter PostgreSQL details from Step 1
```

**See**: [FULL-STACK-DEPLOYMENT.md](FULL-STACK-DEPLOYMENT.md) for complete guide

### Option 2: Keycloak Only (with external database)

If you already have a PostgreSQL database:

```bash
cd keycloak-helm-chart
./install-external-db.sh
```

### Option 3: Keycloak with Bundled Database

For quick testing:

```bash
cd keycloak-helm-chart
./install-simple.sh
```

## Quick Start

### Prerequisites

- Kubernetes 1.19+
- Helm 3.2.0+
- (Optional) PostgreSQL database (for external DB option)
- (Optional) PersistentVolume provisioner (for bundled DB option)
- (Optional) cert-manager for TLS
- (Optional) Rancher 2.5+ for Rancher features

### Installation

#### Option 1: External Database (Recommended) ⭐

Use an existing PostgreSQL database to avoid Helm dependency issues:

```bash
cd keycloak-helm-chart

# Interactive installation with external database
./install-external-db.sh

# OR manual installation
helm install keycloak . \
  -f values-external-db.yaml \
  --namespace keycloak \
  --create-namespace \
  --set keycloak.auth.adminPassword="YourSecurePassword" \
  --set keycloak.configuration.hostname="keycloak.yourdomain.com" \
  --set keycloak.configuration.database.hostname="postgres.example.com" \
  --set keycloak.configuration.database.password="YourDBPassword"
```

See [EXTERNAL-DATABASE-SETUP.md](keycloak-helm-chart/EXTERNAL-DATABASE-SETUP.md) for detailed setup.

#### Option 2: Bundled Database (Quick Testing)

Use the bundled PostgreSQL for quick testing:

```bash
cd keycloak-helm-chart

# Simple installation (no dependency issues)
./install-simple.sh

# OR with Helm dependencies
helm repo add bitnami https://charts.bitnami.com/bitnami
helm install keycloak . \
  --namespace keycloak \
  --create-namespace \
  --set keycloak.auth.adminPassword="YourSecurePassword" \
  --set postgresql.auth.password="YourDBPassword" \
  --set keycloak.configuration.hostname="keycloak.yourdomain.com"
```

## Repository Structure

```
auth-stack/
├── keycloak-helm-chart/          # Helm chart directory
│   ├── Chart.yaml                # Chart metadata
│   ├── values.yaml               # Default configuration values
│   ├── values-production.yaml    # Production-optimized values
│   ├── values-rancher.yaml       # Rancher-optimized values
│   ├── templates/                # Kubernetes manifest templates
│   │   ├── _helpers.tpl          # Template helpers
│   │   ├── statefulset.yaml      # Keycloak StatefulSet
│   │   ├── service.yaml          # Services (ClusterIP + Headless)
│   │   ├── ingress.yaml          # Ingress configuration
│   │   ├── configmap.yaml        # Configuration
│   │   ├── secret.yaml           # Secrets management
│   │   ├── serviceaccount.yaml   # Service account
│   │   ├── rbac.yaml             # RBAC resources
│   │   ├── servicemonitor.yaml   # Prometheus monitoring
│   │   └── poddisruptionbudget.yaml  # HA configuration
│   ├── rancher-questions.yaml    # Rancher catalog questions
│   ├── app-readme.md             # Rancher app description
│   ├── install.sh                # Interactive installation script
│   ├── README.md                 # Chart documentation
│   └── .helmignore               # Helm ignore patterns
├── DEPLOYMENT-GUIDE.md           # Comprehensive deployment guide
└── README.md                     # This file
```

## Features

### High Availability
- StatefulSet with configurable replicas
- Pod anti-affinity rules for distribution
- Pod Disruption Budget for controlled updates
- JGroups/Infinispan clustering
- Headless service for pod discovery

### Security
- RBAC with minimal permissions
- ServiceAccount per deployment
- Security contexts (runAsNonRoot, drop capabilities)
- Secret management with external secret support
- Network Policy support (optional)

### Storage
- PersistentVolume for Keycloak data
- PostgreSQL with persistent storage
- Configurable storage classes
- Support for Rancher Longhorn storage

### Networking
- Ingress with multiple controller support (NGINX, Traefik)
- TLS/SSL with cert-manager integration
- Proxy mode configuration (edge, reencrypt, passthrough)
- Service mesh ready

### Monitoring
- Prometheus metrics endpoint
- ServiceMonitor for Prometheus Operator
- Rancher monitoring integration
- Health and readiness probes
- Startup probes for slow initialization

### Rancher Integration
- Project labels and annotations
- Rancher catalog questions for UI deployment
- Longhorn storage class support
- Traefik ingress configuration
- ServiceMonitor for Rancher monitoring
- Compatible with Rancher authentication

### Database
- PostgreSQL subchart (Bitnami)
- External database support
- Connection pooling
- Read replicas support (optional)
- Backup configuration examples

## Deployment Scenarios

### 1. Development/Testing

```bash
helm install keycloak ./keycloak-helm-chart \
  --set keycloak.auth.adminPassword="admin" \
  --set postgresql.auth.password="postgres" \
  --namespace keycloak-dev \
  --create-namespace
```

### 2. Production

```bash
helm install keycloak ./keycloak-helm-chart \
  -f keycloak-helm-chart/values-production.yaml \
  --set keycloak.configuration.hostname="keycloak.production.com" \
  --namespace keycloak-prod \
  --create-namespace
```

### 3. Rancher Environment

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

## Configuration

### Key Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `keycloak.replicas` | Number of Keycloak replicas | `2` |
| `keycloak.auth.adminPassword` | Admin password | Required |
| `keycloak.configuration.hostname` | Public hostname | `keycloak.example.com` |
| `postgresql.enabled` | Enable PostgreSQL | `true` |
| `postgresql.auth.password` | Database password | Required |
| `ingress.enabled` | Enable ingress | `true` |
| `ingress.className` | Ingress class | `nginx` |
| `rancher.projectId` | Rancher project ID | `""` |
| `persistence.enabled` | Enable persistence | `true` |

See [values.yaml](keycloak-helm-chart/values.yaml) for complete configuration options.

## Documentation

- **[DEPLOYMENT-GUIDE.md](DEPLOYMENT-GUIDE.md)** - Comprehensive deployment guide
- **[keycloak-helm-chart/README.md](keycloak-helm-chart/README.md)** - Chart-specific documentation
- **[Keycloak Documentation](https://www.keycloak.org/documentation)** - Official Keycloak docs

## Common Operations

### Access Keycloak

```bash
# Via ingress (configured hostname)
https://keycloak.yourdomain.com

# Via port-forward (for testing)
kubectl port-forward svc/keycloak 8080:8080 -n keycloak
# Then access: http://localhost:8080
```

### View Logs

```bash
# View logs from all pods
kubectl logs -l app.kubernetes.io/name=keycloak -n keycloak --tail=100 -f

# View logs from specific pod
kubectl logs keycloak-0 -n keycloak -f
```

### Scale Deployment

```bash
# Scale to 3 replicas
helm upgrade keycloak ./keycloak-helm-chart \
  --reuse-values \
  --set keycloak.replicas=3 \
  -n keycloak
```

### Backup Database

```bash
# Backup PostgreSQL database
kubectl exec keycloak-postgresql-0 -n keycloak -- \
  pg_dump -U keycloak keycloak > keycloak-backup-$(date +%Y%m%d).sql
```

### Upgrade

```bash
# Update dependencies
cd keycloak-helm-chart
helm dependency update

# Upgrade release
helm upgrade keycloak . \
  --reuse-values \
  -n keycloak
```

### Uninstall

```bash
# Uninstall release
helm uninstall keycloak -n keycloak

# Delete PVCs (optional)
kubectl delete pvc -l app.kubernetes.io/instance=keycloak -n keycloak

# Delete namespace
kubectl delete namespace keycloak
```

## Troubleshooting

### Check Pod Status

```bash
kubectl get pods -n keycloak
kubectl describe pod keycloak-0 -n keycloak
kubectl logs keycloak-0 -n keycloak
```

### Database Connection Issues

```bash
# Test connectivity
kubectl exec -it keycloak-0 -n keycloak -- sh
nc -zv keycloak-postgresql 5432
```

### Ingress Issues

```bash
kubectl get ingress -n keycloak
kubectl describe ingress keycloak -n keycloak
```

See [DEPLOYMENT-GUIDE.md](DEPLOYMENT-GUIDE.md) for detailed troubleshooting steps.

## Production Checklist

- [ ] Strong passwords for admin and database
- [ ] External secret management configured
- [ ] TLS certificates configured (cert-manager)
- [ ] Resource limits set appropriately
- [ ] Pod Disruption Budget enabled
- [ ] Database backups configured
- [ ] Monitoring and alerting set up
- [ ] Log aggregation configured
- [ ] High availability tested (3+ replicas)
- [ ] Disaster recovery plan documented
- [ ] Network policies configured
- [ ] Security scan completed

## Contributing

Contributions are welcome! Please feel free to submit issues, fork the repository, and create pull requests.

## Support

For issues and questions:
- Chart Issues: Create an issue in this repository
- Keycloak Issues: [Keycloak Community](https://www.keycloak.org/community)
- Rancher Issues: [Rancher Forums](https://forums.rancher.com/)

## License

This Helm chart is provided as-is under the Apache 2.0 license.

## Resources

- [Keycloak Official Documentation](https://www.keycloak.org/documentation)
- [Keycloak Server Admin Guide](https://www.keycloak.org/docs/latest/server_admin/)
- [Rancher Documentation](https://rancher.com/docs/)
- [Helm Documentation](https://helm.sh/docs/)
- [PostgreSQL Bitnami Chart](https://github.com/bitnami/charts/tree/main/bitnami/postgresql)

## Version Information

- **Chart Version**: 1.0.0
- **Keycloak Version**: 24.0.1
- **PostgreSQL Version**: 12.x (Bitnami)
- **Kubernetes Version**: 1.19+
- **Helm Version**: 3.2.0+

---

**Built with ❤️ for Kubernetes and Rancher**
