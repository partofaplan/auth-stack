# External Database Setup Guide

This guide explains how to deploy Keycloak using an external PostgreSQL database instead of the bundled one.

## Why Use an External Database?

- **Avoid Helm Dependency Issues**: No need to run `helm dependency update`
- **Use Managed Services**: AWS RDS, Azure Database, Google Cloud SQL, etc.
- **Better for Production**: Separate database lifecycle from Keycloak
- **Existing Infrastructure**: Use your existing PostgreSQL server
- **Easier Backups**: Managed by your database provider
- **Better Performance**: Dedicated database resources

## Prerequisites

### 1. PostgreSQL Database

You need a PostgreSQL database (version 12+) with:
- A database named `keycloak` (or your preferred name)
- A user with full permissions on that database
- Network access from your Kubernetes cluster

### 2. Database Setup

Connect to your PostgreSQL server and run:

```sql
-- Create database
CREATE DATABASE keycloak;

-- Create user (replace 'your-password' with a strong password)
CREATE USER keycloak WITH PASSWORD 'your-password';

-- Grant permissions
GRANT ALL PRIVILEGES ON DATABASE keycloak TO keycloak;

-- Connect to keycloak database
\c keycloak

-- Grant schema permissions (PostgreSQL 15+)
GRANT ALL ON SCHEMA public TO keycloak;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO keycloak;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO keycloak;
```

### 3. Network Access

Ensure your Kubernetes cluster can reach the database:
- Database must be accessible on its port (usually 5432)
- Firewall rules must allow traffic from your cluster
- For cloud databases, add your cluster's IP range to the allowlist

## Installation Methods

### Method 1: Interactive Script (Recommended)

Use the provided installation script:

```bash
cd keycloak-helm-chart
./install-external-db.sh
```

The script will prompt you for:
- Namespace and release name
- Database connection details (host, port, database, username, password)
- Keycloak configuration (hostname, admin password, replicas)
- Test database connectivity
- Create secrets and install the chart

### Method 2: Using Values File

Create a custom values file:

```yaml
# my-external-db-values.yaml
keycloak:
  auth:
    adminPassword: "MyAdminPassword123!"

  configuration:
    hostname: keycloak.example.com

    database:
      hostname: "postgres.example.com"  # Your database host
      port: 5432
      database: keycloak
      username: keycloak
      password: "YourDBPassword"  # Or use existingSecret

# Disable bundled PostgreSQL
postgresql:
  enabled: false
```

Install with:
```bash
helm install keycloak . \
  -f values-external-db.yaml \
  -f my-external-db-values.yaml \
  --namespace keycloak \
  --create-namespace
```

### Method 3: Command Line Parameters

Install directly with all parameters:

```bash
helm install keycloak . \
  -f values-external-db.yaml \
  --namespace keycloak \
  --create-namespace \
  --set keycloak.auth.adminPassword="AdminPass123!" \
  --set keycloak.configuration.hostname="keycloak.example.com" \
  --set keycloak.configuration.database.hostname="postgres.example.com" \
  --set keycloak.configuration.database.port=5432 \
  --set keycloak.configuration.database.database="keycloak" \
  --set keycloak.configuration.database.username="keycloak" \
  --set keycloak.configuration.database.password="DBPassword123!"
```

### Method 4: Using Kubernetes Secrets (Production)

For better security, store credentials in secrets:

```bash
# Create namespace
kubectl create namespace keycloak

# Create database secret
kubectl create secret generic keycloak-db-secret \
  --from-literal=password='YourDBPassword' \
  -n keycloak

# Create admin secret
kubectl create secret generic keycloak-admin-secret \
  --from-literal=password='YourAdminPassword' \
  -n keycloak

# Install with existing secrets
helm install keycloak . \
  -f values-external-db.yaml \
  --namespace keycloak \
  --set keycloak.auth.existingSecret="keycloak-admin-secret" \
  --set keycloak.configuration.hostname="keycloak.example.com" \
  --set keycloak.configuration.database.hostname="postgres.example.com" \
  --set keycloak.configuration.database.database="keycloak" \
  --set keycloak.configuration.database.username="keycloak" \
  --set keycloak.configuration.database.existingSecret="keycloak-db-secret"
```

## Cloud Provider Examples

### AWS RDS PostgreSQL

```bash
# Get your RDS endpoint from AWS Console
# Example: mykeycloak.abc123.us-east-1.rds.amazonaws.com

helm install keycloak . \
  -f values-external-db.yaml \
  --namespace keycloak \
  --create-namespace \
  --set keycloak.auth.adminPassword="AdminPass" \
  --set keycloak.configuration.hostname="keycloak.example.com" \
  --set keycloak.configuration.database.hostname="mykeycloak.abc123.us-east-1.rds.amazonaws.com" \
  --set keycloak.configuration.database.port=5432 \
  --set keycloak.configuration.database.database="keycloak" \
  --set keycloak.configuration.database.username="keycloak" \
  --set keycloak.configuration.database.password="DBPassword"
```

**Important**: Ensure your EKS cluster's security group allows outbound traffic to RDS security group on port 5432.

### Azure Database for PostgreSQL

```bash
# Format: server-name.postgres.database.azure.com
helm install keycloak . \
  -f values-external-db.yaml \
  --namespace keycloak \
  --create-namespace \
  --set keycloak.auth.adminPassword="AdminPass" \
  --set keycloak.configuration.hostname="keycloak.example.com" \
  --set keycloak.configuration.database.hostname="myserver.postgres.database.azure.com" \
  --set keycloak.configuration.database.username="keycloak@myserver" \
  --set keycloak.configuration.database.password="DBPassword"
```

**Note**: Azure requires username format: `username@servername`

### Google Cloud SQL

