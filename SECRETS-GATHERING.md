# Secrets Gathering & Encryption Guide

## 🔐 **Phase 2: Secrets Preparation**

Before we can deploy, you need to provide credentials and generate secrets. This document guides you through the process.

---

## **Step 1: Gather Required Credentials**

You'll need to provide these credentials. If you don't have them, generate new ones.

### **Keycloak**
- [ ] **Keycloak Admin Username**: _______________
- [ ] **Keycloak Admin Password**: _______________
  - Access: https://keycloak.mylegion5pro.me
  - Purpose: To create OAuth2 clients

### **Database Passwords** (Generate new random passwords)

- [ ] **PostgreSQL Root Password**: _______________
  - Minimum: 16 characters, mixed case, numbers, special chars
  - Example: `SecurePostgres2025!`
  - Generate: `openssl rand -base64 32`

- [ ] **Neo4j Admin Password**: _______________
  - Minimum: 16 characters, mixed case, numbers, special chars
  - Example: `SecureNeo4j2025!`
  - Generate: `openssl rand -base64 32`

---

## **Step 2: Generate Encryption Keys**

Run these commands to generate required keys:

```bash
# n8n Encryption Key (32 bytes hex)
openssl rand -hex 32
# Example output: a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6

# n8n JWT Secret (base64)
openssl rand -base64 32
# Example output: aB12cD34eF56gH78iJ90kL12mN34oP56

# n8n JWT Refresh Secret (base64 - different from JWT Secret)
openssl rand -base64 32
# Example output: xY98zW76vU54tS32rQ10pO98nM76lK54

# Qdrant API Key (any random string)
openssl rand -base64 32
# Example output: qdrant-key-1a2b3c4d5e6f7g8h

# OAuth2 Cookie Secret (32 bytes base64)
openssl rand -base64 32
# Example output: cO00kI99eE88sS77eC66rR55eT44aA33

# Flowise Admin Password
openssl rand -base64 16
# Example output: FlowyAdmin2025!

# Flowise API Key
openssl rand -base64 32
# Example output: flowise-key-xyz123abc456
```

---

## **Step 3: Fill in Credentials Below**

### **PostgreSQL Secrets**
```
DB_POSTGRESDB_PASSWORD = _______________
```

### **Neo4j Secrets**
```
NEO4J_PASSWORD = _______________
```

### **n8n Secrets**
```
N8N_ENCRYPTION_KEY = _______________
(must be 32 bytes hex)

N8N_USER_MANAGEMENT_JWT_SECRET = _______________
(base64 encoded)

N8N_USER_MANAGEMENT_JWT_REFRESH_SECRET = _______________
(base64 encoded, different from JWT_SECRET)
```

### **Qdrant Secrets**
```
QDRANT_API_KEY = _______________
```

### **Flowise Secrets**
```
FLOWISE_PASSWORD = _______________

FLOWISE_APIKEY = _______________
```

### **OAuth2 Proxy Secrets**
```
OAUTH2_CLIENT_SECRET = _______________
(Get from Keycloak - we'll do this in next step)

OAUTH2_COOKIE_SECRET = _______________
(base64 encoded)
```

---

## **Step 4: Create Keycloak OAuth2 Client**

Before we can encrypt secrets, we need the Keycloak OAuth2 client secret.

### **Manual Setup (via Keycloak Admin Console)**

1. Access: https://keycloak.mylegion5pro.me
2. Login with admin credentials
3. Go to: **Clients** → **Create**
4. **Client ID**: `oauth2-proxy`
5. **Client Protocol**: `openid-connect`
6. Click **Save**
7. Configure client:
   - **Access Type**: `confidential`
   - **Standard Flow Enabled**: ON
   - **Valid Redirect URIs**:
     - `https://n8n.lupulup.com/oauth2/callback`
     - `https://flowise.lupulup.com/oauth2/callback`
     - `https://neo4j.lupulup.com/oauth2/callback`
     - `https://searxng.lupulup.com/oauth2/callback`
   - **Web Origins**:
     - `https://n8n.lupulup.com`
     - `https://flowise.lupulup.com`
     - `https://neo4j.lupulup.com`
     - `https://searxng.lupulup.com`
8. Click **Save**
9. Go to **Credentials** tab
10. Copy the **Client Secret**

### **Client Secret**
```
OAUTH2_CLIENT_SECRET = _______________
```

---

## **Step 5: Prepare Secret Files**

Once you have all credentials, we'll create the sealed secrets. Here's what we'll do:

1. Create unencrypted secret files with your credentials
2. Encrypt each with `kubeseal`
3. Commit only the encrypted versions to Git
4. Delete the unencrypted files

### **Services Requiring Secrets**

- [ ] n8n
- [ ] Flowise
- [ ] PostgreSQL
- [ ] Neo4j
- [ ] Qdrant
- [ ] OAuth2 Proxy

---

## **Ingress IP Reminder**

**IMPORTANT**: Save this for Nginx Proxy Manager configuration:

```
Kubernetes Ingress IP: 192.168.1.22
```

---

## **Next: Automated Encryption**

Once you provide all credentials above, I'll:

1. Create secret files for each service
2. Encrypt with sealed-secrets
3. Commit encrypted versions to Git
4. Deploy encrypted secrets to cluster
5. Begin service deployment

---

## **Ready When You Are!**

Please provide:
1. All credentials listed in Step 1
2. All generated keys from Step 2
3. Keycloak OAuth2 client secret from Step 4

Then let me know and I'll proceed with encryption and deployment!
