# Installation Options

This chart provides multiple installation methods to handle different scenarios.

## Method 1: Simple Install (Recommended if you encounter errors)

The `install-simple.sh` script bypasses potential Helm dependency issues by directly adding the PostgreSQL repository.

```bash
cd keycloak-helm-chart
./install-simple.sh
```

**Advantages**:
- Avoids "Chart.yaml file is missing" errors
- Simpler, more reliable
- Interactive prompts
- Works on all platforms

**Use when**:
- You get Helm errors with the full install script
- You want a quick, no-fuss installation
- First time installing

## Method 2: Full Install with Dependencies

The `install.sh` script uses Helm's dependency management system.

```bash
cd keycloak-helm-chart
./install.sh
```

**Advantages**:
- Uses proper Helm dependency management
- Downloads dependencies locally
- Better for offline deployments (after initial download)

**Use when**:
- You have a working Helm setup
- You want to follow Helm best practices
- You need offline capability

**Troubleshooting**: If you see "Chart.yaml file is missing":
```bash
# Clean macOS extended attributes
xattr -cr .

# Try again
./install.sh
```

## Method 3: Manual Helm Install

Install directly with Helm commands.

```bash
# Add PostgreSQL repo
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update

# Install
helm install keycloak . \
  --namespace keycloak \
  --create-namespace \
  --set keycloak.auth.adminPassword="YourPassword" \
  --set postgresql.auth.password="DBPassword" \
  --set keycloak.configuration.hostname="keycloak.yourdomain.com"
```

**Advantages**:
- Full control over all parameters
- Can use values files
- Scriptable

**Use when**:
- You want full control
- You're automating deployment
- You're experienced with Helm

## Method 4: With Values Files

Use pre-configured values files for specific environments.

### Development
```bash
helm install keycloak . \
  -f values.yaml \
  --set keycloak.auth.adminPassword="admin" \
  --set postgresql.auth.password="postgres" \
  --namespace keycloak-dev \
  --create-namespace
```

### Production
```bash
helm install keycloak . \
  -f values-production.yaml \
  --set keycloak.auth.adminPassword="<secure-password>" \
  --set postgresql.auth.password="<secure-db-password>" \
  --set keycloak.configuration.hostname="keycloak.production.com" \
  --namespace keycloak-prod \
  --create-namespace
```

### Rancher
```bash
helm install keycloak . \
  -f values-rancher.yaml \
  --set keycloak.auth.adminPassword="<password>" \
  --set postgresql.auth.password="<db-password>" \
  --set keycloak.configuration.hostname="keycloak.rancher.local" \
  --set rancher.projectId="c-xxxxx:p-xxxxx" \
  --namespace keycloak \
  --create-namespace
```

## Method 5: Using External Database

Skip the PostgreSQL subchart entirely by using an external database.

```bash
helm install keycloak . \
  --namespace keycloak \
  --create-namespace \
  --set keycloak.auth.adminPassword="YourPassword" \
  --set postgresql.enabled=false \
  --set keycloak.configuration.database.hostname="your-db-host.example.com" \
  --set keycloak.configuration.database.port=5432 \
  --set keycloak.configuration.database.database="keycloak" \
  --set keycloak.configuration.database.username="keycloak" \
  --set keycloak.configuration.database.password="DBPassword" \
  --set keycloak.configuration.hostname="keycloak.yourdomain.com"
```

**Advantages**:
- No dependency issues
- Use managed database service (AWS RDS, Azure Database, etc.)
- Better for production

**Use when**:
- You have an existing PostgreSQL database
- You want to use a managed database service
- You're avoiding dependency issues

## Method 6: Rancher App Catalog

Deploy through Rancher's UI using the catalog integration.

1. Navigate to your cluster in Rancher
2. Go to **Apps & Marketplace** → **Charts**
3. Add this repository as a custom catalog (if not already added)
4. Search for "Keycloak"
5. Click **Install**
6. Fill in the form (powered by `rancher-questions.yaml`)
7. Click **Install**

**Advantages**:
- No command line needed
- Form-based configuration
- Integrated with Rancher
- Easy for non-technical users

## Comparison

| Method | Difficulty | Best For | Handles Dependencies |
|--------|-----------|----------|---------------------|
| Simple Install | Easy | First-time users, quick deploys | Automatically |
| Full Install | Easy | Helm best practices | Via Helm |
| Manual Helm | Medium | Automation, experienced users | Manually |
| Values Files | Medium | Environment-specific deploys | Manually |
| External DB | Medium | Production, managed services | N/A |
| Rancher Catalog | Easy | Rancher users, GUI preference | Automatically |

## Troubleshooting Installation

### "Chart.yaml file is missing"

This is typically a macOS-specific issue with extended file attributes.

**Quick Fix**:
```bash
cd keycloak-helm-chart
./install-simple.sh  # Use the simple installer instead
```

**Alternative Fix**:
```bash
# Clean extended attributes (macOS)
xattr -cr .

# Or recreate Chart.yaml
cat > Chart.yaml << 'EOF'
apiVersion: v2
name: keycloak
description: A Helm chart for Keycloak identity and access management with Rancher integration
type: application
version: 1.0.0
appVersion: "24.0.1"
dependencies:
  - name: postgresql
    version: "12.x.x"
    repository: "https://charts.bitnami.com/bitnami"
    condition: postgresql.enabled
EOF

# Try again
helm dependency update
```

### Dependency Update Fails

**Solution**: Add the repository manually and skip dependency update:

```bash
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update
helm install keycloak . <your-parameters>
```

### PostgreSQL Won't Start

**Solution 1**: Check storage class availability
```bash
kubectl get storageclass
helm install keycloak . \
  --set postgresql.primary.persistence.storageClass="your-storage-class"
```

**Solution 2**: Use external database (see Method 5)

## After Installation

Regardless of installation method, verify the deployment:

```bash
# Check pods
kubectl get pods -n keycloak

# Check services
kubectl get svc -n keycloak

# Check ingress
kubectl get ingress -n keycloak

# View logs
kubectl logs -f statefulset/keycloak -n keycloak
```

Access Keycloak:
```bash
# Port-forward for local testing
kubectl port-forward svc/keycloak 8080:8080 -n keycloak

# Or access via your configured hostname
# https://keycloak.yourdomain.com
```

## Need Help?

See the [TROUBLESHOOTING.md](TROUBLESHOOTING.md) guide for more detailed solutions to common issues.
