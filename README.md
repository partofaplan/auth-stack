# Keycloak Authentication Stack for Kubernetes

A production-ready Keycloak identity and access management deployment for Kubernetes (k3d local cluster).

## What's Deployed

- **PostgreSQL 16** - Persistent database for Keycloak
- **Keycloak 24.0.1** - Identity and Access Management (2 replicas, clustered)
- **Traefik Ingress** - HTTP access via `keycloak.local`

## Quick Start

### Prerequisites

- k3d cluster running
- kubectl configured
- Traefik ingress controller installed
- `/etc/hosts` entry: `127.0.0.1 keycloak.local`

### Deploy Everything

```bash
./deploy.sh
```

This script deploys PostgreSQL and Keycloak with hardcoded development credentials.

### Access Keycloak

**Admin Console:** http://keycloak.local/admin/

**Credentials:**
- Username: `admin`
- Password: `admin123`

## Configuration

All configuration is in `values-k3d.yaml` files:

- [postgresql-helm-chart/values-k3d.yaml](postgresql-helm-chart/values-k3d.yaml) - Database settings
- [keycloak-helm-chart/values-k3d.yaml](keycloak-helm-chart/values-k3d.yaml) - Keycloak settings

**Database Credentials:**
- Database: `keycloak`
- Username: `keycloak`
- Password: `keycloak123`

## Management

### View Resources

```bash
kubectl get all,pvc,ingress -n keycloak
```

### View Logs

```bash
# Keycloak
kubectl logs -f keycloak-0 -n keycloak

# PostgreSQL
kubectl logs -f postgresql-0 -n keycloak
```

### Scale Keycloak

```bash
kubectl scale statefulset keycloak -n keycloak --replicas=3
```

### Backup Database

```bash
kubectl exec postgresql-0 -n keycloak -- \
  pg_dump -U keycloak keycloak > backup-$(date +%Y%m%d).sql
```

### Uninstall

```bash
kubectl delete namespace keycloak
```

## Architecture

```
┌─────────────────┐
│   Browser       │
│ keycloak.local  │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│ Traefik Ingress │
└────────┬────────┘
         │
         ▼
┌─────────────────────────────┐
│   Keycloak Service          │
│   (ClusterIP + Headless)    │
└──────┬──────────────┬───────┘
       │              │
       ▼              ▼
┌────────────┐  ┌────────────┐
│ keycloak-0 │  │ keycloak-1 │
│  (Pod)     │◄─┤  (Pod)     │
└─────┬──────┘  └──────┬─────┘
      │                │
      │   JGroups      │
      │   Clustering   │
      └────────┬───────┘
               │
               ▼
        ┌────────────┐
        │ PostgreSQL │
        │ postgresql │
        │   (Pod)    │
        └────────────┘
```

## Features

✅ **High Availability** - 2 Keycloak replicas with clustering
✅ **Persistent Storage** - PostgreSQL data survives pod restarts
✅ **Health Checks** - Liveness, readiness, and startup probes
✅ **Resource Limits** - CPU and memory constraints
✅ **Security** - Non-root containers, dropped capabilities
✅ **Pod Disruption Budget** - Maintains availability during updates

## Troubleshooting

### Pods Not Starting

```bash
kubectl describe pod <pod-name> -n keycloak
kubectl logs <pod-name> -n keycloak
```

### Database Connection Issues

```bash
# Test connection
kubectl run test-pg --image=postgres:16 --rm -i --restart=Never -n keycloak -- \
  env PGPASSWORD=keycloak123 psql \
  -h postgresql.keycloak.svc.cluster.local \
  -U keycloak -d keycloak -c "SELECT version();"
```

### Ingress Not Working

```bash
# Check ingress
kubectl describe ingress keycloak -n keycloak

# Port-forward directly
kubectl port-forward svc/keycloak 8080:8080 -n keycloak
# Then visit http://localhost:8080
```

### Clustering Issues

```bash
# Check cluster formation
kubectl logs keycloak-0 -n keycloak | grep -i "cluster\|jgroups"
```

## Security Notes

⚠️ **This is a development configuration**

For production:
- Use strong, random passwords
- Enable TLS/HTTPS
- Use external secret management (Vault, Sealed Secrets)
- Configure network policies
- Enable audit logging
- Regular security updates
- Use managed PostgreSQL (RDS, Cloud SQL, Azure Database)

## Documentation

- [K3D-DEPLOYMENT.md](K3D-DEPLOYMENT.md) - Detailed deployment information
- [Keycloak Documentation](https://www.keycloak.org/documentation)
- [PostgreSQL Documentation](https://www.postgresql.org/docs/)

## License

This deployment configuration is provided as-is for development and testing purposes.
