# Application-Level Keycloak Integration Guide

This guide explains how application-level Keycloak authentication is configured for Local AI Packaged services after moving away from the OAuth2 Proxy ingress auth pattern.

## Overview

Rather than enforcing authentication at the ingress level (which caused redirect loop issues), each application now integrates directly with Keycloak for authentication:

- **Flowise**: Uses Keycloak OIDC configuration via environment variables
- **n8n**: Uses Keycloak OIDC endpoints and excludes OAuth callback endpoints from auth
- **Neo4j**: Browser UI includes login form (standard Neo4j authentication)
- **SearXNG**: Search engine without authentication (public access)

## Architecture

```
User Browser
    ↓
HTTPS to Service (n8n.lupulup.com, flowise.lupulup.com, etc.)
    ↓
Nginx Ingress (TLS termination, no auth)
    ↓
Service Container (runs login form/auth)
    ↓ (on first access/no session)
Keycloak (homelab realm)
    ↓
Service (establishes session cookie)
```

## Service-Specific Configuration

### 1. Flowise (flowiseai/flowise)

**Location**: `k8s/apps/flowise/deployment.yaml`

**Keycloak Credentials**:
- Client ID: `flowise`
- Client Secret: `Rxw3PxcTggcYa2oN9vUDx5MSWCL0PAGQ`

**Environment Variables** (ConfigMap):
```yaml
KEYCLOAK_ENABLED: "true"
KEYCLOAK_CLIENT_ID: "flowise"
KEYCLOAK_REALM_URL: "https://keycloak.mylegion5pro.me/realms/homelab"
KEYCLOAK_AUTH_URL: "https://keycloak.mylegion5pro.me/realms/homelab/protocol/openid-connect/auth"
KEYCLOAK_TOKEN_URL: "https://keycloak.mylegion5pro.me/realms/homelab/protocol/openid-connect/token"
KEYCLOAK_USERINFO_URL: "https://keycloak.mylegion5pro.me/realms/homelab/protocol/openid-connect/userinfo"
KEYCLOAK_REDIRECT_URI: "https://flowise.lupulup.com/auth/callback"
```

**Client Secret** (Secret):
```yaml
KEYCLOAK_CLIENT_SECRET: "Rxw3PxcTggcYa2oN9vUDx5MSWCL0PAGQ"
```

**How It Works**:
1. User accesses `https://flowise.lupulup.com`
2. Flowise detects no authenticated session
3. Redirects to Keycloak login form
4. User enters credentials (homelab realm)
5. Keycloak redirects back to `https://flowise.lupulup.com/auth/callback`
6. Flowise establishes session and user can access application

### 2. n8n (n8nio/n8n)

**Location**: `k8s/apps/n8n/`

**Keycloak Credentials**:
- Client ID: `n8n`
- Client Secret: `TN7cydhZ8S6FLYtRNw9jcuOoIMb6wnyW`

**Environment Variables** (ConfigMap):
```yaml
N8N_AUTH_EXCLUDEENDPOINTS: "/rest/oauth2/callback,/rest/webhook"
N8N_EXTERNAL_FRONTEND_URL: "https://n8n.lupulup.com"
```

**Client Secret** (Secret):
```yaml
KEYCLOAK_CLIENT_SECRET: "TN7cydhZ8S6FLYtRNw9jcuOoIMb6wnyW"
```

**Important Notes**:
- The `N8N_AUTH_EXCLUDEENDPOINTS` setting allows webhook and OAuth callback URLs to work without authentication
- Webhooks can be called from external systems without credentials
- OAuth callback endpoint doesn't require authentication (needed for the redirect from Keycloak)

**How It Works**:
1. User accesses `https://n8n.lupulup.com`
2. n8n detects no authenticated session
3. Displays n8n login form (not Keycloak login - n8n handles auth internally)
4. n8n can optionally sync users from Keycloak via backend configuration
5. User establishes session

**Note**: n8n has built-in user management. To enable Keycloak OIDC in n8n, additional configuration through n8n's OIDC plugin may be needed, which is beyond this basic setup.

### 3. Neo4j (neo4j:4.4.19)

**Location**: `k8s/apps/neo4j/statefulset.yaml`

**Service URL**: `https://neo4j.lupulup.com`

**Authentication**:
- Default credentials are used (see `k8s/apps/neo4j/secret.yaml`)
- Neo4j Browser at `https://neo4j.lupulup.com` includes built-in login form
- No Keycloak integration (Neo4j manages its own authentication)

