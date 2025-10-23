# Keycloak SSO Integration Guide

This guide explains how to configure Keycloak for SSO with all Local AI applications.

## Prerequisites

- Keycloak instance running on `https://keycloak.mylegion5pro.me`
- Access to Keycloak admin console
- `homelab` realm already created

## Architecture

```
User → Nginx Proxy Manager → Ingress → OAuth2 Proxy → Keycloak
                                            ↓
                                      Application
```

Each application is protected by OAuth2 Proxy, which validates tokens against Keycloak.

## Step 1: Create OAuth2 Proxy Client in Keycloak

This is the main client that handles all SSO redirects.

### In Keycloak Admin Console:

1. Go to **Clients** → **Create**
2. Client ID: `oauth2-proxy`
3. Client Protocol: `openid-connect`
4. Click **Save**

### Configure Client Settings:

1. **Access Type**: `confidential`
2. **Valid Redirect URIs**:
   ```
   https://n8n.lupulup.com/oauth2/callback
   https://flowise.lupulup.com/oauth2/callback
   https://neo4j.lupulup.com/oauth2/callback
   https://searxng.lupulup.com/oauth2/callback
   https://supabase.lupulup.com/oauth2/callback
   ```
3. **Web Origins**:
   ```
   https://n8n.lupulup.com
   https://flowise.lupulup.com
   https://neo4j.lupulup.com
   https://searxng.lupulup.com
   https://supabase.lupulup.com
   ```

4. **Client Secret**: Copy from **Credentials** tab

### Enable Required Features:

- ✅ Standard Flow Enabled
- ✅ Direct Access Grants Enabled
- ✅ Service Accounts Enabled
- ✅ Authorization Enabled

5. Click **Save**

## Step 2: Configure Keycloak Client Secrets

Generate credentials for OAuth2 Proxy:

```bash
# Get the client secret
kubectl get secret -n local-ai-system oauth2-proxy-secrets -o jsonpath='{.data.client-secret}' | base64 -d
```

Or in Keycloak:
1. Go to **Clients** → **oauth2-proxy** → **Credentials**
2. Copy the **Client Secret**

## Step 3: Update Sealed Secrets

Create the encrypted secret for OAuth2 Proxy:

```bash
# First, create the plain secret
cat > /tmp/oauth2-proxy-secret.yaml <<'EOF'
apiVersion: v1
kind: Secret
metadata:
  name: oauth2-proxy-secrets
  namespace: local-ai-system
type: Opaque
stringData:
  client-id: "oauth2-proxy"
  client-secret: "YOUR_KEYCLOAK_CLIENT_SECRET_HERE"
  cookie-secret: "YOUR_32_BYTE_BASE64_ENCODED_SECRET"
EOF

# Generate a random cookie secret
openssl rand -base64 32 > /tmp/cookie-secret.txt

# Update the YAML
sed -i "s/YOUR_32_BYTE_BASE64_ENCODED_SECRET/$(cat /tmp/cookie-secret.txt)/" /tmp/oauth2-proxy-secret.yaml

# Seal it
kubeseal -f /tmp/oauth2-proxy-secret.yaml -w k8s/apps/_common/oauth2-proxy-sealed-secret.yaml

# Apply the sealed secret
kubectl apply -f k8s/apps/_common/oauth2-proxy-sealed-secret.yaml
```

## Step 4: Create Service-Specific OAuth2 Clients (Optional)

For fine-grained control, you can create separate clients per service:

### n8n Client
1. **Client ID**: `n8n`
2. **Valid Redirect URIs**: `https://n8n.lupulup.com/*`
3. **Web Origins**: `https://n8n.lupulup.com`

### Flowise Client
1. **Client ID**: `flowise`
2. **Valid Redirect URIs**: `https://flowise.lupulup.com/*`
3. **Web Origins**: `https://flowise.lupulup.com`

### Neo4j Client
1. **Client ID**: `neo4j`
2. **Valid Redirect URIs**: `https://neo4j.lupulup.com/*`
3. **Web Origins**: `https://neo4j.lupulup.com`

### SearXNG Client
1. **Client ID**: `searxng`
2. **Valid Redirect URIs**: `https://searxng.lupulup.com/*`
3. **Web Origins**: `https://searxng.lupulup.com`

### Supabase Client
1. **Client ID**: `supabase`
2. **Valid Redirect URIs**: `https://supabase.lupulup.com/*`
3. **Web Origins**: `https://supabase.lupulup.com`

