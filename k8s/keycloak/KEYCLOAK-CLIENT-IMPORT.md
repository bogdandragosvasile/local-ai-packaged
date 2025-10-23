# Keycloak OAuth2 Client Configuration Guide

This guide explains how to import and configure OAuth2 clients in Keycloak for your local-ai services.

## Overview

Five OAuth2 clients are configured:

1. **oauth2-proxy** (Central SSO Gateway) - Handles authentication for all services via OAuth2 Proxy
2. **n8n** (Individual client for n8n)
3. **flowise** (Individual client for Flowise)
4. **neo4j** (Individual client for Neo4j)
5. **searxng** (Individual client for SearXNG)

## Prerequisites

- Keycloak running at `https://keycloak.mylegion5pro.me`
- Admin access to Keycloak (realm: `homelab`)
- JSON client configuration files in `k8s/keycloak/` directory

## Import Method 1: Via Keycloak Admin Console (Manual)

### Step 1: Access Keycloak Admin Console

1. Navigate to `https://keycloak.mylegion5pro.me/admin`
2. Login with admin credentials
3. Ensure you're in the **homelab** realm (top-left dropdown)

### Step 2: Import OAuth2 Proxy Client

1. Click **Clients** in left sidebar
2. Click **Import** button
3. Select file: `k8s/keycloak/oauth2-proxy-client.json`
4. Click **Import**
5. Review settings and click **Save**

### Step 3: Get Client Secret for OAuth2 Proxy

1. Go to **Clients** → Select **oauth2-proxy**
2. Click **Credentials** tab
3. Copy the **Client Secret** value
4. Save this for later (needed in K8s secret)

**Important**: You'll need this secret to update your K8s OAuth2 Proxy configuration:
```bash
kubectl get secret -n local-ai-system oauth2-proxy-secrets -o jsonpath='{.data.client-secret}' | base64 -d
```

### Step 4: Import Individual Service Clients

Repeat the import process for each service:

1. **n8n Client**
   - File: `k8s/keycloak/n8n-client.json`
   - Click **Import** → Review → **Save**
   - Get Client Secret from **Credentials** tab

2. **Flowise Client**
   - File: `k8s/keycloak/flowise-client.json`
   - Click **Import** → Review → **Save**
   - Get Client Secret from **Credentials** tab

3. **Neo4j Client**
   - File: `k8s/keycloak/neo4j-client.json`
   - Click **Import** → Review → **Save**
   - Get Client Secret from **Credentials** tab

4. **SearXNG Client**
   - File: `k8s/keycloak/searxng-client.json`
   - Click **Import** → Review → **Save**
   - Get Client Secret from **Credentials** tab

## Import Method 2: Via Keycloak API

### Using cURL to Import Clients

First, get an admin access token:

```bash
# Get access token for admin
ACCESS_TOKEN=$(curl -s -X POST \
  "https://keycloak.mylegion5pro.me/realms/master/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "client_id=admin-cli" \
  -d "username=admin" \
  -d "password=<admin-password>" \
  -d "grant_type=password" | jq -r '.access_token')

echo "Access Token: $ACCESS_TOKEN"
```

### Import OAuth2 Proxy Client via API

```bash
curl -X POST \
  "https://keycloak.mylegion5pro.me/admin/realms/homelab/clients" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d @k8s/keycloak/oauth2-proxy-client.json
```

### Import Service Clients via API

```bash
# n8n
curl -X POST \
  "https://keycloak.mylegion5pro.me/admin/realms/homelab/clients" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d @k8s/keycloak/n8n-client.json

# flowise
curl -X POST \
  "https://keycloak.mylegion5pro.me/admin/realms/homelab/clients" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d @k8s/keycloak/flowise-client.json

# neo4j
curl -X POST \
  "https://keycloak.mylegion5pro.me/admin/realms/homelab/clients" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d @k8s/keycloak/neo4j-client.json

# searxng
curl -X POST \
  "https://keycloak.mylegion5pro.me/admin/realms/homelab/clients" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d @k8s/keycloak/searxng-client.json
```

## OAuth2 Proxy Client Configuration

### Redirect URIs (Already Configured)

These redirect URIs are pre-configured in the JSON:

```
https://n8n.lupulup.com/oauth2/callback
https://flowise.lupulup.com/oauth2/callback
https://neo4j.lupulup.com/oauth2/callback
https://searxng.lupulup.com/oauth2/callback
https://keycloak.mylegion5pro.me/oauth2/callback
http://localhost:4180/oauth2/callback (for local testing)
```

### Web Origins (Already Configured)

```
https://n8n.lupulup.com
https://flowise.lupulup.com
https://neo4j.lupulup.com
https://searxng.lupulup.com
https://keycloak.mylegion5pro.me
http://localhost:4180 (for local testing)
```

### Protocol Mappers (Already Configured)

The oauth2-proxy client includes mappers for:
- `username` → `preferred_username` claim
- `email` → `email` claim
- `given_name` → `given_name` claim
- `family_name` → `family_name` claim
- `groups` → `groups` claim (from realm roles)
- `client_ip` → IP address in token

## Kubernetes Secret Update

After creating the oauth2-proxy client in Keycloak, update the K8s secret:

### Step 1: Get Client Secret from Keycloak

In Keycloak Admin Console:
1. Go to **Clients** → **oauth2-proxy**
2. Click **Credentials** tab
3. Copy the **Client Secret**

### Step 2: Update K8s Secret