**Default Credentials**:
```yaml
NEO4J_AUTH: "neo4j/neo4j_secure_123"
NEO4J_PASSWORD: "neo4j_secure_123"
```

**How It Works**:
1. User accesses `https://neo4j.lupulup.com`
2. Neo4j Browser login form appears
3. User enters Neo4j credentials (default: neo4j/neo4j_secure_123)
4. User can access Neo4j Browser UI

**To Add Keycloak Integration to Neo4j**:
- Use Neo4j's LDAP/SAML authentication plugins
- Configure LDAP connector to Keycloak
- See Neo4j documentation on external authentication

### 4. SearXNG (searxng/searxng)

**Location**: `k8s/apps/searxng/deployment.yaml`

**Service URL**: `https://searxng.lupulup.com`

**Authentication**: None (Public Access)

SearXNG is configured as a public metasearch engine with no authentication required. All users can access search functionality without logging in.

**Configuration**:
```yaml
BASE_URL: "https://searxng.lupulup.com/"
SEARXNG_REDIS_URL: "redis://redis.local-ai-system.svc.cluster.local:6379"
```

**To Add Authentication to SearXNG**:
1. Implement a reverse proxy in front (e.g., OAuth2-Proxy with proper configuration)
2. Or use SearXNG's built-in authentication plugins
3. Would require separate configuration beyond this guide

## Why We Switched Away from OAuth2 Proxy

### The Problem
Using OAuth2 Proxy at the Nginx Ingress level with `auth-url` annotations created a redirect loop:
- Nginx Ingress would send `/oauth2/auth` requests to OAuth2 Proxy
- OAuth2 Proxy returned 401 Unauthorized because the request context was incomplete
- Browser would get infinite redirects between service and Keycloak

### The Solution
Application-level authentication allows each service to handle auth directly:
- No relay through OAuth2 Proxy's auth endpoint
- Each service knows its own authentication requirements
- Services can provide proper login UIs
- Better compatibility with existing application auth systems

## Configuration in Kubernetes

All Keycloak credentials are stored in Kubernetes Secrets:

**Flowise Secret**:
```bash
kubectl get secret -n local-ai-flowise flowise-secrets -o yaml
```

**n8n Secret**:
```bash
kubectl get secret -n local-ai-n8n n8n-secrets -o yaml
```

### Updating Secrets

If you need to rotate Keycloak client secrets:

```bash
# Edit the secret
kubectl edit secret flowise-secrets -n local-ai-flowise

# Or patch it
kubectl patch secret flowise-secrets -n local-ai-flowise \
  -p '{"stringData":{"KEYCLOAK_CLIENT_SECRET":"new-secret"}}'

# Restart the pod to pick up the change
kubectl rollout restart deployment/flowise -n local-ai-flowise
```

## Ingress Configuration

After moving to application-level auth, ingress resources are simplified:

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: flowise
  namespace: local-ai-flowise
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod-dns"
    nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - flowise.lupulup.com
    secretName: flowise-tls
  rules:
  - host: flowise.lupulup.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: flowise
            port:
              number: 3000
```

**Key Changes**:
- ❌ Removed: `nginx.ingress.kubernetes.io/auth-url`
- ❌ Removed: `nginx.ingress.kubernetes.io/auth-signin`
- ❌ Removed: `nginx.ingress.kubernetes.io/auth-response-headers`
- ✅ Updated: `cert-manager.io/cluster-issuer: "letsencrypt-prod-dns"` (using DNS-01 validation)

## Testing Authentication Flow

### Flowise
1. Open `https://flowise.lupulup.com` in browser
2. Flowise should display its interface with Keycloak login option
3. Click login and authenticate with Keycloak credentials
4. You should be redirected back to Flowise authenticated

### n8n
1. Open `https://n8n.lupulup.com` in browser
2. n8n login form appears
3. Default credentials can be used, or configure Keycloak sync

### Neo4j Browser
1. Open `https://neo4j.lupulup.com` in browser
2. Neo4j Browser login form appears
3. Use Neo4j credentials (default: neo4j/neo4j_secure_123)

### SearXNG
1. Open `https://searxng.lupulup.com` in browser
2. Public search interface appears immediately (no auth required)

## Service-to-Service Communication

Services can communicate internally without authentication:

