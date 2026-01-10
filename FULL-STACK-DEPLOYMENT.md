# Complete Auth Stack Deployment Guide

Deploy PostgreSQL and Keycloak together on Kubernetes.

## Overview

This guide shows you how to deploy a complete authentication stack:
1. PostgreSQL database (standalone)
2. Keycloak connected to PostgreSQL

## Quick Deployment (5 Minutes)

### Method 1: Interactive Scripts (Easiest) ⭐

```bash
# Step 1: Deploy PostgreSQL (direct install, no Helm issues)
cd postgresql-helm-chart
./install-direct.sh

# Step 2: Deploy Keycloak
cd ../keycloak-helm-chart
./install-external-db.sh
# Enter the PostgreSQL connection details from Step 1
```

### Method 2: Manual Commands

```bash
# Step 1: Install PostgreSQL
cd postgresql-helm-chart
helm install postgres . \
  --namespace postgres \
  --create-namespace \
  --set postgresql.auth.password="DBPassword123" \
  --set postgresql.auth.postgresPassword="SuperPassword123"

# Wait for PostgreSQL
kubectl wait --for=condition=ready pod postgres-postgresql-0 -n postgres --timeout=120s

# Step 2: Install Keycloak
cd ../keycloak-helm-chart
helm install keycloak . \
  -f values-external-db.yaml \
  --namespace keycloak \
  --create-namespace \
  --set keycloak.auth.adminPassword="AdminPassword123" \
  --set keycloak.configuration.hostname="keycloak.example.com" \
  --set keycloak.configuration.database.hostname="postgres-postgresql.postgres.svc.cluster.local" \
  --set keycloak.configuration.database.password="DBPassword123"
```

## Detailed Step-by-Step

### Step 1: Deploy PostgreSQL Database

#### 1.1 Install PostgreSQL

```bash
cd postgresql-helm-chart

# Interactive installation
./install.sh

# OR manual installation
helm install postgres . \
  --namespace postgres \
  --create-namespace \
  --set postgresql.auth.database="keycloak" \
  --set postgresql.auth.username="keycloak" \
  --set postgresql.auth.password="YourDBPassword" \
  --set postgresql.auth.postgresPassword="YourSuperPassword" \
  --set persistence.size="8Gi"
```

#### 1.2 Verify PostgreSQL

```bash
# Check pod status
kubectl get pods -n postgres

# Should show:
# NAME                    READY   STATUS    RESTARTS   AGE
# postgres-postgresql-0   1/1     Running   0          1m

# Test connection
kubectl exec -it postgres-postgresql-0 -n postgres -- \
  psql -U keycloak -d keycloak -c "SELECT version();"
```

#### 1.3 Note Connection Details

After installation, save these details:
- **Host**: `postgres-postgresql.postgres.svc.cluster.local`
- **Port**: `5432`
- **Database**: `keycloak`
- **Username**: `keycloak`
- **Password**: `<what you set>`

### Step 2: Deploy Keycloak

#### 2.1 Install Keycloak

```bash
cd ../keycloak-helm-chart

# Interactive installation (recommended)
./install-external-db.sh
# Enter PostgreSQL details when prompted

# OR manual installation
helm install keycloak . \
  -f values-external-db.yaml \
  --namespace keycloak \
  --create-namespace \
  --set keycloak.auth.adminPassword="AdminPassword" \
  --set keycloak.configuration.hostname="keycloak.example.com" \
  --set keycloak.configuration.database.hostname="postgres-postgresql.postgres.svc.cluster.local" \
  --set keycloak.configuration.database.port=5432 \
  --set keycloak.configuration.database.database="keycloak" \
  --set keycloak.configuration.database.username="keycloak" \
  --set keycloak.configuration.database.password="YourDBPassword"
```

#### 2.2 Verify Keycloak

```bash
# Check pods
kubectl get pods -n keycloak

# Should show 2 replicas running:
# NAME          READY   STATUS    RESTARTS   AGE
# keycloak-0    1/1     Running   0          2m
# keycloak-1    1/1     Running   0          1m

# Check logs for database connection
kubectl logs keycloak-0 -n keycloak | grep -i "database"
```

### Step 3: Access Keycloak

#### 3.1 Port-Forward (Local Access)

```bash
kubectl port-forward svc/keycloak 8080:8080 -n keycloak
```

Open browser: http://localhost:8080

#### 3.2 Via Ingress (Production)

Ensure DNS points to your ingress:
- URL: https://keycloak.example.com (or your configured hostname)

#### 3.3 Login

- Username: `admin`
- Password: `<your admin password>`

## Configuration Options

### PostgreSQL Configuration

```yaml
# postgresql-values.yaml
postgresql:
  auth:
    database: keycloak
    username: keycloak
    password: "SecurePassword"
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
  storageClass: "fast-ssd"  # or "longhorn" for Rancher
```

### Keycloak Configuration

```yaml
# keycloak-values.yaml
keycloak:
  replicas: 3

  auth:
    adminPassword: "AdminPassword"

  configuration:
    hostname: keycloak.production.com

    database:
      hostname: postgres-postgresql.postgres.svc.cluster.local
      port: 5432
      database: keycloak
      username: keycloak
      password: "DBPassword"

  resources:
    requests:
      cpu: 1000m
      memory: 1Gi
    limits:
      cpu: 2000m
      memory: 2Gi
```

Install with custom values:
```bash
helm install postgres ./postgresql-helm-chart -f postgresql-values.yaml -n postgres --create-namespace
helm install keycloak ./keycloak-helm-chart -f values-external-db.yaml -f keycloak-values.yaml -n keycloak --create-namespace
```

## Rancher Deployment

### With Longhorn Storage

