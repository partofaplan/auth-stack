# Troubleshooting Guide

## Common Installation Issues

### "Chart.yaml file is missing" Error

This error can occur on macOS due to extended file attributes or Helm's working directory handling.

#### Solution 1: Clean Extended Attributes (macOS)

```bash
cd keycloak-helm-chart
xattr -cr .
helm dependency update
```

#### Solution 2: Use the Simple Install Script

The `install-simple.sh` script bypasses the dependency update issue:

```bash
cd keycloak-helm-chart
./install-simple.sh
```

#### Solution 3: Manual Dependency Installation

Instead of using `helm dependency update`, manually add the PostgreSQL chart:

```bash
# Add Bitnami repo
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update

# Install with inline dependency
helm install keycloak . \
  --namespace keycloak \
  --create-namespace \
  --set keycloak.auth.adminPassword="YourPassword" \
  --set postgresql.enabled=true \
  --set postgresql.auth.password="DBPassword" \
  --set keycloak.configuration.hostname="keycloak.local"
```

#### Solution 4: Use External PostgreSQL

Skip the PostgreSQL subchart entirely by using an external database:

```bash
helm install keycloak . \
  --namespace keycloak \
  --create-namespace \
  --set keycloak.auth.adminPassword="YourPassword" \
  --set postgresql.enabled=false \
  --set keycloak.configuration.database.hostname="your-db-host" \
  --set keycloak.configuration.database.port=5432 \
  --set keycloak.configuration.database.database="keycloak" \
  --set keycloak.configuration.database.username="keycloak" \
  --set keycloak.configuration.database.password="DBPassword" \
  --set keycloak.configuration.hostname="keycloak.local"
```

#### Solution 5: Recreate Chart.yaml

If the file is corrupted, recreate it:

```bash
cd keycloak-helm-chart
cat > Chart.yaml << 'EOF'
apiVersion: v2
name: keycloak
description: A Helm chart for Keycloak identity and access management with Rancher integration
type: application
version: 1.0.0
appVersion: "24.0.1"
keywords:
  - keycloak
  - authentication
  - authorization
  - identity
  - sso
  - rancher
home: https://www.keycloak.org/
sources:
  - https://github.com/keycloak/keycloak
maintainers:
  - name: Auth Stack Team
    email: team@example.com
dependencies:
  - name: postgresql
    version: "12.x.x"
    repository: "https://charts.bitnami.com/bitnami"
    condition: postgresql.enabled
EOF

helm dependency update
```

---

## Other Common Issues

### Pods Not Starting

**Symptoms**: Pods stuck in `Pending`, `CrashLoopBackOff`, or `Error` state

**Diagnosis**:
```bash
kubectl get pods -n keycloak
kubectl describe pod keycloak-0 -n keycloak
kubectl logs keycloak-0 -n keycloak
```

**Common Causes**:

1. **No storage class available**
   ```bash
   # Check available storage classes
   kubectl get storageclass

   # Use a specific storage class
   helm upgrade keycloak . \
     --reuse-values \
     --set persistence.storageClass="your-storage-class" \
     --set postgresql.primary.persistence.storageClass="your-storage-class"
   ```

2. **Insufficient resources**
   ```bash
   # Reduce resource requirements
   helm upgrade keycloak . \
     --reuse-values \
     --set keycloak.resources.requests.memory="256Mi" \
     --set keycloak.resources.requests.cpu="250m"
   ```

3. **Database connection failure**
   ```bash
   # Check PostgreSQL pod
   kubectl get pods -n keycloak | grep postgresql
   kubectl logs keycloak-postgresql-0 -n keycloak
   ```

### Database Connection Issues

**Symptoms**: Keycloak logs show database connection errors

**Solutions**:

1. **Check PostgreSQL is running**
   ```bash
   kubectl get pods -n keycloak | grep postgresql
   kubectl logs keycloak-postgresql-0 -n keycloak
   ```

2. **Verify database credentials**
   ```bash
   # Check secret exists
   kubectl get secret keycloak-postgresql -n keycloak

   # View password (base64 encoded)
   kubectl get secret keycloak-postgresql -n keycloak -o jsonpath='{.data.password}' | base64 -d
   ```

3. **Test connectivity from Keycloak pod**
   ```bash
   kubectl exec -it keycloak-0 -n keycloak -- sh
   nc -zv keycloak-postgresql 5432
   ```

### Ingress Not Working

**Symptoms**: Cannot access Keycloak via the configured hostname

**Solutions**:

1. **Check ingress resource**
   ```bash
   kubectl get ingress -n keycloak
   kubectl describe ingress keycloak -n keycloak
   ```

2. **Verify ingress controller is installed**
   ```bash
   # For NGINX
   kubectl get pods -n ingress-nginx

   # For Traefik
   kubectl get pods -n kube-system | grep traefik
   ```

3. **Check DNS resolution**
   ```bash
   nslookup your-keycloak-hostname
   ```

4. **Use port-forward as workaround**
   ```bash
   kubectl port-forward svc/keycloak 8080:8080 -n keycloak
   # Access at: http://localhost:8080
   ```

### Certificate/TLS Issues