**Example - n8n to Flowise**:
```
n8n pod (local-ai-n8n)
    ↓ (internal Kubernetes DNS)
flowise.local-ai-flowise.svc.cluster.local:3000
    ↓
Flowise pod (no TLS, no auth needed)
```

## OAuth2 Proxy Status

OAuth2 Proxy deployment remains in place but is not used for authentication:
- **Status**: Deployed but disabled in ingress annotations
- **Use Case**: Can be repurposed for other services or for centralized audit logging
- **Location**: `local-ai-system` namespace
- **Config**: `k8s/apps/_common/oauth2-proxy-base.yaml`

To completely remove OAuth2 Proxy if no longer needed:
```bash
kubectl delete deployment/oauth2-proxy -n local-ai-system
kubectl delete service/oauth2-proxy -n local-ai-system
kubectl delete configmap/oauth2-proxy-base -n local-ai-system
kubectl delete secret/oauth2-proxy-secrets -n local-ai-system
```

## Keycloak Client Configuration Reference

### Flowise Client
- **Client ID**: flowise
- **Protocol**: openid-connect
- **Access Type**: confidential
- **Redirect URIs**: `https://flowise.lupulup.com/auth/callback`
- **Web Origins**: `https://flowise.lupulup.com`

### n8n Client
- **Client ID**: n8n
- **Protocol**: openid-connect
- **Access Type**: confidential
- **Redirect URIs**: `https://n8n.lupulup.com/oauth2/callback`
- **Web Origins**: `https://n8n.lupulup.com`

### Neo4j Client
- **Client ID**: neo4j
- **Protocol**: openid-connect
- **Access Type**: confidential
- **Redirect URIs**: `https://neo4j.lupulup.com/oauth2/callback`
- **Web Origins**: `https://neo4j.lupulup.com`

### SearXNG Client
- **Client ID**: searxng
- **Protocol**: openid-connect
- **Access Type**: confidential
- **Redirect URIs**: `https://searxng.lupulup.com/oauth2/callback`
- **Web Origins**: `https://searxng.lupulup.com`

All clients use PKCE (S256) for enhanced security.

## Troubleshooting

### Services Return Unauthorized
- Check if Keycloak is accessible from the pod
- Verify client secrets match in Keycloak vs Kubernetes secret
- Check pod logs: `kubectl logs -n local-ai-flowise deployment/flowise`

### Redirect Loop Still Occurs
- Verify OAuth2 Proxy auth annotations are removed from ingress
- Check: `kubectl get ingress -n local-ai-flowise flowise -o yaml`
- Remove annotations if they exist: `kubectl annotate ingress flowise -n local-ai-flowise nginx.ingress.kubernetes.io/auth-url-`

### Certificate Issues
- Certificates use DNS-01 validation via Cloudflare
- Check certificate status: `kubectl get certificate -n local-ai-flowise`
- Check cert-manager logs: `kubectl logs -n cert-manager deployment/cert-manager`

### Keycloak Realm Unavailable
- Verify Keycloak is running: `kubectl get pods -n keycloak`
- Check Keycloak URL from pod: `kubectl exec -it -n local-ai-flowise deployment/flowise -- curl -I https://keycloak.mylegion5pro.me/realms/homelab`
- Verify DNS resolution: `nslookup keycloak.mylegion5pro.me`

## Next Steps

1. **Configure User Groups in Keycloak**:
   - Create groups: `admins`, `developers`, `explorers`
   - Assign users to appropriate groups
   - Configure role-based access in applications

2. **Enable SSO Across Multiple Applications**:
   - Each new application can follow the same pattern
   - Register client in Keycloak
   - Add environment variables to app configuration
   - Update ingress (remove OAuth2 Proxy annotations)

3. **Implement Application-Specific Authorization**:
   - Configure Flowise to show different features based on groups
   - Configure n8n to restrict workflow execution based on roles
   - Add audit logging for authentication events

4. **Monitor Authentication Events**:
   - Check Keycloak admin console for login attempts
   - Review application logs for failed authentications
   - Set up alerts for suspicious activity

## References

- [Keycloak Documentation](https://www.keycloak.org/docs/)
- [Flowise Documentation](https://docs.flowiseai.com/)
- [n8n Documentation](https://docs.n8n.io/)
- [Neo4j Authentication](https://neo4j.com/docs/operations-manual/current/authentication-authorization/)
