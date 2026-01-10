# Helm Charts Overview

This repository contains two Helm charts for deploying a complete authentication stack on Kubernetes.

## Charts Included

### 1. PostgreSQL Helm Chart
**Location**: `postgresql-helm-chart/`

A minimal, standalone PostgreSQL database chart designed specifically for Keycloak.

**Key Features**:
- Single-instance PostgreSQL 16
- StatefulSet with persistent storage
- Health checks and resource limits
- Pre-configured for Keycloak database
- Simple and lightweight (no complex dependencies)

**Quick Install**:
```bash
cd postgresql-helm-chart
./install.sh
```

**Use Cases**:
- Development and testing
- Small production deployments
- When you want full control over the database
- Avoiding Helm dependency issues

### 2. Keycloak Helm Chart
**Location**: `keycloak-helm-chart/`

A production-ready Keycloak IAM chart with multiple deployment options.

**Key Features**:
- High availability (configurable replicas)
- Clustering support (JGroups)
- Multiple database options (bundled, external, managed services)
- Ingress with TLS support
- Rancher integration (monitoring, projects, UI)
- ServiceMonitor for Prometheus
- Pod Disruption Budget for HA
- Horizontal Pod Autoscaling

**Quick Install Options**:
```bash
# With external database (recommended)
cd keycloak-helm-chart
./install-external-db.sh

# With bundled database (testing)
./install-simple.sh

# Full install (with dependencies)
./install.sh
```

**Use Cases**:
- Production SSO/IAM deployments
- Multi-tenant authentication
- Identity brokering
- API authentication and authorization

## Deployment Architectures

### Architecture 1: Standalone PostgreSQL + Keycloak (Recommended)

```
┌─────────────────┐
│   Kubernetes    │
│                 │
│  ┌───────────┐  │
│  │PostgreSQL │  │  ← Standalone chart
│  │Namespace  │  │
│  └─────▲─────┘  │
│        │        │
│  ┌─────┴─────┐  │
│  │ Keycloak  │  │  ← External DB mode
│  │ Namespace │  │
│  └───────────┘  │
└─────────────────┘
```

**Advantages**:
- ✅ No Helm dependency issues
- ✅ Clean separation of concerns
- ✅ Easy to manage independently
- ✅ Works with any PostgreSQL version

**Deploy**:
```bash
# 1. PostgreSQL
cd postgresql-helm-chart
./install.sh

# 2. Keycloak
cd ../keycloak-helm-chart
./install-external-db.sh
```

### Architecture 2: Keycloak with Bundled Database

```
┌─────────────────┐
│   Kubernetes    │
│                 │
│  ┌───────────┐  │
│  │           │  │
│  │ Keycloak  │  │
│  │ Namespace │  │
│  │           │  │
│  │ ┌───────┐ │  │
│  │ │ PG    │ │  │  ← Bitnami subchart
│  │ └───────┘ │  │
│  └───────────┘  │
└─────────────────┘
```

**Advantages**:
- ✅ Single Helm release
- ✅ Quick testing/demo
- ✅ All-in-one deployment

**Deploy**:
```bash
cd keycloak-helm-chart
./install-simple.sh
```

### Architecture 3: Keycloak with Managed Database

```
┌─────────────────┐     ┌─────────────┐
│   Kubernetes    │     │   Cloud     │
│                 │     │             │
│  ┌───────────┐  │     │ ┌─────────┐ │
│  │ Keycloak  │─────────▶│   RDS   │ │
│  │ Namespace │  │     │ │ Azure   │ │
│  └───────────┘  │     │ │ Cloud   │ │
└─────────────────┘     │ └─────────┘ │
                        └─────────────┘
```

**Advantages**:
- ✅ Managed backups and HA
- ✅ Better reliability
- ✅ Automatic updates
- ✅ Enterprise support

**Deploy**:
```bash
cd keycloak-helm-chart
./install-external-db.sh
# Enter your managed database endpoint
```

## Comparison

| Feature | Standalone PostgreSQL | Bundled PostgreSQL | Managed Database |
|---------|----------------------|-------------------|------------------|
| **Ease of Deploy** | Medium | Easy | Easy |
| **Helm Dependencies** | None | Bitnami chart | None |
| **Separation of Concerns** | ✅ | ❌ | ✅ |
| **Production Ready** | ✅ | ⚠️ Limited | ✅✅ |
| **Cost** | Low | Low | Higher |
| **Maintenance** | Manual | Manual | Managed |
| **Backups** | Manual | Manual | Automatic |
| **High Availability** | Single instance | Single instance | Built-in |
| **Best For** | Dev/Test, Small Prod | Quick Testing | Production |

## File Structure

