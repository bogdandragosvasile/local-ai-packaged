# Keycloak User & Groups Setup - Step-by-Step Guide

This guide walks you through creating users, groups, and testing authentication with your Local AI Packaged services.

## Prerequisites

- Keycloak server running at: `https://keycloak.mylegion5pro.me`
- Homelab realm already created
- OAuth2 clients already configured (flowise, n8n, neo4j, searxng, oauth2-proxy)
- All 4 application services running and accessible

## Part 1: Access Keycloak Admin Console

### Step 1.1: Open Keycloak Admin Console

1. Open your web browser
2. Navigate to: `https://keycloak.mylegion5pro.me`
3. Click on **"Administration Console"** link
4. Log in with admin credentials (if prompted)

**Note**: Save the Keycloak admin password in a secure location

### Step 1.2: Navigate to Homelab Realm

1. In the top-left corner, you should see a dropdown with realm name
2. Click the dropdown and select **"homelab"** realm
3. You should now be in the homelab realm admin console

---

## Part 2: Create User Groups

Groups allow you to organize users and manage permissions collectively. We'll create three groups: admins, developers, and explorers.

### Step 2.1: Create "admins" Group

1. In left sidebar, click **"Groups"**
2. Click **"Create group"** button
3. Enter name: `admins`
4. Click **"Create"**
5. You should see the group created with path `/admins`

**Group Details for Admins:**
- Full access to all services
- Can manage workflows (n8n)
- Can manage flows (Flowise)
- Can access Neo4j admin functions
- Can configure search (SearXNG)

### Step 2.2: Create "developers" Group

1. Click **"Create group"** again
2. Enter name: `developers`
3. Click **"Create"**

**Group Details for Developers:**
- Access to all services
- Can create and modify workflows (n8n)
- Can create and modify flows (Flowise)
- Read-only access to Neo4j
- Can use search (SearXNG)

### Step 2.3: Create "explorers" Group

1. Click **"Create group"** again
2. Enter name: `explorers`
3. Click **"Create"**

**Group Details for Explorers:**
- Read-only access to services
- Can view workflows and flows (read-only)
- Can view Neo4j data (read-only)
- Can use search (SearXNG)

**Result**: You should now see 3 groups in the Groups list:
- `/admins`
- `/developers`
- `/explorers`

---

## Part 3: Create User Accounts

We'll create test users and assign them to different groups.

### Step 3.1: Create First User (Admin)

1. In left sidebar, click **"Users"**
2. Click **"Create new user"** button
3. Fill in the form:
   - **Username**: `admin` (or your preferred name)
   - **Email**: `admin@example.com`
   - **First Name**: `Admin`
   - **Last Name**: `User`
   - **Email Verified**: Toggle ON
   - **Enabled**: Toggle ON
4. Click **"Create"**

### Step 3.2: Set Password for Admin User

