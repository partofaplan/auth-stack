# Keycloak Helm Chart - Quick Start Guide

## TL;DR - Get Started in 5 Minutes

### 1. Prerequisites Check
```bash
kubectl version --short  # Ensure you're connected to a cluster
helm version --short     # Ensure Helm 3+ is installed
```

### 2. Clone/Navigate to Chart
```bash
cd keycloak-helm-chart
```

### 3. Choose Your Deployment Method

#### Option A: External Database (Recommended - No Helm Dependency Issues) ⭐

Use this if you have an existing PostgreSQL database or want to avoid Helm dependency issues.

```bash
./install-external-db.sh
```

**Advantages**:
- ✅ No Helm dependency update needed
- ✅ No "Chart.yaml file is missing" errors
- ✅ Works with AWS RDS, Azure Database, Google Cloud SQL, etc.
- ✅ Better for production (managed databases)

**Requirements**: PostgreSQL database with `keycloak` database created.
See [EXTERNAL-DATABASE-SETUP.md](keycloak-helm-chart/EXTERNAL-DATABASE-SETUP.md) for setup instructions.

#### Option B: Bundled Database (Quick Testing)

**B1: Simple Install (if you encounter errors)**
```bash
./install-simple.sh
```

**B2: Full Install (with Helm dependencies)**
```bash
# Add PostgreSQL repository first
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update

# Run installer
./install.sh
```

**B3: One-liner**
```bash
helm install keycloak . \
  --namespace keycloak \
  --create-namespace \
  --set keycloak.auth.adminPassword="ChangeMe123!" \
  --set postgresql.auth.password="ChangeMe123!" \
  --set keycloak.configuration.hostname="keycloak.local"
```

**Troubleshooting**: If you encounter "Chart.yaml file is missing" error, use Option A (External Database) or `install-simple.sh`.

### 5. Access Keycloak

**Get the admin password:**
```bash
kubectl get secret keycloak-admin-secret -n keycloak \
  -o jsonpath='{.data.password}' | base64 -d && echo
```

**Port-forward for local access:**
```bash
kubectl port-forward svc/keycloak 8080:8080 -n keycloak
```

**Open browser:**
```
http://localhost:8080
```

Login with:
- Username: `admin`
- Password: (from step above)

---

## Deployment Scenarios

### Development/Testing
```bash
helm install keycloak ./keycloak-helm-chart \
  --namespace keycloak-dev \
  --create-namespace \
  --set keycloak.auth.adminPassword="admin" \
  --set postgresql.auth.password="postgres"
```

### Production
```bash
helm install keycloak ./keycloak-helm-chart \
  -f keycloak-helm-chart/values-production.yaml \
  --namespace keycloak-prod \
  --create-namespace \
  --set keycloak.auth.adminPassword="<strong-password>" \
  --set postgresql.auth.password="<strong-db-password>" \
  --set keycloak.configuration.hostname="keycloak.yourdomain.com"
```

### Rancher Environment
```bash
helm install keycloak ./keycloak-helm-chart \
  -f keycloak-helm-chart/values-rancher.yaml \
  --namespace keycloak \
  --create-namespace \
  --set keycloak.auth.adminPassword="<password>" \
  --set postgresql.auth.password="<db-password>" \
  --set keycloak.configuration.hostname="keycloak.rancher.local" \
  --set rancher.projectId="c-xxxxx:p-xxxxx"
```

---

## Common Commands

### Check Status
```bash
# View all resources
kubectl get all -n keycloak

# Check pod status
kubectl get pods -n keycloak -w

# View pod logs
kubectl logs -f keycloak-0 -n keycloak
```

### Access Keycloak

**Via Port-Forward (local testing):**
```bash
kubectl port-forward svc/keycloak 8080:8080 -n keycloak
# Access at: http://localhost:8080
```

**Via Ingress (production):**
```bash
# Check ingress
kubectl get ingress -n keycloak

# Access at your configured hostname
# https://keycloak.yourdomain.com
```

### Scale Replicas
```bash
helm upgrade keycloak ./keycloak-helm-chart \
  --reuse-values \
  --set keycloak.replicas=3 \
  -n keycloak
```

### Backup Database
```bash
kubectl exec keycloak-postgresql-0 -n keycloak -- \
  pg_dump -U keycloak keycloak > keycloak-backup-$(date +%Y%m%d).sql
```

### Uninstall
```bash
helm uninstall keycloak -n keycloak
kubectl delete namespace keycloak  # Also deletes PVCs
```

---

## Troubleshooting

### Pods Not Starting
```bash
kubectl describe pod keycloak-0 -n keycloak
kubectl logs keycloak-0 -n keycloak
```

### Database Connection Issues
```bash
kubectl exec -it keycloak-0 -n keycloak -- sh
nc -zv keycloak-postgresql 5432
```

### Reset Admin Password
```bash
kubectl delete secret keycloak-admin-secret -n keycloak
kubectl create secret generic keycloak-admin-secret \
  --from-literal=password='NewPassword123!' \
  -n keycloak
kubectl rollout restart statefulset/keycloak -n keycloak
```

---

## Key Configuration Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `keycloak.replicas` | `2` | Number of replicas |
| `keycloak.auth.adminPassword` | - | Admin password (required) |
| `keycloak.configuration.hostname` | `keycloak.example.com` | Public hostname |
| `postgresql.auth.password` | - | Database password (required) |
| `ingress.enabled` | `true` | Enable ingress |
| `ingress.className` | `nginx` | Ingress class (nginx/traefik) |
| `persistence.storageClass` | `""` | Storage class (empty = default) |

---

## Next Steps After Deployment

1. **Access Admin Console**
   - URL: https://your-hostname or http://localhost:8080
   - Login with admin credentials

2. **Create a Realm**
   - Click "Add realm"
   - Name it (e.g., "myapp")
   - Click "Create"

3. **Add a Client**
   - Go to "Clients" → "Create"
   - Client ID: your-app-name
   - Root URL: https://your-app.com
   - Save

4. **Add Users**
   - Go to "Users" → "Add user"
   - Set username and email
   - Save
   - Go to "Credentials" tab to set password

5. **Configure Your App**
   - Use OpenID Connect or SAML
   - Client ID: (from step 3)
   - Discovery URL: https://keycloak.yourdomain.com/realms/myapp/.well-known/openid-configuration

---

## File Reference

- **[README.md](README.md)** - Full documentation
- **[DEPLOYMENT-GUIDE.md](DEPLOYMENT-GUIDE.md)** - Detailed deployment guide
- **[CHART-SUMMARY.md](CHART-SUMMARY.md)** - Feature summary
- **[keycloak-helm-chart/README.md](keycloak-helm-chart/README.md)** - Chart docs

---

## Support & Resources

- Keycloak Docs: https://www.keycloak.org/documentation
- Chart Issues: Create issue in this repository
- Rancher Docs: https://rancher.com/docs/

---

**Happy deploying! 🚀**