## Step 5: Configure Mappers (Optional)

To pass user information to applications, configure mappers:

1. Go to **Clients** → **oauth2-proxy** → **Mappers**
2. **Add Builtin**:
   - Username
   - Email
   - Given Name
   - Family Name

3. **Add Custom Mapper** for groups:
   - Name: `groups`
   - Mapper Type: `User Client Role`
   - Token Claim Name: `groups`

## Step 6: Configure User Groups and Roles

Assign users to groups for access control:

```bash
# In Keycloak Admin Console:
# Go to Users → Select User → Groups

# Available groups:
- admins (admin role)
- developers (developer role)
- explorers (explorer role)
```

## Step 7: Verify OAuth2 Proxy Configuration

Check that OAuth2 Proxy is configured correctly:

```bash
# Check OAuth2 Proxy deployment
kubectl get deployment -n local-ai-system oauth2-proxy

# Check logs
kubectl logs -n local-ai-system deployment/oauth2-proxy

# Verify ConfigMap
kubectl get configmap -n local-ai-system oauth2-proxy-config -o yaml

# Verify Secret
kubectl get secret -n local-ai-system oauth2-proxy-secrets
```

## Step 8: Test SSO Flow

1. Visit `https://n8n.lupulup.com`
2. You should be redirected to Keycloak login
3. Enter credentials:
   - Username: `admin`
   - Password: `Admin!234`
4. You should be redirected back to n8n
5. Check that you're authenticated in n8n

### Troubleshooting OAuth2 Proxy

```bash
# Check OAuth2 Proxy logs
kubectl logs -n local-ai-system -f deployment/oauth2-proxy

# Common errors:
# - "invalid_client": Check client ID and secret
# - "redirect_uri_mismatch": Update redirect URIs in Keycloak
# - "access_denied": Check user roles and groups
```

## Step 9: Update Ingress Annotations

Each service's Ingress already has OAuth2 Proxy annotations configured:

```yaml
nginx.ingress.kubernetes.io/auth-url: "http://oauth2-proxy.local-ai-system.svc.cluster.local:4180/oauth2/auth"
nginx.ingress.kubernetes.io/auth-signin: "https://keycloak.mylegion5pro.me/realms/homelab/protocol/openid-connect/auth?..."
```

These are pre-configured in each service's `ingress.yaml` file.

## Advanced: Custom Claims

To add custom claims to the OAuth2 tokens:

1. Go to **Clients** → **oauth2-proxy** → **Mappers**
2. **Add** → **Custom - Hardcoded Claim**
   - Name: `department`
   - Token Claim Name: `department`
   - Claim value: `engineering`

## Advanced: Groups as Roles

To map Keycloak groups to application roles:

1. Go to **Clients** → **oauth2-proxy** → **Mappers**
2. **Add** → **User Client Role Mapper**
   - Client ID: `oauth2-proxy`
   - Token Claim Name: `groups`

## Logout Configuration

When users click logout in n8n or Flowise:

1. Application clears local session
2. OAuth2 Proxy should redirect to:
   ```
   https://keycloak.mylegion5pro.me/realms/homelab/protocol/openid-connect/logout?redirect_uri=https://n8n.lupulup.com
   ```

This is already configured in `k8s/apps/_common/oauth2-proxy-base.yaml`.

## OIDC Discovery

OAuth2 Proxy automatically discovers Keycloak's OIDC endpoints from:
```
https://keycloak.mylegion5pro.me/realms/homelab/.well-known/openid-configuration
```

## Monitoring and Debugging

### View Active Sessions
```bash
kubectl exec -n local-ai-system oauth2-proxy-0 -- curl http://localhost:4180/info
```

### Check User Sessions in Keycloak
1. Go to **Sessions**
2. See all active sessions and devices

### View OAuth2 Logs
```bash
kubectl logs -n local-ai-system -f deployment/oauth2-proxy | grep -i "oauth\|auth\|error"
```

## Next Steps

1. Verify each application is protected by SSO
2. Test login flow for each user group
3. Configure application-specific permissions
4. Set up audit logging in Keycloak

## References

- [OAuth2 Proxy Documentation](https://oauth2-proxy.github.io/oauth2-proxy/)
- [Keycloak OIDC Configuration](https://www.keycloak.org/docs/latest/server_admin/#_oidc_clients)
- [Nginx Ingress Auth](https://kubernetes.github.io/ingress-nginx/examples/auth/oauth-external-auth/)