```
auth-stack/
├── postgresql-helm-chart/
│   ├── Chart.yaml
│   ├── values.yaml
│   ├── install.sh
│   ├── README.md
│   └── templates/
│       ├── statefulset.yaml
│       ├── service.yaml
│       ├── secret.yaml
│       ├── serviceaccount.yaml
│       └── NOTES.txt
│
├── keycloak-helm-chart/
│   ├── Chart.yaml
│   ├── values.yaml
│   ├── values-external-db.yaml      ← For external database
│   ├── values-production.yaml       ← Production settings
│   ├── values-rancher.yaml          ← Rancher integration
│   ├── install.sh                   ← Full installer
│   ├── install-simple.sh            ← Simple installer
│   ├── install-external-db.sh       ← External DB installer
│   ├── validate.sh
│   ├── README.md
│   ├── EXTERNAL-DATABASE-SETUP.md
│   ├── TROUBLESHOOTING.md
│   ├── INSTALL-OPTIONS.md
│   └── templates/
│       ├── statefulset.yaml
│       ├── service.yaml
│       ├── ingress.yaml
│       ├── configmap.yaml
│       ├── secret.yaml
│       ├── serviceaccount.yaml
│       ├── rbac.yaml
│       ├── servicemonitor.yaml
│       └── poddisruptionbudget.yaml
│
├── README.md                        ← Main overview
├── FULL-STACK-DEPLOYMENT.md         ← Complete deployment guide
├── DEPLOYMENT-GUIDE.md              ← Keycloak-focused guide
├── QUICK-START.md                   ← Quick reference
└── CHARTS-OVERVIEW.md               ← This file
```

## Quick Reference Commands

### PostgreSQL Chart

```bash
# Install
helm install postgres ./postgresql-helm-chart \
  --namespace postgres \
  --create-namespace \
  --set postgresql.auth.password="pass" \
  --set postgresql.auth.postgresPassword="superpass"

# Uninstall
helm uninstall postgres -n postgres

# Backup
kubectl exec postgres-postgresql-0 -n postgres -- \
  pg_dump -U keycloak keycloak > backup.sql
```

### Keycloak Chart

```bash
# Install with external DB
helm install keycloak ./keycloak-helm-chart \
  -f keycloak-helm-chart/values-external-db.yaml \
  --namespace keycloak \
  --create-namespace \
  --set keycloak.auth.adminPassword="pass" \
  --set keycloak.configuration.hostname="keycloak.local" \
  --set keycloak.configuration.database.hostname="postgres.postgres.svc.cluster.local" \
  --set keycloak.configuration.database.password="dbpass"

# Uninstall
helm uninstall keycloak -n keycloak

# Scale
helm upgrade keycloak ./keycloak-helm-chart \
  --reuse-values \
  --set keycloak.replicas=3 \
  -n keycloak
```

## Documentation Index

### Getting Started
- [README.md](README.md) - Main overview and quick start
- [QUICK-START.md](QUICK-START.md) - 5-minute quick start
- [FULL-STACK-DEPLOYMENT.md](FULL-STACK-DEPLOYMENT.md) - Complete stack deployment

### PostgreSQL
- [postgresql-helm-chart/README.md](postgresql-helm-chart/README.md) - PostgreSQL chart documentation

### Keycloak
- [keycloak-helm-chart/README.md](keycloak-helm-chart/README.md) - Keycloak chart documentation
- [keycloak-helm-chart/EXTERNAL-DATABASE-SETUP.md](keycloak-helm-chart/EXTERNAL-DATABASE-SETUP.md) - External database guide
- [keycloak-helm-chart/INSTALL-OPTIONS.md](keycloak-helm-chart/INSTALL-OPTIONS.md) - All installation methods
- [keycloak-helm-chart/TROUBLESHOOTING.md](keycloak-helm-chart/TROUBLESHOOTING.md) - Troubleshooting guide

### Deployment Guides
- [DEPLOYMENT-GUIDE.md](DEPLOYMENT-GUIDE.md) - Comprehensive Keycloak deployment
- [CHART-SUMMARY.md](CHART-SUMMARY.md) - Feature summary

## Support Matrix

| Platform | PostgreSQL Chart | Keycloak Chart |
|----------|-----------------|----------------|
| Kubernetes 1.19+ | ✅ | ✅ |
| OpenShift | ✅ | ✅ |
| Rancher | ✅ | ✅✅ (native integration) |
| AWS EKS | ✅ | ✅ |
| Azure AKS | ✅ | ✅ |
| Google GKE | ✅ | ✅ |

## Tested Configurations

- ✅ PostgreSQL 16 + Keycloak 24
- ✅ Kubernetes 1.24-1.29
- ✅ Rancher 2.7+
- ✅ Longhorn storage
- ✅ AWS RDS PostgreSQL
- ✅ Azure Database for PostgreSQL
- ✅ Google Cloud SQL

## License

Apache 2.0