```bash
# Create the plain secret (don't commit this!)
cat > /tmp/oauth2-proxy-secret.yaml <<'EOF'
apiVersion: v1
kind: Secret
metadata:
  name: oauth2-proxy-secrets
  namespace: local-ai-system
type: Opaque
stringData:
  client-id: "oauth2-proxy"
  client-secret: "PASTE_KEYCLOAK_CLIENT_SECRET_HERE"
  cookie-secret: "$(openssl rand -base64 32)"
EOF

# Generate cookie secret
COOKIE_SECRET=$(openssl rand -base64 32)
sed -i "s|PASTE_KEYCLOAK_CLIENT_SECRET_HERE|$KEYCLOAK_SECRET|" /tmp/oauth2-proxy-secret.yaml
sed -i "s|\$(openssl rand -base64 32)|$COOKIE_SECRET|" /tmp/oauth2-proxy-secret.yaml

# Apply the secret (if not using sealed secrets)
kubectl apply -f /tmp/oauth2-proxy-secret.yaml

# OR if using sealed secrets:
kubeseal -f /tmp/oauth2-proxy-secret.yaml -w k8s/apps/_common/oauth2-proxy-sealed-secret.yaml
kubectl apply -f k8s/apps/_common/oauth2-proxy-sealed-secret.yaml

# Clean up
rm /tmp/oauth2-proxy-secret.yaml
```

## Verify Client Configuration

### Check Clients in Keycloak

```bash
# Get all clients
curl -s -X GET \
  "https://keycloak.mylegion5pro.me/admin/realms/homelab/clients" \
  -H "Authorization: Bearer $ACCESS_TOKEN" | jq '.[] | {clientId, name}'

# Expected output should show:
# - oauth2-proxy
# - n8n
# - flowise
# - neo4j
# - searxng
```

### Check OAuth2 Proxy Logs

```bash
kubectl logs -n local-ai-system deployment/oauth2-proxy -f
```

Look for messages indicating successful Keycloak discovery:
```
provider=oidc
oidc_issuer_url=https://keycloak.mylegion5pro.me/realms/homelab
```

## Testing OAuth2 Flow

### Test 1: Redirect to Keycloak Login

```bash
# Should redirect to Keycloak login page
curl -v https://n8n.lupulup.com 2>&1 | grep -E "Location:|Set-Cookie"
```

Expected:
```
Location: https://keycloak.mylegion5pro.me/realms/homelab/protocol/openid-connect/auth?...
```

### Test 2: Login via Browser

1. Open `https://n8n.lupulup.com` in browser
2. You should be redirected to Keycloak login
3. Enter credentials:
   - Username: `admin`
   - Password: (your admin password)
4. You should be redirected back to n8n
5. Check if you're authenticated

### Test 3: Check OAuth2 Proxy Session

```bash
# Get OAuth2 Proxy session info
kubectl exec -n local-ai-system deployment/oauth2-proxy -- curl -s http://localhost:4180/info | jq .
```

## User Groups and Roles

### Create User Groups in Keycloak

1. Go to **Groups** in left sidebar
2. Click **New**
3. Create groups:
   - `admins` - Administrative access
   - `developers` - Developer access
   - `explorers` - Read-only access

### Assign Users to Groups

1. Go to **Users**
2. Select a user
3. Click **Groups** tab
4. Join groups as needed

### Map Groups to Token Claims

The `groups` mapper in oauth2-proxy client will automatically include group membership in the token:

```json
"groups": ["admins", "developers"]
```

## Troubleshooting

### Issue: "redirect_uri_mismatch" error

**Solution**: Verify redirect URIs in Keycloak:
1. Go to **Clients** → **oauth2-proxy**
2. Check **Valid Redirect URIs** match your domains
3. Ensure you have both the exact match and wildcard versions

### Issue: "invalid_client" error

**Solution**: Check client secret:
1. Go to **Clients** → **oauth2-proxy** → **Credentials**
2. Verify the secret in K8s matches Keycloak
3. Try regenerating the secret if still failing

### Issue: Token doesn't contain user info

**Solution**: Check protocol mappers:
1. Go to **Clients** → **oauth2-proxy** → **Mappers**
2. Verify all mappers are configured correctly
3. Check that mappers have `access.token.claim: true`

### Issue: "Access denied" after login

**Solution**: Check user roles/groups:
1. Verify user is in the correct group
2. Check if OAuth2 Proxy has role requirements configured
3. Check application logs for authorization errors

## Security Considerations

### Client Secret Security

- **Never commit** client secrets to Git
- Store secrets in Kubernetes secrets (sealed or encrypted)
- Rotate secrets periodically
- Use separate secrets for each environment (dev, staging, prod)

### Redirect URI Validation

The `oauth2-proxy` client uses strict redirect URI matching:
- Always use HTTPS in production
- Include all possible redirect URIs
- Use wildcard URIs carefully (security implications)

### Token Expiration

Default token expiration: **5 minutes** (short-lived)
Refresh token expiration: **30 days**

Configure in **Realm Settings** → **Tokens** if needed

### PKCE Support

All clients have PKCE enabled (S256 method):
- Protects against authorization code interception
- Recommended for all OAuth2 flows

## References

- [Keycloak Client Configuration](https://www.keycloak.org/docs/latest/server_admin/#_oidc_clients)
- [OAuth2 Proxy Configuration](https://oauth2-proxy.github.io/oauth2-proxy/)
- [OIDC Client Metadata](https://openid.net/specs/openid-connect-discovery-1_0.html)

## Next Steps

1. ✅ Import all 5 clients into Keycloak
2. ✅ Update K8s oauth2-proxy secret with client credentials
3. ✅ Verify OAuth2 flow works
4. ✅ Test login for each user group
5. Set up audit logging
6. Configure additional security policies