1. You'll be redirected to the user details page
2. Click on the **"Credentials"** tab
3. Click **"Set password"** button
4. Enter a password (e.g., `Admin@123!`)
5. **Temporary**: Toggle OFF (so they don't have to change it on first login)
6. Click **"Set Password"** to confirm
7. You'll see "Password updated" message

### Step 3.3: Assign Admin User to "admins" Group

1. Click on the **"Groups"** tab (on the same user page)
2. In the "Available Groups" section, find and click **"admins"**
3. Click **"Join"** button
4. You should see "admins" now appears in the "Groups" section at top

### Step 3.4: Create Second User (Developer)

Repeat steps 3.1-3.3 but:
- **Username**: `developer` (or `dev-user`)
- **Email**: `developer@example.com`
- **First Name**: `Developer`
- **Last Name**: `User`
- **Password**: `Dev@123!`
- **Assign to group**: `developers`

### Step 3.5: Create Third User (Explorer)

Repeat steps 3.1-3.3 but:
- **Username**: `explorer`
- **Email**: `explorer@example.com`
- **First Name**: `Explorer`
- **Last Name**: `User`
- **Password**: `Explorer@123!`
- **Assign to group**: `explorers`

**Result**: You should have 3 users created:
- `admin` (in admins group)
- `developer` (in developers group)
- `explorer` (in explorers group)

---

## Part 4: Add Group Membership Claims (Optional but Recommended)

This allows applications to see which groups a user belongs to.

### Step 4.1: Add Groups to Token Claims

1. In left sidebar, click **"Client Scopes"**
2. Click on **"roles"** scope
3. Click on **"Scope"** tab
4. Under "Assigned Roles", verify these are present:
   - `realm-management > manage-users`
   - `realm-management > manage-account`
5. Click on **"Mappers"** tab
6. Click **"Add mapper"** → **"By configuration"**
7. Select mapper type: **"Group Membership"**
8. Fill in:
   - **Name**: `groups`
   - **Token Claim Name**: `groups`
   - **Add to ID token**: ON
   - **Add to access token**: ON
   - **Add to userinfo**: ON
9. Click **"Save"**

---

## Part 5: Verify Keycloak Configuration

### Step 5.1: Verify OAuth2 Clients

1. In left sidebar, click **"Clients"**
2. You should see these clients listed:
   - flowise
   - n8n
   - neo4j
   - oauth2-proxy
   - searxng

3. For each client, click and verify:
   - **Valid Redirect URIs** is set correctly
   - **Web Origins** is set correctly
   - **PKCE Code Challenge Method** is set to `S256`

### Step 5.2: Check Realm Settings

1. Click **"Realm Settings"** in left sidebar
2. Verify:
   - **Realm name**: `homelab`
   - **Enabled**: Toggle is ON
   - **User-Managed Access**: Check if needed for your use case

---

## Part 6: Test User Login with Each Service

Now let's test that users can actually authenticate with the services.

### Step 6.1: Test Flowise Login

1. Open new browser window/tab (or clear cookies)
2. Navigate to: `https://flowise.lupulup.com`
3. You should see Flowise interface
4. Look for login option (may be built-in or redirect to Keycloak)
5. If Keycloak login appears:
   - Enter username: `admin`
   - Enter password: `Admin@123!`
   - Click **"Sign In"**
6. You should be redirected back to Flowise logged in
7. Try again with `developer` and `explorer` users

**Expected behavior**:
- ✅ Admin can log in
- ✅ Developer can log in
- ✅ Explorer can log in

### Step 6.2: Test n8n Login

1. Open new browser window/tab (clear cookies)
2. Navigate to: `https://n8n.lupulup.com`
3. Look for n8n login screen
4. Try logging in with:
   - Username: `admin` (or your n8n admin if already set up)
   - Password: (n8n password, not Keycloak)
5. If n8n doesn't show Keycloak integration yet, that's normal
   - n8n OIDC plugin requires additional configuration

**Note**: n8n uses internal user management by default. To integrate with Keycloak, you'll need:
- Install n8n OIDC plugin
- Configure OIDC provider settings in n8n
- Restart n8n

### Step 6.3: Test Neo4j Browser

1. Open new browser window/tab (clear cookies)
2. Navigate to: `https://neo4j.lupulup.com`
3. Neo4j Browser login screen should appear
4. Default credentials:
   - Username: `neo4j`
   - Password: `neo4j_secure_123` (from secret)
5. Click **"Connect"**
6. You should see Neo4j Browser interface

**Note**: Neo4j uses its own authentication. To integrate with Keycloak:
- Use Neo4j's LDAP or SAML authentication plugins
- Configure connector to Keycloak
- Requires Neo4j Enterprise or additional plugins

### Step 6.4: Test SearXNG

1. Open new browser window/tab
2. Navigate to: `https://searxng.lupulup.com`
3. Public search interface should appear immediately (no login)
4. Try a search query
5. Results should appear

**Note**: SearXNG is public by default. To add authentication:
- Use OAuth2-Proxy in front (but this caused issues earlier)
- Or use SearXNG's built-in auth plugins

---

## Part 7: Test Direct Keycloak Authentication

This verifies that Keycloak and OAuth2 clients are working correctly.

### Step 7.1: Get OAuth2 Token (Advanced Test)

If you want to verify the OAuth2 flow is working:

```bash
# Get authorization code
curl -L "https://keycloak.mylegion5pro.me/realms/homelab/protocol/openid-connect/auth?response_type=code&client_id=flowise&redirect_uri=https://flowise.lupulup.com/auth/callback&scope=openid%20profile%20email"

# Exchange code for token (requires client secret)
curl -X POST \
  https://keycloak.mylegion5pro.me/realms/homelab/protocol/openid-connect/token \
  -d "grant_type=password" \
  -d "client_id=flowise" \
  -d "client_secret=Rxw3PxcTggcYa2oN9vUDx5MSWCL0PAGQ" \
  -d "username=admin" \
  -d "password=Admin@123!" \
  -d "scope=openid profile email"

# Response should include: access_token, refresh_token, id_token
```

---

## Part 8: Configure Keycloak User Attributes (Optional)

Add custom attributes to users for application-specific features.

### Step 8.1: Add User Attributes

1. Go to **"Users"** in left sidebar
2. Click on a user (e.g., `admin`)
3. Scroll to **"Attributes"** section
4. Click **"Add attribute"** button
5. Add custom attributes:
   - **Key**: `department` | **Value**: `Engineering`
   - **Key**: `role` | **Value**: `admin`
   - **Key**: `team` | **Value**: `DevOps`
6. Click **"Save"** or **"Add"** for each

These attributes can be:
- Included in JWT tokens
- Used by applications for role-based access control
- Mapped to application-specific permissions

---

## Part 9: Enable Keycloak OIDC in n8n (Optional Advanced)

If you want to fully integrate n8n with Keycloak:

### Step 9.1: Install n8n OIDC Plugin

```bash
# SSH into n8n pod
kubectl exec -it -n local-ai-n8n deployment/n8n -- /bin/sh

# Install OIDC plugin
npm install --prefix /usr/local/lib/node_modules/n8n @n8n/nodes-base-oidc

# Exit pod
exit

# Restart n8n
kubectl rollout restart deployment/n8n -n local-ai-n8n
```

### Step 9.2: Configure n8n OIDC

1. Access n8n at `https://n8n.lupulup.com`
2. Go to **Settings** → **Authentication**
3. Enable **"OIDC"** if available
4. Configure:
   - **Authority**: `https://keycloak.mylegion5pro.me/realms/homelab`
   - **Client ID**: `n8n`
   - **Client Secret**: `TN7cydhZ8S6FLYtRNw9jcuOoIMb6wnyW`
   - **Redirect URI**: `https://n8n.lupulup.com/auth/callback`
   - **Scopes**: `openid profile email`
5. Save changes
6. Restart n8n

---

## Part 10: Troubleshooting Common Issues

### Issue: "Invalid redirect URI"

**Cause**: Redirect URI in Keycloak client doesn't match browser request

**Solution**:
1. Go to Keycloak → Clients → (service client)
2. Check **"Valid Redirect URIs"**
3. Make sure exact URL is listed (e.g., `https://flowise.lupulup.com/auth/callback`)
4. Save changes

### Issue: "Untrusted certificate" when accessing Keycloak

**Cause**: Self-signed or untrusted TLS certificate

**Solution**:
1. Verify certificate is issued by Let's Encrypt (via cert-manager)
2. Check: `kubectl get certificate -A`
3. If certificate is invalid, regenerate:
   ```bash
   kubectl delete certificate keycloak-tls -n keycloak
   kubectl apply -f k8s/apps/keycloak/certificate.yaml
   ```

### Issue: Users can't log in with correct credentials

**Cause**: User account disabled or password not set

**Solution**:
1. Go to Keycloak → Users → (username)
2. Check **"Enabled"** toggle is ON
3. Check **"Credentials"** tab has password set
4. Try resetting password:
   - Click **"Reset password"**
   - Set new password
   - Click **"Set password"**

### Issue: Groups not appearing in token

**Cause**: Group mapper not configured

**Solution**:
1. Go to Keycloak → Client Scopes → roles
2. Click **"Mappers"** tab
3. Verify "Group Membership" mapper exists
4. Check all "Add to" toggles are ON
5. Restart service pods

---

## Summary Checklist

- [ ] Accessed Keycloak Admin Console
- [ ] Selected "homelab" realm
- [ ] Created 3 groups: admins, developers, explorers
- [ ] Created 3 users: admin, developer, explorer
- [ ] Set passwords for all users
- [ ] Assigned users to appropriate groups
- [ ] Verified OAuth2 clients exist in Keycloak
- [ ] Tested Flowise login with all 3 users
- [ ] Tested n8n access
- [ ] Tested Neo4j Browser login
- [ ] Tested SearXNG search
- [ ] (Optional) Installed n8n OIDC plugin and configured integration

---

## Next Steps After Setup

1. **Monitor Authentication Events**:
   ```bash
   kubectl logs -n keycloak deployment/keycloak -f | grep -i "user\|login\|auth"
   ```

2. **Configure Application-Specific Permissions**:
   - Set up role-based access control (RBAC) in each service
   - Map Keycloak groups to application roles

3. **Enable MFA (Multi-Factor Authentication)**:
   - Go to Keycloak → Realm Settings → Security Defenses
   - Configure OTP or WebAuthn

4. **Set Up User Onboarding**:
   - Create registration form
   - Set email verification requirements
   - Configure self-service password reset

5. **Monitor Usage**:
   - Check Keycloak admin console for login activity
   - Review application logs for auth issues

---

## Reference: Service Keycloak Integration Status

| Service | Status | Auth Method | Notes |
|---------|--------|------------|-------|
| **Flowise** | ✅ Ready | OIDC Environment Variables | Can authenticate now |
| **n8n** | ⚠️ Partial | Internal + Optional OIDC | Needs OIDC plugin for full integration |
| **Neo4j** | ⚠️ Partial | Neo4j Built-in | Needs LDAP/SAML plugin for Keycloak |
| **SearXNG** | ❌ Not Protected | None | Public access - no auth required |
| **OAuth2-Proxy** | ✅ Ready | OIDC | Configured but disabled in ingress |

---

## Support & Further Documentation

- **Keycloak Official Docs**: https://www.keycloak.org/docs/latest/
- **n8n OIDC**: https://docs.n8n.io/hosting/authentication/
- **Neo4j Authentication**: https://neo4j.com/docs/operations-manual/current/authentication-authorization/
- **Local AI Packaged Docs**: See `k8s/docs/APPLICATION-KEYCLOAK-INTEGRATION.md`