```bash
# Option 1: Using Public IP
helm install keycloak . \
  -f values-external-db.yaml \
  --set keycloak.configuration.database.hostname="35.xxx.xxx.xxx"

# Option 2: Using Cloud SQL Proxy sidecar (recommended)
# Add to values file:
# extraContainers:
#   - name: cloud-sql-proxy
#     image: gcr.io/cloudsql-docker/gce-proxy
#     command: ["/cloud_sql_proxy", "-instances=PROJECT:REGION:INSTANCE=tcp:5432"]
```

### Rancher with External Database

```bash
helm install keycloak . \
  -f values-external-db.yaml \
  -f values-rancher.yaml \
  --namespace keycloak \
  --create-namespace \
  --set keycloak.auth.adminPassword="AdminPass" \
  --set keycloak.configuration.hostname="keycloak.rancher.local" \
  --set keycloak.configuration.database.hostname="postgres.example.com" \
  --set keycloak.configuration.database.password="DBPassword" \
  --set rancher.projectId="c-xxxxx:p-xxxxx"
```

## Testing Database Connectivity

### Before Installation

Test connectivity from a test pod:

```bash
# Create test pod
kubectl run -it --rm debug --image=postgres:14 --restart=Never -- bash

# Inside the pod, test connection
psql -h postgres.example.com -U keycloak -d keycloak -c "\l"
# Enter password when prompted
```

### After Installation

Check Keycloak logs for database connection:

```bash
# View logs
kubectl logs keycloak-0 -n keycloak | grep -i database

# Look for successful connection messages
kubectl logs keycloak-0 -n keycloak | grep -i "database initialized"
```

Test from Keycloak pod:

```bash
# Exec into pod
kubectl exec -it keycloak-0 -n keycloak -- sh

# Test connectivity
nc -zv postgres.example.com 5432

# Or try psql (if available)
apt-get update && apt-get install -y postgresql-client
psql -h postgres.example.com -U keycloak -d keycloak -c "SELECT version();"
```

## Troubleshooting

### Connection Refused

**Problem**: Keycloak can't connect to database

**Solutions**:
1. Check hostname is correct
2. Verify database is running
3. Check firewall rules
4. Ensure Kubernetes cluster has network access
5. Verify credentials are correct

```bash
# Test from within cluster
kubectl run -it --rm debug --image=postgres:14 --restart=Never -n keycloak -- \
  psql -h YOUR_DB_HOST -U keycloak -d keycloak
```

### Authentication Failed

**Problem**: Wrong username or password

**Solutions**:
1. Verify database credentials
2. Check secret values:
   ```bash
   kubectl get secret keycloak-db-secret -n keycloak -o jsonpath='{.data.password}' | base64 -d
   ```
3. For Azure, ensure username format is `user@server`

### SSL/TLS Issues

**Problem**: Database requires SSL but connection fails

**Solution**: Add SSL parameters to database URL in values:

```yaml
keycloak:
  configuration:
    database:
      hostname: "postgres.example.com"
      # Add SSL parameters via extraEnv
  extraEnv:
    - name: KC_DB_URL_PROPERTIES
      value: "?ssl=true&sslmode=require"
```

### Schema Permissions

**Problem**: Keycloak can't create tables

**Solution**: Grant proper permissions:

```sql
\c keycloak
GRANT ALL ON SCHEMA public TO keycloak;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO keycloak;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO keycloak;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO keycloak;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO keycloak;
```

### Network Timeout

**Problem**: Connection times out

**Solutions**:
1. Check network connectivity from cluster to database
2. Verify security groups/firewall rules
3. Increase timeout in probe settings:
   ```yaml
   keycloak:
     startupProbe:
       failureThreshold: 60  # Increase for slow network
   ```

## Migration from Bundled to External Database

If you already deployed with bundled PostgreSQL and want to migrate:

### 1. Backup Existing Data

```bash
# Backup from bundled PostgreSQL
kubectl exec keycloak-postgresql-0 -n keycloak -- \
  pg_dump -U keycloak keycloak > keycloak-backup.sql
```

### 2. Restore to External Database

```bash
# Restore to external database
psql -h postgres.example.com -U keycloak -d keycloak < keycloak-backup.sql
```

### 3. Upgrade Helm Release

```bash
helm upgrade keycloak . \
  -f values-external-db.yaml \
  --set keycloak.configuration.database.hostname="postgres.example.com" \
  --set keycloak.configuration.database.password="DBPassword" \
  --reuse-values \
  -n keycloak
```

### 4. Delete Old PostgreSQL

```bash
# After verifying everything works
kubectl delete statefulset keycloak-postgresql -n keycloak
kubectl delete pvc data-keycloak-postgresql-0 -n keycloak
```

## Security Best Practices

1. **Use Secrets**: Never put passwords in values files
2. **Use SSL/TLS**: Enable encrypted database connections
3. **Least Privilege**: Grant only necessary database permissions
4. **Rotate Credentials**: Regularly change database passwords
5. **Network Policies**: Restrict database access to Keycloak pods only
6. **Private Networks**: Use VPC peering or private endpoints for cloud databases

## Performance Tuning

For external databases, consider:

```yaml
keycloak:
  extraEnv:
    - name: KC_DB_POOL_INITIAL_SIZE
      value: "10"
    - name: KC_DB_POOL_MIN_SIZE
      value: "10"
    - name: KC_DB_POOL_MAX_SIZE
      value: "50"
```

## Next Steps

After successful installation:
1. Verify pods are running: `kubectl get pods -n keycloak`
2. Check logs: `kubectl logs keycloak-0 -n keycloak`
3. Access Keycloak: `https://your-hostname`
4. Configure your realm and clients

For more help, see [TROUBLESHOOTING.md](TROUBLESHOOTING.md)
