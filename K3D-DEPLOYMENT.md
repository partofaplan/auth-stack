# k3d Deployment Guide

Complete guide for deploying the Keycloak authentication stack on k3d.

## Quick Deploy

```bash
./deploy.sh
```

Access: http://keycloak.local/admin/ (admin/admin123)

## What Gets Deployed

### PostgreSQL Database
- **Image:** postgres:16.2
- **Namespace:** keycloak
- **Storage:** 8Gi PVC
- **Credentials:** keycloak/keycloak123

### Keycloak
- **Image:** quay.io/keycloak/keycloak:24.0.1
- **Replicas:** 2 (clustered)
- **Namespace:** keycloak
- **Storage:** 1Gi PVC per pod
- **Credentials:** admin/admin123

## Prerequisites

1. **k3d cluster running:**
   ```bash
   k3d cluster create mycluster
   ```

2. **Add to /etc/hosts:**
   ```bash
   echo "127.0.0.1 keycloak.local" | sudo tee -a /etc/hosts
   ```

## Manual Deployment

If you prefer to deploy step-by-step:

### 1. Create Namespace
```bash
kubectl create namespace keycloak
```

### 2. Deploy PostgreSQL
```bash
# Secret
kubectl apply -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: postgresql-secret
  namespace: keycloak
type: Opaque
stringData:
  username: "keycloak"
  password: "keycloak123"
  database: "keycloak"
  postgres-password: "postgres123"
EOF

# PVC
kubectl apply -f - <<EOF
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: postgresql-data
  namespace: keycloak
spec:
  accessModes: [ReadWriteOnce]
  resources:
    requests:
      storage: 8Gi
EOF

# StatefulSet
kubectl apply -f postgresql-helm-chart/values-k3d.yaml
# (Use the manifest from deploy.sh)

# Wait for ready
kubectl wait --for=condition=ready pod -l app=postgresql -n keycloak --timeout=120s

# Fix authentication
kubectl exec postgresql-0 -n keycloak -- \
  psql -U keycloak -d keycloak -c "ALTER USER keycloak WITH PASSWORD 'keycloak123';"
```

### 3. Deploy Keycloak
```bash
# Apply all Keycloak manifests from deploy.sh
# See deploy.sh for complete configuration

# Wait for ready
kubectl wait --for=condition=ready pod -l app=keycloak -n keycloak --timeout=300s
```

## Verify Deployment

```bash
# Check all resources
kubectl get all,pvc,ingress -n keycloak

# Check health
kubectl run test --image=curlimages/curl --rm -i --restart=Never -n keycloak -- \
  curl -s http://keycloak:8080/health

# View logs
kubectl logs -f keycloak-0 -n keycloak
```

## Access Methods

### Browser (via Ingress)
- URL: http://keycloak.local/admin/
- Username: admin
- Password: admin123

### Port Forward
```bash
kubectl port-forward svc/keycloak 8080:8080 -n keycloak
# Access: http://localhost:8080
```

### From Within Cluster
```bash
# Service endpoint
http://keycloak.keycloak.svc.cluster.local:8080
```

## Configuration Files

All configuration is in YAML files under the chart directories:

- [postgresql-helm-chart/values-k3d.yaml](postgresql-helm-chart/values-k3d.yaml)
- [keycloak-helm-chart/values-k3d.yaml](keycloak-helm-chart/values-k3d.yaml)

**Note:** These files are for reference. The actual deployment uses kubectl with manifests in `deploy.sh`.

## Common Tasks

### View Logs
```bash
kubectl logs -f keycloak-0 -n keycloak
kubectl logs -f postgresql-0 -n keycloak
```

### Scale Keycloak
```bash
kubectl scale statefulset keycloak -n keycloak --replicas=3
```

### Restart Pods
```bash
kubectl delete pod keycloak-0 keycloak-1 -n keycloak
```

### Backup Database
```bash
kubectl exec postgresql-0 -n keycloak -- \
  pg_dump -U keycloak keycloak > backup-$(date +%Y%m%d).sql
```

