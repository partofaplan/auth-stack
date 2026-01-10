# External Database - Quick Reference

## 30-Second Setup

If you have a PostgreSQL database ready, deploy in 3 commands:

```bash
cd keycloak-helm-chart
./install-external-db.sh
# Answer the prompts and you're done!
```

---

## Manual 5-Minute Setup

### 1. Prepare Database

```sql
-- Connect to PostgreSQL and run:
CREATE DATABASE keycloak;
CREATE USER keycloak WITH PASSWORD 'your-password';
GRANT ALL PRIVILEGES ON DATABASE keycloak TO keycloak;
```

### 2. Deploy Keycloak

```bash
cd keycloak-helm-chart

helm install keycloak . \
  -f values-external-db.yaml \
  --namespace keycloak \
  --create-namespace \
  --set keycloak.auth.adminPassword="AdminPassword123" \
  --set keycloak.configuration.hostname="keycloak.example.com" \
  --set keycloak.configuration.database.hostname="postgres.example.com" \
  --set keycloak.configuration.database.password="your-password"
```

### 3. Access

```bash
# Port-forward
kubectl port-forward svc/keycloak 8080:8080 -n keycloak

# Open: http://localhost:8080
# Username: admin
# Password: AdminPassword123
```

---

## Cloud Database Examples

### AWS RDS
```bash
--set keycloak.configuration.database.hostname="mydb.abc123.us-east-1.rds.amazonaws.com"
```

### Azure Database
```bash
--set keycloak.configuration.database.hostname="myserver.postgres.database.azure.com" \
--set keycloak.configuration.database.username="keycloak@myserver"
```

### Google Cloud SQL
```bash
--set keycloak.configuration.database.hostname="35.xxx.xxx.xxx"
```

---

## Why External Database?

✅ **No Helm dependency issues** - No "Chart.yaml file is missing" errors
✅ **Production-ready** - Use AWS RDS, Azure Database, Google Cloud SQL
✅ **Better reliability** - Managed databases with backups
✅ **Easier management** - Separate database lifecycle
✅ **Cost-effective** - Use existing database infrastructure

---

## Full Documentation

- **Detailed Setup**: [EXTERNAL-DATABASE-SETUP.md](EXTERNAL-DATABASE-SETUP.md)
- **Troubleshooting**: [TROUBLESHOOTING.md](TROUBLESHOOTING.md)
- **All Options**: [INSTALL-OPTIONS.md](INSTALL-OPTIONS.md)