**Symptoms**: HTTPS not working, certificate errors

**Solutions**:

1. **Check cert-manager is installed**
   ```bash
   kubectl get pods -n cert-manager
   ```

2. **Check certificate status**
   ```bash
   kubectl get certificate -n keycloak
   kubectl describe certificate keycloak-tls -n keycloak
   ```

3. **Check certificate request**
   ```bash
   kubectl get certificaterequest -n keycloak
   kubectl describe certificaterequest -n keycloak
   ```

4. **Use existing TLS secret**
   ```bash
   # Create secret manually
   kubectl create secret tls keycloak-tls \
     --cert=path/to/tls.crt \
     --key=path/to/tls.key \
     -n keycloak
   ```

### Keycloak Admin Password Not Working

**Symptoms**: Cannot login with admin password

**Solutions**:

1. **Get the actual password from secret**
   ```bash
   kubectl get secret keycloak-admin-secret -n keycloak \
     -o jsonpath='{.data.password}' | base64 -d
   ```

2. **Reset admin password**
   ```bash
   kubectl delete secret keycloak-admin-secret -n keycloak
   kubectl create secret generic keycloak-admin-secret \
     --from-literal=password='NewPassword123!' \
     -n keycloak
   kubectl rollout restart statefulset/keycloak -n keycloak
   ```

### Clustering Issues

**Symptoms**: Pods not forming a cluster, session not replicated

**Solutions**:

1. **Check headless service**
   ```bash
   kubectl get svc keycloak-headless -n keycloak
   ```

2. **Check JGroups logs**
   ```bash
   kubectl logs keycloak-0 -n keycloak | grep -i jgroups
   ```

3. **Verify pod-to-pod connectivity**
   ```bash
   kubectl exec -it keycloak-0 -n keycloak -- sh
   nc -zv keycloak-1.keycloak-headless 7600
   ```

### High CPU/Memory Usage

**Symptoms**: Pods using too much resources, getting OOMKilled

**Solutions**:

1. **Check resource usage**
   ```bash
   kubectl top pods -n keycloak
   ```

2. **Increase resource limits**
   ```bash
   helm upgrade keycloak . \
     --reuse-values \
     --set keycloak.resources.limits.cpu=3000m \
     --set keycloak.resources.limits.memory=3Gi
   ```

3. **Reduce Java heap size** (if needed)
   ```bash
   helm upgrade keycloak . \
     --reuse-values \
     --set 'keycloak.extraEnv[0].name=JAVA_OPTS_APPEND' \
     --set 'keycloak.extraEnv[0].value=-Xmx1g -Xms512m'
   ```

### Helm Upgrade Fails

**Symptoms**: `helm upgrade` command fails

**Solutions**:

1. **Check what changed**
   ```bash
   helm diff upgrade keycloak . --reuse-values
   ```

2. **Dry run first**
   ```bash
   helm upgrade keycloak . --dry-run --reuse-values
   ```

3. **Force update if needed**
   ```bash
   helm upgrade keycloak . --reuse-values --force
   ```

4. **Rollback if needed**
   ```bash
   helm rollback keycloak -n keycloak
   ```

### Persistent Volume Issues

**Symptoms**: PVCs stuck in `Pending` state

**Solutions**:

1. **Check PVC status**
   ```bash
   kubectl get pvc -n keycloak
   kubectl describe pvc data-keycloak-0 -n keycloak
   ```

2. **Check available PVs**
   ```bash
   kubectl get pv
   ```

3. **Use a different storage class**
   ```bash
   helm upgrade keycloak . \
     --reuse-values \
     --set persistence.storageClass="your-storage-class"
   ```

4. **Disable persistence (not recommended for production)**
   ```bash
   helm upgrade keycloak . \
     --reuse-values \
     --set persistence.enabled=false
   ```

---

## Getting Help

### Collect Diagnostic Information

```bash
# Create a diagnostic bundle
kubectl get all -n keycloak > keycloak-resources.txt
kubectl describe pods -n keycloak > keycloak-pods-describe.txt
kubectl logs -l app.kubernetes.io/name=keycloak -n keycloak --tail=500 > keycloak-logs.txt
helm get values keycloak -n keycloak > keycloak-values.yaml
kubectl get events -n keycloak --sort-by='.lastTimestamp' > keycloak-events.txt
```

### Useful Debug Commands

```bash
# Check all resources
kubectl get all -n keycloak

# Check events
kubectl get events -n keycloak --sort-by='.lastTimestamp'

# Check logs from all pods
kubectl logs -l app.kubernetes.io/name=keycloak -n keycloak --tail=100

# Exec into pod
kubectl exec -it keycloak-0 -n keycloak -- sh

# Check Helm release status
helm status keycloak -n keycloak

# Get deployed values
helm get values keycloak -n keycloak

# Check deployed manifests
helm get manifest keycloak -n keycloak
```

### Support Resources

- **Chart Issues**: Create an issue in this repository
- **Keycloak Documentation**: https://www.keycloak.org/documentation
- **Keycloak Community**: https://www.keycloak.org/community
- **Rancher Forums**: https://forums.rancher.com/
- **Kubernetes Slack**: https://kubernetes.slack.com/
