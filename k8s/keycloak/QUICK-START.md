# Keycloak Clients - Quick Start

## Files Created

All OAuth2 client configuration files are in `k8s/keycloak/`:

```
k8s/keycloak/
├── oauth2-proxy-client.json      (Central SSO gateway - REQUIRED)
├── n8n-client.json               (n8n application)
├── flowise-client.json           (Flowise application)
├── neo4j-client.json             (Neo4j application)
├── searxng-client.json           (SearXNG application)
├── KEYCLOAK-CLIENT-IMPORT.md     (Detailed import guide)
└── QUICK-START.md                (This file)
```

## Fast Import (Manual - 5 minutes)

### 1. Open Keycloak Admin Console
```
https://keycloak.mylegion5pro.me/admin
```

Login with admin credentials.

### 2. Import oauth2-proxy Client (IMPORTANT)

1. Click **Clients** in sidebar
2. Click **Import** button
3. Select: `k8s/keycloak/oauth2-proxy-client.json`
4. Click **Import** → **Save**

### 3. Get oauth2-proxy Client Secret

1. Go to **Clients** → **oauth2-proxy**
2. Click **Credentials** tab
3. **Copy** the **Client Secret** value
4. **Save this value** - you'll need it for K8s

### 4. Import Individual Service Clients (Optional)

If you want separate clients per service, repeat for each:
- `n8n-client.json`
- `flowise-client.json`
- `neo4j-client.json`
- `searxng-client.json`

Get their Client Secrets too.

## Automated Import (via API)

### Prerequisites

```bash
# Get admin access token
KEYCLOAK_URL="https://keycloak.mylegion5pro.me"
ADMIN_PASSWORD="your-admin-password"  # Change this!

ACCESS_TOKEN=$(curl -s -X POST \
  "$KEYCLOAK_URL/realms/master/protocol/openid-connect/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "client_id=admin-cli" \
  -d "username=admin" \
  -d "password=$ADMIN_PASSWORD" \
  -d "grant_type=password" | jq -r '.access_token')

echo "Token: $ACCESS_TOKEN"
```

### Import All Clients

```bash
cd k8s/keycloak

for client in oauth2-proxy-client.json n8n-client.json flowise-client.json neo4j-client.json searxng-client.json; do
  echo "Importing $client..."
  curl -X POST \
    "$KEYCLOAK_URL/admin/realms/homelab/clients" \
    -H "Authorization: Bearer $ACCESS_TOKEN" \
    -H "Content-Type: application/json" \
    -d @$client
  echo "✓ $client imported"
done
```

### Get Client Secrets (via API)

```bash
# Get oauth2-proxy client ID
CLIENT_ID=$(curl -s -X GET \
  "$KEYCLOAK_URL/admin/realms/homelab/clients?clientId=oauth2-proxy" \
  -H "Authorization: Bearer $ACCESS_TOKEN" | jq -r '.[0].id')

# Get client secret
curl -s -X GET \
  "$KEYCLOAK_URL/admin/realms/homelab/clients/$CLIENT_ID/client-secret" \
  -H "Authorization: Bearer $ACCESS_TOKEN" | jq -r '.value'
```

## Update Kubernetes Secret

Once you have the oauth2-proxy client secret from Keycloak:

```bash
# Set these values
KEYCLOAK_SECRET="paste-from-keycloak-here"
COOKIE_SECRET=$(openssl rand -base64 32)

# Create secret file
cat > /tmp/oauth2-proxy-secret.yaml <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: oauth2-proxy-secrets
  namespace: local-ai-system
type: Opaque
stringData:
  client-id: "oauth2-proxy"
  client-secret: "$KEYCLOAK_SECRET"
  cookie-secret: "$COOKIE_SECRET"
EOF

# Apply to cluster
kubectl apply -f /tmp/oauth2-proxy-secret.yaml

# Verify
kubectl get secret -n local-ai-system oauth2-proxy-secrets

# Restart OAuth2 Proxy to pick up new secret
kubectl rollout restart deployment/oauth2-proxy -n local-ai-system
```

## Verify Setup

### Check Clients Imported

```bash
curl -s -X GET \
  "$KEYCLOAK_URL/admin/realms/homelab/clients" \
  -H "Authorization: Bearer $ACCESS_TOKEN" | jq '.[] | {clientId, name}'
```

Expected:
```json
{
  "clientId": "oauth2-proxy",
  "name": "OAuth2 Proxy - Central SSO Gateway"
}
{
  "clientId": "n8n",
  "name": "n8n - Workflow Automation"
}
...
```

### Test OAuth2 Proxy

```bash
# Check OAuth2 Proxy status
kubectl get deployment -n local-ai-system oauth2-proxy

# View logs
kubectl logs -n local-ai-system deployment/oauth2-proxy | tail -20

# Should see:
# "provider=oidc"
# "oidc_issuer_url=https://keycloak.mylegion5pro.me/realms/homelab"
```

### Test Service Access

```bash
# Try accessing a service
curl -v https://n8n.lupulup.com 2>&1 | grep -E "Location:|Set-Cookie"

# Should redirect to Keycloak:
# Location: https://keycloak.mylegion5pro.me/realms/homelab/protocol/openid-connect/auth?...
```

## Troubleshooting

### "Client already exists" error

If importing fails because client exists:

```bash
# Get client UUID
CLIENT_ID=$(curl -s -X GET \
  "$KEYCLOAK_URL/admin/realms/homelab/clients?clientId=oauth2-proxy" \
  -H "Authorization: Bearer $ACCESS_TOKEN" | jq -r '.[0].id')

# Delete old client
curl -X DELETE \
  "$KEYCLOAK_URL/admin/realms/homelab/clients/$CLIENT_ID" \
  -H "Authorization: Bearer $ACCESS_TOKEN"

# Re-import
curl -X POST \
  "$KEYCLOAK_URL/admin/realms/homelab/clients" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d @oauth2-proxy-client.json
```

### "redirect_uri_mismatch" in browser

Means redirect URIs don't match. Check:

1. In Keycloak: **Clients** → **oauth2-proxy** → **Valid Redirect URIs**
2. Should include all 4 services:
   ```
   https://n8n.lupulup.com/oauth2/callback
   https://flowise.lupulup.com/oauth2/callback
   https://neo4j.lupulup.com/oauth2/callback
   https://searxng.lupulup.com/oauth2/callback
   ```

### OAuth2 Proxy stuck in CrashLoopBackOff

Check the secret is correct:

```bash
# Verify secret
kubectl get secret -n local-ai-system oauth2-proxy-secrets -o yaml

# Check logs
kubectl logs -n local-ai-system deployment/oauth2-proxy

# Look for: "invalid_client", "invalid client", "not found"
```

## Next Steps

1. ✅ Import clients into Keycloak
2. ✅ Update K8s oauth2-proxy secret
3. ✅ Restart OAuth2 Proxy
4. ✅ Test login flow via browser
5. Create user groups in Keycloak (optional)
6. Assign users to groups (optional)

See `KEYCLOAK-CLIENT-IMPORT.md` for detailed instructions.
