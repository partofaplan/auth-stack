# Keycloak Helm Chart for Kubernetes with Rancher Integration

This Helm chart deploys Keycloak, an open-source identity and access management solution, on Kubernetes with built-in Rancher integration support.

## Features

- **High Availability**: StatefulSet deployment with configurable replicas
- **Clustering**: Built-in support for Keycloak clustering using JGroups/Infinispan
- **Database**: Integrated PostgreSQL database (via Bitnami chart) or external database support
- **Ingress**: Pre-configured ingress with TLS support
- **Rancher Integration**: Ready for Rancher monitoring, project management, and UI integration
- **Security**: RBAC, ServiceAccount, PodSecurityContext, and NetworkPolicy support
- **Monitoring**: ServiceMonitor for Prometheus/Grafana integration
- **Scalability**: Horizontal Pod Autoscaling (optional)
- **Resilience**: PodDisruptionBudget for controlled disruptions

## Prerequisites

- Kubernetes 1.19+
- Helm 3.2.0+
- PersistentVolume provisioner support in the underlying infrastructure
- (Optional) cert-manager for automatic TLS certificate management
- (Optional) Rancher 2.5+ for Rancher-specific features

## Installation

### Quick Start

```bash
# Add the repository (if hosted)
helm repo add auth-stack https://your-repo-url.com
helm repo update

# Install with default values
helm install keycloak auth-stack/keycloak \
  --set keycloak.auth.adminPassword="YourSecurePassword" \
  --set postgresql.auth.password="YourDBPassword" \
  --set keycloak.configuration.hostname="keycloak.yourdomain.com"
```

### Install from local directory

```bash
# Navigate to the chart directory
cd keycloak-helm-chart

# Update dependencies
helm dependency update

# Install the chart
helm install keycloak . \
  --namespace keycloak \
  --create-namespace \
  --set keycloak.auth.adminPassword="YourSecurePassword" \
  --set postgresql.auth.password="YourDBPassword" \
  --set keycloak.configuration.hostname="keycloak.yourdomain.com"
```

### Install with custom values file

```bash
# Create a custom values file
cat > my-values.yaml <<EOF
keycloak:
  replicas: 3
  auth:
    adminUser: admin
    adminPassword: "MySecurePassword123!"
  configuration:
    hostname: keycloak.example.com

postgresql:
  auth:
    password: "MyDBPassword123!"

ingress:
  enabled: true
  className: "nginx"
  hosts:
    - host: keycloak.example.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: keycloak-tls
      hosts:
        - keycloak.example.com

rancher:
  projectId: "c-xxxxx:p-xxxxx"
  monitoring:
    enabled: true
    serviceMonitor:
      enabled: true
EOF

# Install with custom values
helm install keycloak . -f my-values.yaml --namespace keycloak --create-namespace
```

## Configuration

### Key Configuration Parameters

| Parameter | Description | Default |
|-----------|-------------|---------|
| `keycloak.replicas` | Number of Keycloak replicas | `2` |
| `keycloak.image.repository` | Keycloak image repository | `quay.io/keycloak/keycloak` |
| `keycloak.image.tag` | Keycloak image tag | `24.0.1` |
| `keycloak.auth.adminUser` | Keycloak admin username | `admin` |
| `keycloak.auth.adminPassword` | Keycloak admin password | `""` (required) |
| `keycloak.configuration.hostname` | Keycloak hostname | `keycloak.example.com` |
| `keycloak.configuration.proxy` | Proxy mode (edge/reencrypt/passthrough) | `edge` |
| `postgresql.enabled` | Enable PostgreSQL subchart | `true` |
| `postgresql.auth.password` | PostgreSQL password | `""` (required) |
| `ingress.enabled` | Enable ingress | `true` |
| `ingress.className` | Ingress class name | `nginx` |
| `rancher.projectId` | Rancher project ID | `""` |
| `rancher.monitoring.enabled` | Enable Rancher monitoring | `true` |

For a complete list of parameters, see [values.yaml](values.yaml).

## Rancher Integration

### Project Assignment

To assign the Keycloak deployment to a Rancher project:

```bash
helm install keycloak . \
  --set rancher.projectId="c-m-xxxxx:p-xxxxx" \
  --namespace keycloak
```

Find your project ID in Rancher UI or via CLI:
```bash
kubectl get projects -A
```

### Monitoring Integration

The chart includes a ServiceMonitor resource for Prometheus Operator integration:

```yaml
rancher:
  monitoring:
    enabled: true
    serviceMonitor:
      enabled: true
      interval: 30s
      scrapeTimeout: 10s
```

Access metrics at: `http://keycloak:8080/metrics`

### Ingress with Rancher/Traefik

For Rancher's default Traefik ingress:

```yaml
ingress:
  enabled: true
  className: "traefik"
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
    traefik.ingress.kubernetes.io/router.tls: "true"
```

### Storage Classes

Rancher provides storage classes like Longhorn. To use them:

```yaml
persistence:
  enabled: true
  storageClass: "longhorn"
  size: 1Gi

postgresql:
  primary:
    persistence:
      enabled: true
      storageClass: "longhorn"
      size: 8Gi
```

## High Availability Configuration

For production deployments, consider these settings:

