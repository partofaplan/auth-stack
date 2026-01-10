# PostgreSQL Helm Chart

A minimal, production-ready PostgreSQL database chart designed for use with Keycloak.

## Features

- Single-instance PostgreSQL 16
- Persistent storage with StatefulSet
- Health checks and probes
- Configurable resources
- Pre-configured for Keycloak
- Simple and lightweight

## Quick Start

### Installation

#### Method 1: Direct Install (Recommended - No Helm Issues) ⭐

```bash
cd postgresql-helm-chart
./install-direct.sh
```

This installs PostgreSQL using kubectl directly, avoiding all Helm chart issues.

#### Method 2: Helm Chart Install

```bash
cd postgresql-helm-chart

# Clean any macOS attributes first
xattr -cr .

# Install with Helm
helm install postgres . \
  --namespace postgres \
  --create-namespace \
  --set postgresql.auth.password="YourPassword123" \
  --set postgresql.auth.postgresPassword="SuperUserPassword123"
```

**Note**: If you get "Chart.yaml file is missing" error, use Method 1 instead.

### Use with Keycloak

After installing PostgreSQL, use it with Keycloak:

```bash
cd ../keycloak-helm-chart

# Get the PostgreSQL service hostname
POSTGRES_HOST="postgres-postgresql.postgres.svc.cluster.local"

# Install Keycloak with external database
./install-external-db.sh

# When prompted, enter:
# Host: postgres-postgresql.postgres.svc.cluster.local
# Port: 5432
# Database: keycloak
# Username: keycloak
# Password: <your password>
```

## Configuration

### Key Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `postgresql.auth.database` | Database name | `keycloak` |
| `postgresql.auth.username` | Database user | `keycloak` |
| `postgresql.auth.password` | User password | `""` (required) |
| `postgresql.auth.postgresPassword` | Postgres superuser password | `""` (required) |
| `postgresql.image.tag` | PostgreSQL version | `16.2` |
| `postgresql.resources.requests.memory` | Memory request | `256Mi` |
| `postgresql.resources.limits.memory` | Memory limit | `1Gi` |
| `persistence.enabled` | Enable persistence | `true` |
| `persistence.size` | Volume size | `8Gi` |
| `persistence.storageClass` | Storage class | `""` (default) |

### Custom Values

Create a `my-values.yaml`:

```yaml
postgresql:
  auth:
    password: "MySecurePassword"
    postgresPassword: "SuperPassword"

  resources:
    requests:
      cpu: 500m
      memory: 512Mi
    limits:
      cpu: 1000m
      memory: 1Gi

persistence:
  size: 20Gi
  storageClass: "fast-ssd"
```

Install with custom values:

```bash
helm install postgres . -f my-values.yaml --namespace postgres --create-namespace
```

## Access Database

### From within Kubernetes

```bash
# Get password
kubectl get secret postgres-postgresql -n postgres -o jsonpath='{.data.password}' | base64 -d

# Connect from a pod
kubectl run -it --rm psql --image=postgres:16 --restart=Never -- \
  psql -h postgres-postgresql.postgres.svc.cluster.local -U keycloak -d keycloak
```

### From your local machine

```bash
# Port-forward
kubectl port-forward svc/postgres-postgresql 5432:5432 -n postgres

# Connect with psql
psql -h localhost -U keycloak -d keycloak
```

## Operations

### Backup

```bash
# Backup database
kubectl exec postgres-postgresql-0 -n postgres -- \
  pg_dump -U keycloak keycloak > backup.sql
```

### Restore

```bash
# Restore database
cat backup.sql | kubectl exec -i postgres-postgresql-0 -n postgres -- \
  psql -U keycloak -d keycloak
```

### Scale (Not Recommended)

This chart is designed for single-instance use. For high availability, consider using the Bitnami PostgreSQL chart or a managed database service.

## Uninstall

```bash
# Uninstall release
helm uninstall postgres -n postgres

# Delete PVC (optional)
kubectl delete pvc data-postgres-postgresql-0 -n postgres

# Delete namespace
kubectl delete namespace postgres
```

## Troubleshooting

### Pod not starting

```bash
# Check pod status
kubectl get pods -n postgres
kubectl describe pod postgres-postgresql-0 -n postgres
kubectl logs postgres-postgresql-0 -n postgres
```

### Storage issues

```bash
# Check PVC
kubectl get pvc -n postgres
kubectl describe pvc data-postgres-postgresql-0 -n postgres

# Check available storage classes
kubectl get storageclass
```

### Connection refused

```bash
# Test from within cluster
kubectl run -it --rm test --image=postgres:16 --restart=Never -n postgres -- \
  psql -h postgres-postgresql -U keycloak -d keycloak
```

## Complete Example with Keycloak

Deploy both PostgreSQL and Keycloak:

```bash
# 1. Install PostgreSQL
cd postgresql-helm-chart
helm install postgres . \
  --namespace postgres \
  --create-namespace \
  --set postgresql.auth.password="DBPassword123" \
  --set postgresql.auth.postgresPassword="SuperPassword123"

# Wait for PostgreSQL to be ready
kubectl wait --for=condition=ready pod postgres-postgresql-0 -n postgres --timeout=120s

# 2. Install Keycloak with external database
cd ../keycloak-helm-chart
helm install keycloak . \
  -f values-external-db.yaml \
  --namespace keycloak \
  --create-namespace \
  --set keycloak.auth.adminPassword="AdminPass123" \
  --set keycloak.configuration.hostname="keycloak.example.com" \
  --set keycloak.configuration.database.hostname="postgres-postgresql.postgres.svc.cluster.local" \
  --set keycloak.configuration.database.password="DBPassword123"

# Check status
kubectl get pods -n postgres
kubectl get pods -n keycloak
```

## Notes

- This is a minimal chart for development/testing or small production deployments
- For production high-availability, consider:
  - Managed database services (AWS RDS, Azure Database, Google Cloud SQL)
  - Bitnami PostgreSQL chart with replication
  - PostgreSQL operators (Zalando, Crunchy Data)
- The chart creates a single StatefulSet with one replica
- Data is persisted using PersistentVolumeClaims

## License

Apache 2.0