```bash
# PostgreSQL with Longhorn
helm install postgres ./postgresql-helm-chart \
  --namespace postgres \
  --create-namespace \
  --set postgresql.auth.password="DBPassword" \
  --set postgresql.auth.postgresPassword="SuperPassword" \
  --set persistence.storageClass="longhorn"

# Keycloak with Rancher settings
helm install keycloak ./keycloak-helm-chart \
  -f values-external-db.yaml \
  -f values-rancher.yaml \
  --namespace keycloak \
  --create-namespace \
  --set keycloak.auth.adminPassword="AdminPassword" \
  --set keycloak.configuration.hostname="keycloak.rancher.local" \
  --set keycloak.configuration.database.hostname="postgres-postgresql.postgres.svc.cluster.local" \
  --set keycloak.configuration.database.password="DBPassword" \
  --set rancher.projectId="c-xxxxx:p-xxxxx" \
  --set persistence.storageClass="longhorn"
```

## Monitoring

### Check All Resources

```bash
# PostgreSQL
kubectl get all -n postgres

# Keycloak
kubectl get all -n keycloak
```

### View Logs

```bash
# PostgreSQL logs
kubectl logs -f postgres-postgresql-0 -n postgres

# Keycloak logs
kubectl logs -f keycloak-0 -n keycloak
```

### Test Database Connection from Keycloak

```bash
# Exec into Keycloak pod
kubectl exec -it keycloak-0 -n keycloak -- sh

# Test database connectivity
nc -zv postgres-postgresql.postgres.svc.cluster.local 5432
```

## Backup and Restore

### Backup PostgreSQL

```bash
# Backup database
kubectl exec postgres-postgresql-0 -n postgres -- \
  pg_dump -U keycloak keycloak > keycloak-backup-$(date +%Y%m%d).sql

# Verify backup
ls -lh keycloak-backup-*.sql
```

### Restore PostgreSQL

```bash
# Restore database
cat keycloak-backup-20240115.sql | \
  kubectl exec -i postgres-postgresql-0 -n postgres -- \
  psql -U keycloak -d keycloak

# Restart Keycloak pods to reconnect
kubectl rollout restart statefulset/keycloak -n keycloak
```

## Scaling

### Scale Keycloak

```bash
# Scale to 3 replicas
helm upgrade keycloak ./keycloak-helm-chart \
  --reuse-values \
  --set keycloak.replicas=3 \
  -n keycloak
```

### PostgreSQL (Not Recommended)

The minimal PostgreSQL chart is single-instance. For HA, use:
- Managed database service (AWS RDS, Azure Database, Google Cloud SQL)
- Bitnami PostgreSQL chart with replication
- PostgreSQL operator

## Troubleshooting

### PostgreSQL Not Starting

```bash
# Check pod
kubectl describe pod postgres-postgresql-0 -n postgres

# Check PVC
kubectl get pvc -n postgres

# Check logs
kubectl logs postgres-postgresql-0 -n postgres
```

### Keycloak Can't Connect to Database

```bash
# Test connectivity from Keycloak
kubectl exec -it keycloak-0 -n keycloak -- nc -zv postgres-postgresql.postgres.svc.cluster.local 5432

# Check database is running
kubectl get pods -n postgres

# Verify credentials match
kubectl get secret postgres-postgresql -n postgres -o jsonpath='{.data.password}' | base64 -d
```

### Performance Issues

```bash
# Increase PostgreSQL resources
helm upgrade postgres ./postgresql-helm-chart \
  --reuse-values \
  --set postgresql.resources.limits.memory=2Gi \
  --set postgresql.resources.limits.cpu=2000m \
  -n postgres

# Increase Keycloak resources
helm upgrade keycloak ./keycloak-helm-chart \
  --reuse-values \
  --set keycloak.resources.limits.memory=3Gi \
  -n keycloak
```

## Uninstalling

### Uninstall Both Stacks

```bash
# Uninstall Keycloak
helm uninstall keycloak -n keycloak
kubectl delete namespace keycloak

# Uninstall PostgreSQL
helm uninstall postgres -n postgres
kubectl delete pvc data-postgres-postgresql-0 -n postgres  # Delete data
kubectl delete namespace postgres
```

### Keep Data

```bash
# Uninstall but keep PVCs
helm uninstall keycloak -n keycloak
helm uninstall postgres -n postgres

# PVCs remain and can be reused on next install
```

## Production Checklist

- [ ] Strong, unique passwords set for all accounts
- [ ] TLS/SSL enabled for Keycloak ingress
- [ ] Resource limits configured appropriately
- [ ] Persistent storage configured with appropriate size
- [ ] Backups configured and tested
- [ ] Monitoring enabled (Rancher/Prometheus)
- [ ] High availability tested (3+ Keycloak replicas)
- [ ] Database backup strategy in place
- [ ] Disaster recovery plan documented
- [ ] Security scan completed

## Next Steps

1. **Configure Keycloak**
   - Create realms
   - Add clients
   - Configure authentication flows
   - Set up user federation (LDAP/AD)

2. **Integrate Applications**
   - Use OpenID Connect
   - Configure client credentials
   - Test authentication flow

3. **Set Up Backups**
   - Automate PostgreSQL backups
   - Test restore procedures
   - Store backups off-cluster

4. **Enable Monitoring**
   - Configure Prometheus
   - Set up alerts
   - Create dashboards

## Support

- **PostgreSQL Chart**: [postgresql-helm-chart/README.md](postgresql-helm-chart/README.md)
- **Keycloak Chart**: [keycloak-helm-chart/README.md](keycloak-helm-chart/README.md)
- **Troubleshooting**: [keycloak-helm-chart/TROUBLESHOOTING.md](keycloak-helm-chart/TROUBLESHOOTING.md)