```yaml
keycloak:
  replicas: 3

  resources:
    requests:
      cpu: 1000m
      memory: 1Gi
    limits:
      cpu: 2000m
      memory: 2Gi

  affinity:
    podAntiAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
        - labelSelector:
            matchExpressions:
              - key: app.kubernetes.io/name
                operator: In
                values:
                  - keycloak
          topologyKey: kubernetes.io/hostname

podDisruptionBudget:
  enabled: true
  minAvailable: 2

postgresql:
  readReplicas:
    replicaCount: 1
```

## External Database Configuration

To use an external PostgreSQL database instead of the bundled one:

```yaml
postgresql:
  enabled: false

keycloak:
  configuration:
    database:
      vendor: postgres
      hostname: "your-db-host.example.com"
      port: 5432
      database: keycloak
      username: keycloak
      password: "YourDBPassword"  # Or use existingSecret
```

## TLS/SSL Configuration

### Using cert-manager

```yaml
ingress:
  enabled: true
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
  tls:
    - secretName: keycloak-tls
      hosts:
        - keycloak.example.com
```

### Using existing TLS secret

```bash
# Create TLS secret
kubectl create secret tls keycloak-tls \
  --cert=path/to/tls.crt \
  --key=path/to/tls.key \
  -n keycloak
```

## Upgrading

```bash
# Update dependencies
helm dependency update

# Upgrade the release
helm upgrade keycloak . \
  --namespace keycloak \
  --reuse-values \
  --set keycloak.image.tag="24.0.2"
```

## Uninstalling

```bash
# Uninstall the release
helm uninstall keycloak --namespace keycloak

# Delete the namespace (if desired)
kubectl delete namespace keycloak
```

Note: PersistentVolumeClaims are not deleted automatically. Delete them manually if needed:

```bash
kubectl delete pvc -l app.kubernetes.io/instance=keycloak -n keycloak
```

## Accessing Keycloak

After installation, access Keycloak:

1. **Via Ingress** (if enabled):
   - URL: `https://keycloak.example.com`
   - Username: `admin` (or your configured admin user)
   - Password: Your configured admin password

2. **Via Port-Forward** (for testing):
   ```bash
   kubectl port-forward svc/keycloak 8080:8080 -n keycloak
   ```
   - URL: `http://localhost:8080`

3. **Via LoadBalancer** (if service type is LoadBalancer):
   ```bash
   kubectl get svc keycloak -n keycloak
   ```

## Troubleshooting

### Check pod status
```bash
kubectl get pods -n keycloak
kubectl describe pod keycloak-0 -n keycloak
kubectl logs keycloak-0 -n keycloak
```

### Check database connectivity
```bash
kubectl exec -it keycloak-0 -n keycloak -- sh
# Inside the pod
nc -zv keycloak-postgresql 5432
```

### Check ingress
```bash
kubectl get ingress -n keycloak
kubectl describe ingress keycloak -n keycloak
```

### Common Issues

1. **Pods not starting**: Check PVC status and storage class availability
2. **Database connection errors**: Verify PostgreSQL credentials and network policies
3. **Ingress not working**: Ensure ingress controller is installed and DNS is configured
4. **Certificate issues**: Check cert-manager logs and certificate status

## Security Considerations

1. **Always use strong passwords** for admin and database credentials
2. **Use secrets management**: Consider using external secrets operators (e.g., External Secrets Operator)
3. **Enable NetworkPolicy** in production environments
4. **Regular updates**: Keep Keycloak and dependencies up to date
5. **TLS/SSL**: Always use HTTPS in production
6. **RBAC**: Review and customize RBAC rules as needed

## Example: Full Production Configuration

```yaml
keycloak:
  replicas: 3

  image:
    tag: "24.0.1"

  auth:
    adminUser: admin
    existingSecret: "keycloak-admin-secret"

  configuration:
    hostname: keycloak.production.example.com
    proxy: edge
    logLevel: WARN

  resources:
    requests:
      cpu: 1000m
      memory: 1Gi
    limits:
      cpu: 2000m
      memory: 2Gi

postgresql:
  enabled: true
  auth:
    existingSecret: "keycloak-postgresql-secret"
  primary:
    persistence:
      enabled: true
      storageClass: "longhorn"
      size: 20Gi
    resources:
      requests:
        cpu: 500m
        memory: 512Mi
      limits:
        cpu: 1000m
        memory: 1Gi

ingress:
  enabled: true
  className: "nginx"
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
  hosts:
    - host: keycloak.production.example.com
      paths:
        - path: /
          pathType: Prefix
  tls:
    - secretName: keycloak-production-tls
      hosts:
        - keycloak.production.example.com

rancher:
  projectId: "c-m-xxxxx:p-xxxxx"
  monitoring:
    enabled: true
    serviceMonitor:
      enabled: true

podDisruptionBudget:
  enabled: true
  minAvailable: 2

autoscaling:
  enabled: true
  minReplicas: 3
  maxReplicas: 6
  targetCPUUtilizationPercentage: 80
```

## Support

For issues and questions:
- Keycloak Documentation: https://www.keycloak.org/documentation
- Rancher Documentation: https://rancher.com/docs/
- Chart Issues: Create an issue in the repository

## License

This Helm chart is provided as-is under the Apache 2.0 license.
