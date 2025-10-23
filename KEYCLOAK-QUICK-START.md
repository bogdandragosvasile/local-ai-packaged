# Keycloak Quick Start - TL;DR Version

**Fast-track setup for users, groups, and testing.**

## 5-Minute Setup

### 1. Access Keycloak
- URL: `https://keycloak.mylegion5pro.me`
- Click "Administration Console"
- Select "homelab" realm (top-left dropdown)

### 2. Create Groups (1 minute)
```
Groups → Create group
├─ admins
├─ developers
└─ explorers
```

### 3. Create Users (2 minutes)
```
Users → Create new user

Admin User:
├─ Username: admin
├─ Email: admin@example.com
├─ Credentials tab → Set password: Admin@123!
└─ Groups tab → Join: admins

Developer User:
├─ Username: developer
├─ Email: developer@example.com
├─ Credentials tab → Set password: Dev@123!
└─ Groups tab → Join: developers

Explorer User:
├─ Username: explorer
├─ Email: explorer@example.com
├─ Credentials tab → Set password: Explorer@123!
└─ Groups tab → Join: explorers
```

### 4. Test Services (2 minutes)
- Flowise: `https://flowise.lupulup.com` → Try logging in with admin/Admin@123!
- n8n: `https://n8n.lupulup.com` → Check if accessible
- Neo4j: `https://neo4j.lupulup.com` → Login with neo4j/neo4j_secure_123
- SearXNG: `https://searxng.lupulup.com` → Public search (no auth)

---

## Keycloak Credentials

| Item | Value |
|------|-------|
| **Keycloak URL** | https://keycloak.mylegion5pro.me |
| **Realm** | homelab |
| **Flowise Client Secret** | Rxw3PxcTggcYa2oN9vUDx5MSWCL0PAGQ |
| **n8n Client Secret** | TN7cydhZ8S6FLYtRNw9jcuOoIMb6wnyW |
| **Neo4j Default User** | neo4j |
| **Neo4j Default Password** | neo4j_secure_123 |

---

## Useful Keycloak URLs

```
Admin Console:     https://keycloak.mylegion5pro.me/admin
Homelab Realm:     https://keycloak.mylegion5pro.me/realms/homelab
OIDC Discovery:    https://keycloak.mylegion5pro.me/realms/homelab/.well-known/openid-configuration
Token Endpoint:    https://keycloak.mylegion5pro.me/realms/homelab/protocol/openid-connect/token
```

---

## Service Credentials

```
Flowise:
├─ URL: https://flowise.lupulup.com
├─ Default user: admin/admin (internal)
└─ Keycloak client: flowise

n8n:
├─ URL: https://n8n.lupulup.com
├─ Default user: admin (internal)
└─ Keycloak client: n8n (optional)

Neo4j Browser:
├─ URL: https://neo4j.lupulup.com
├─ Default user: neo4j/neo4j_secure_123
└─ Keycloak client: neo4j (optional)

SearXNG:
├─ URL: https://searxng.lupulup.com
├─ Access: Public (no auth)
└─ Keycloak client: searxng (unused)
```

---

## Test Keycloak Token (curl)

```bash
# Get token for admin user
curl -X POST \
  https://keycloak.mylegion5pro.me/realms/homelab/protocol/openid-connect/token \
  -d "grant_type=password" \
  -d "client_id=flowise" \
  -d "client_secret=Rxw3PxcTggcYa2oN9vUDx5MSWCL0PAGQ" \
  -d "username=admin" \
  -d "password=Admin@123!" \
  -d "scope=openid profile email" \
  -H "Content-Type: application/x-www-form-urlencoded"

# Response will include: access_token, refresh_token, id_token
```

---

## Common Tasks

### Reset User Password
1. Users → Select user → Credentials
2. Click "Reset password"
3. Enter new password
4. Toggle "Temporary" to OFF
5. Click "Set password"

### Change User Group
1. Users → Select user → Groups
2. Available Groups → Select group → Join
3. Or remove from current group (click X)

### Delete User
1. Users → Select user
2. Click "Delete" button (top-right)
3. Confirm deletion

### Verify OAuth Client Configuration
1. Clients → Select client (e.g., flowise)
2. Check:
   - ✅ Valid Redirect URIs: `https://flowise.lupulup.com/auth/callback`
   - ✅ Web Origins: `https://flowise.lupulup.com`
   - ✅ PKCE Code Challenge: `S256`

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| Can't access Keycloak | Check DNS: `nslookup keycloak.mylegion5pro.me` |
| Certificate error | Wait for cert-manager: `kubectl get certificate -n keycloak` |
| User can't log in | Check "Enabled" toggle and password in Credentials tab |
| Token error | Verify client secret matches in Keycloak vs config |
| Groups not in token | Go to Client Scopes → roles → Mappers → verify "Group Membership" |

---

## What's Next?

After creating users and groups:

1. **Optional**: Configure n8n OIDC plugin for full Keycloak integration
2. **Optional**: Set up Neo4j LDAP connector for Keycloak auth
3. **Recommended**: Configure group-based access control in applications
4. **Monitor**: Check Keycloak logs for authentication events

---

See `KEYCLOAK-USER-SETUP-GUIDE.md` for detailed step-by-step instructions.
