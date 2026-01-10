# Keycloak - Identity and Access Management

Keycloak is an open-source Identity and Access Management solution aimed at modern applications and services. It makes it easy to secure applications and services with little to no code.

## Features

- **Single-Sign On (SSO)**: Users authenticate with Keycloak rather than individual applications
- **Identity Brokering**: Authenticate with external OpenID Connect or SAML Identity Providers
- **Social Login**: Enable login with Google, GitHub, Facebook, Twitter, and more
- **User Federation**: Sync users from LDAP and Active Directory servers
- **Client Adapters**: Secure applications easily with pre-built adapters
- **Admin Console**: Centralized management console for all your configuration
- **Account Management Console**: Allows users to manage their own accounts
- **Standard Protocols**: OpenID Connect, OAuth 2.0, and SAML 2.0 support
- **Authorization Services**: Fine-grained authorization using various access control mechanisms
- **Customizable**: Themes, custom user storage providers, and event listeners

## This Deployment

This Helm chart deploys Keycloak with the following features:

- **High Availability**: Multiple replicas with clustering support
- **Persistent Storage**: Data persists across pod restarts
- **PostgreSQL Database**: Integrated database for production use
- **Ingress Ready**: Pre-configured ingress with TLS support
- **Rancher Integration**: ServiceMonitor, project labels, and Rancher UI support
- **Security**: RBAC, service accounts, and security contexts
- **Monitoring**: Metrics endpoint for Prometheus/Grafana

## Quick Start

After deployment:

1. Wait for all pods to be ready:
   ```bash
   kubectl get pods -n <namespace>
   ```

2. Access Keycloak admin console at your configured hostname

3. Log in with the admin credentials you provided during installation

4. Start configuring your realms, clients, and users

## Default Ports

- **8080**: HTTP (admin console and application)
- **8443**: HTTPS (if enabled)

## Documentation

- Official Documentation: https://www.keycloak.org/documentation
- Getting Started: https://www.keycloak.org/getting-started
- Server Administration: https://www.keycloak.org/docs/latest/server_admin/

## Support

For issues specific to this Helm chart, please contact your administrator.

For Keycloak issues and questions, visit:
- Documentation: https://www.keycloak.org/documentation
- Community: https://www.keycloak.org/community
- Mailing List: https://www.keycloak.org/support