### Restore Database
```bash
cat backup.sql | kubectl exec -i postgresql-0 -n keycloak -- \
  psql -U keycloak -d keycloak
```

### Access Database
```bash
kubectl exec -it postgresql-0 -n keycloak -- \
  psql -U keycloak -d keycloak
```

## Troubleshooting

### Pods Not Starting
```bash
kubectl describe pod <pod-name> -n keycloak
kubectl logs <pod-name> -n keycloak
```

### Database Connection Failed
```bash
# Test connection
kubectl run test-pg --image=postgres:16 --rm -i --restart=Never -n keycloak -- \
  env PGPASSWORD=keycloak123 psql -h postgresql -U keycloak -d keycloak -c "SELECT 1;"
```

### Ingress Not Working
```bash
# Check ingress
kubectl describe ingress keycloak -n keycloak

# Check traefik
kubectl get pods -n kube-system | grep traefik

# Test service directly
kubectl port-forward svc/keycloak 8080:8080 -n keycloak
```

### Clustering Issues
```bash
# Check cluster formation
kubectl logs keycloak-0 -n keycloak | grep -i "cluster\|jgroups"

# Check headless service
kubectl get svc keycloak-headless -n keycloak

# Test DNS
kubectl run test-dns --image=busybox --rm -i --restart=Never -n keycloak -- \
  nslookup keycloak-headless.keycloak.svc.cluster.local
```

### Password Authentication Failed
This was fixed in the deploy.sh script. If you encounter this:
```bash
kubectl exec postgresql-0 -n keycloak -- \
  psql -U keycloak -d keycloak -c "ALTER USER keycloak WITH PASSWORD 'keycloak123';"
```

## Uninstall

### Remove Everything
```bash
kubectl delete namespace keycloak
```

### Remove Specific Components
```bash
# Remove Keycloak only
kubectl delete statefulset,svc,ingress,pdb,role,rolebinding,sa,secret -l app=keycloak -n keycloak
kubectl delete pvc -l app=keycloak -n keycloak

# Remove PostgreSQL only
kubectl delete statefulset,svc,secret -l app=postgresql -n keycloak
kubectl delete pvc postgresql-data -n keycloak
```

## Architecture

```
Browser → Traefik Ingress (keycloak.local)
    ↓
Keycloak Service (ClusterIP + Headless)
    ↓
Keycloak Pods (keycloak-0, keycloak-1)
    ↓ JGroups Clustering
    ↓
PostgreSQL Pod (postgresql-0)
    ↓
Persistent Volume (8Gi)
```

## Resources Created

### PostgreSQL
- Secret: postgresql-secret
- PVC: postgresql-data (8Gi)
- StatefulSet: postgresql (1 replica)
- Service: postgresql (ClusterIP)

### Keycloak
- Secret: keycloak-secret
- ServiceAccount: keycloak
- Role: keycloak (pod list permissions)
- RoleBinding: keycloak
- StatefulSet: keycloak (2 replicas)
- PVC: keycloak-data-keycloak-{0,1} (1Gi each)
- Service: keycloak (ClusterIP)
- Service: keycloak-headless (for clustering)
- Ingress: keycloak (traefik)
- PodDisruptionBudget: keycloak

## Security Notes

⚠️ **Development Configuration Only**

For production:
- Use strong, randomly generated passwords
- Enable TLS (HTTPS) with cert-manager
- Use external secret management (Sealed Secrets, Vault)
- Configure NetworkPolicies
- Use managed PostgreSQL (RDS, Cloud SQL)
- Enable audit logging
- Regular backups
- Security scanning

## Next Steps

After deployment:
1. Login to admin console
2. Create a new realm
3. Add users
4. Configure clients (OIDC/SAML)
5. Set up identity providers
6. Enable MFA
7. Customize themes

## Resources

- [Keycloak Documentation](https://www.keycloak.org/documentation)
- [PostgreSQL Documentation](https://www.postgresql.org/docs/)
- [k3d Documentation](https://k3d.io/)
