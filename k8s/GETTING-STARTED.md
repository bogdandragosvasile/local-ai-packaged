# Getting Started with Local AI Kubernetes Deployment

Welcome! This guide will help you get the Local AI Package running on your Talos Kubernetes cluster with ArgoCD and Keycloak SSO integration.

## What You're Getting

A complete production-ready deployment of:
- **n8n** - Low-code workflow automation
- **Flowise** - AI agent builder
- **Neo4j** - Knowledge graph database
- **Qdrant** - Vector database for RAG
- **PostgreSQL** - Primary database
- **Redis** - Caching and session store
- **SearXNG** - Privacy-focused search engine
- **OAuth2 Proxy** - Keycloak SSO integration

All deployed via **ArgoCD** with GitOps principles, protected by **Keycloak** authentication, and exposed through **Nginx Proxy Manager**.

## 5-Minute Quick Start

### Prerequisites
```bash
# You need:
# 1. Working Talos Kubernetes cluster
# 2. ArgoCD installed and accessible
# 3. Keycloak running with homelab realm
# 4. Nginx Proxy Manager with HA setup
# 5. kubectl configured
```

### Deploy Everything

```bash
# 1. Clone the repository
git clone https://github.com/your-username/local-ai-packaged.git
cd local-ai-packaged

# 2. Make script executable
chmod +x k8s/scripts/quick-start.sh

# 3. Run quick start
./k8s/scripts/quick-start.sh

# 4. Follow the prompts and next steps
```

That's it! The script will:
- ✅ Verify your Kubernetes cluster
- ✅ Create necessary namespaces
- ✅ Deploy supporting services (Redis, OAuth2 Proxy)
- ✅ Deploy data layer (PostgreSQL, Qdrant, Neo4j)
- ✅ Deploy applications via ArgoCD
- ✅ Create Ingress endpoints

## Step-by-Step Manual Setup

If you prefer to deploy manually, follow this sequence:

### Step 1: Verify Prerequisites (5 minutes)

```bash
# Check cluster health
kubectl get nodes                # All should be Ready
kubectl get pods -n argocd       # ArgoCD should be running
kubectl get pods -n cert-manager # cert-manager should be running
kubectl get pods -n ingress-nginx # Nginx Ingress should be running

# Get Kubernetes Ingress IP (needed for Nginx Proxy Manager later)
kubectl get svc -n ingress-nginx ingress-nginx-controller
# Note the EXTERNAL-IP (e.g., 192.168.1.30)
```

### Step 2: Create Namespaces (1 minute)

```bash
kubectl apply -f k8s/apps/_common/namespace.yaml

# Verify
kubectl get ns | grep local-ai
# Should see: local-ai-system, local-ai-n8n, local-ai-flowise, local-ai-data, local-ai-search
```

### Step 3: Prepare Sealed Secrets (10 minutes)

This is the most important step for security.

**Important**: Never commit unencrypted secrets to Git!

```bash
# 1. Edit secret files with your actual values
vi k8s/apps/n8n/secret.yaml
vi k8s/apps/postgres/secret.yaml
vi k8s/apps/neo4j/secret.yaml
vi k8s/apps/qdrant/secret.yaml
vi k8s/apps/_common/oauth2-proxy-secrets.yaml
vi k8s/apps/flowise/secret.yaml

# 2. Encrypt each secret
kubeseal -f k8s/apps/n8n/secret.yaml -w k8s/apps/n8n/secret-sealed.yaml
kubeseal -f k8s/apps/postgres/secret.yaml -w k8s/apps/postgres/secret-sealed.yaml
kubeseal -f k8s/apps/neo4j/secret.yaml -w k8s/apps/neo4j/secret-sealed.yaml
kubeseal -f k8s/apps/qdrant/secret.yaml -w k8s/apps/qdrant/secret-sealed.yaml
kubeseal -f k8s/apps/_common/oauth2-proxy-secrets.yaml -w k8s/apps/_common/oauth2-proxy-sealed-secret.yaml

# 3. Verify sealed secrets
ls -la k8s/apps/*/secret-sealed.yaml
ls -la k8s/apps/_common/*sealed*.yaml

# 4. Add unencrypted secrets to .gitignore
echo "*/secret.yaml" >> .gitignore
echo "!*/secret-sealed.yaml" >> .gitignore

# 5. Commit sealed secrets to Git
git add k8s/
git commit -m "Add encrypted secrets for all services"
git push origin main
```

### Step 4: Deploy Supporting Services (5 minutes)

```bash
# Deploy Redis (caching and session store)
kubectl apply -f k8s/apps/redis/deployment.yaml

# Verify Redis
kubectl get pods -n local-ai-system -l app=redis -w
# Wait for READY: 1/1

# Deploy OAuth2 Proxy (Keycloak SSO gateway)
kubectl apply -f k8s/apps/_common/oauth2-proxy-base.yaml

# Verify OAuth2 Proxy
kubectl get pods -n local-ai-system -l app=oauth2-proxy -w
# Wait for READY: 2/2
```

### Step 5: Deploy Data Layer (15 minutes)

Data layer services may take a few minutes to start due to volume initialization.

```bash
# Deploy PostgreSQL
kubectl apply -f k8s/apps/postgres/statefulset.yaml
kubectl get pods -n local-ai-data -l app=postgres -w
# Wait for READY: 1/1 (may take 3-5 minutes)

# Deploy Qdrant
kubectl apply -f k8s/apps/qdrant/statefulset.yaml
kubectl get pods -n local-ai-data -l app=qdrant -w
# Wait for READY: 1/1

# Deploy Neo4j
kubectl apply -f k8s/apps/neo4j/statefulset.yaml
kubectl get pods -n local-ai-data -l app=neo4j -w
# Wait for READY: 1/1 (may take 3-5 minutes)
```

### Step 6: Deploy Applications (10 minutes)

```bash
# Deploy n8n
kubectl apply -k k8s/apps/n8n/
kubectl get pods -n local-ai-n8n -w

# Deploy Flowise
kubectl apply -f k8s/apps/flowise/deployment.yaml
kubectl get pods -n local-ai-flowise -w

# Deploy SearXNG
kubectl apply -f k8s/apps/searxng/deployment.yaml
kubectl get pods -n local-ai-search -w

# All pods should reach READY: 1/1 status
```

### Step 7: Verify Ingress & Certificates (5 minutes)

```bash
# Check Ingress endpoints
kubectl get ingress -A | grep local-ai

# Check certificate status (should be READY)
kubectl get certificate -A | grep local-ai

# Check issued certificates
kubectl get secret -A | grep tls | grep -E "(n8n|flowise|neo4j|searxng)"
```

### Step 8: Configure Keycloak (10 minutes)

Follow detailed guide: `k8s/docs/KEYCLOAK-SETUP.md`

Quick summary:
```bash
# 1. Create OAuth2 client in Keycloak:
#    - Client ID: oauth2-proxy
#    - Valid Redirect URIs: https://n8n.lupulup.com/oauth2/callback (and all others)
#    - Copy Client Secret

# 2. Get the sealed secret public key
kubectl get secret -n kube-system sealed-secrets-key -o json | \
  jq -r '.data."tls.crt"' | base64 -d > /tmp/sealed-secrets-pub.crt

# 3. Create encrypted secret with client secret
cat > /tmp/oauth2-secret.yaml <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: oauth2-proxy-secrets
  namespace: local-ai-system
stringData:
  client-id: "oauth2-proxy"
  client-secret: "<paste-keycloak-secret>"
  cookie-secret: "$(openssl rand -base64 32)"
EOF

# 4. Seal it
kubeseal -f /tmp/oauth2-secret.yaml -w k8s/apps/_common/oauth2-proxy-sealed-secret.yaml

# 5. Apply the sealed secret
kubectl apply -f k8s/apps/_common/oauth2-proxy-sealed-secret.yaml
```

### Step 9: Configure Nginx Proxy Manager (10 minutes)

Follow detailed guide: `k8s/docs/NGINX-PROXY-MANAGER.md`

Quick summary:
```bash
# 1. Get Kubernetes Ingress IP
kubectl get svc -n ingress-nginx ingress-nginx-controller
# Note the EXTERNAL-IP (e.g., 192.168.1.30)

# 2. In Nginx Proxy Manager admin panel:
#    - Create Proxy Host for n8n:
#      - Domain: n8n.lupulup.com
#      - Forward To: https://192.168.1.30:443
#      - Enable SSL & Force SSL
#    - Repeat for flowise, neo4j, searxng, supabase

# 3. Update DNS records in Cloudflare:
#    n8n.lupulup.com → A 192.168.1.11 (or 192.168.1.12)
#    flowise.lupulup.com → A 192.168.1.11
#    neo4j.lupulup.com → A 192.168.1.11
#    searxng.lupulup.com → A 192.168.1.11
#    supabase.lupulup.com → A 192.168.1.11
```

### Step 10: Test Everything (5 minutes)

```bash
# Test each service
curl https://n8n.lupulup.com -k
curl https://flowise.lupulup.com -k
curl https://neo4j.lupulup.com -k
curl https://searxng.lupulup.com -k

# Test in browser (should redirect to Keycloak):
# https://n8n.lupulup.com
# https://flowise.lupulup.com
# https://neo4j.lupulup.com
# https://searxng.lupulup.com

# Login with Keycloak credentials:
# Username: admin
# Password: Admin!234
```

## Using ArgoCD for GitOps (Optional but Recommended)

Instead of manually applying files, you can use ArgoCD for automatic syncing:

```bash
# Apply the App of Apps
kubectl apply -f k8s/argocd/app-of-apps.yaml

# ArgoCD will automatically:
# ✓ Deploy all applications
# ✓ Keep them in sync with Git
# ✓ Handle cleanup when you delete manifests

# Monitor sync status
argocd app list
argocd app sync local-ai-n8n  # If manual sync needed

# Access ArgoCD dashboard
# https://argocd.mylegion5pro.me
```

## File Structure

```
k8s/
├── README.md                              # Overview
├── GETTING-STARTED.md                     # This file
│
├── argocd/
│   ├── app-of-apps.yaml                   # Root application
│   └── applications.yaml                  # Individual apps
│
├── apps/
│   ├── _common/                           # Shared services
│   │   ├── namespace.yaml                 # K8s namespaces
│   │   ├── oauth2-proxy-base.yaml         # SSO gateway
│   │   └── oauth2-proxy-sealed-secret.yaml
│   │
│   ├── n8n/                               # Workflow automation
│   │   ├── deployment.yaml
│   │   ├── service.yaml
│   │   ├── ingress.yaml
│   │   ├── configmap.yaml
│   │   ├── secret.yaml (unencrypted)
│   │   ├── secret-sealed.yaml (encrypted) ← Commit this
│   │   ├── pvc.yaml
│   │   └── kustomization.yaml
│   │
│   ├── flowise/                           # AI agent builder
│   ├── qdrant/                            # Vector database
│   ├── neo4j/                             # Knowledge graph
│   ├── postgres/                          # PostgreSQL database
│   ├── redis/                             # Cache store
│   └── searxng/                           # Search engine
│
├── docs/
│   ├── MIGRATION.md                       # Docker Compose → K8s
│   ├── KEYCLOAK-SETUP.md                  # SSO configuration
│   ├── NGINX-PROXY-MANAGER.md             # NPM setup
│   └── TROUBLESHOOTING.md                 # Common issues
│
└── scripts/
    └── quick-start.sh                     # Automated setup
```

## Quick Reference: Service URLs

| Service | URL | Purpose |
|---------|-----|---------|
| n8n | https://n8n.lupulup.com | Workflow automation |
| Flowise | https://flowise.lupulup.com | AI agent builder |
| Neo4j | https://neo4j.lupulup.com | Knowledge graph |
| SearXNG | https://searxng.lupulup.com | Web search |
| Qdrant | Internal only | Vector database |
| PostgreSQL | Internal only | Primary database |
| Redis | Internal only | Cache store |
| ArgoCD | https://argocd.mylegion5pro.me | Deployment management |
| Keycloak | https://keycloak.mylegion5pro.me | Authentication |
| Ollama | https://ollama.mylegion5pro.me | LLM runtime |
| Open WebUI | https://openwebui.mylegion5pro.me | Chat interface |

## Troubleshooting

### Pod Won't Start

```bash
# Check pod status
kubectl describe pod -n <namespace> <pod-name>

# View logs
kubectl logs -n <namespace> <pod-name>

# Check resource requests
kubectl top pod -n <namespace> <pod-name>
```

### Certificate Issues

```bash
# Check certificate status
kubectl get certificate -n <namespace>

# Describe certificate
kubectl describe cert -n <namespace> <cert-name>

# Check cert secret
kubectl get secret -n <namespace> <cert-secret>
```

### Database Connection Errors

```bash
# Test connection from pod
kubectl exec -it -n <namespace> <pod> -- bash

# Inside pod:
psql -h postgres.local-ai-data -U postgres
redis-cli -h redis.local-ai-system
curl http://qdrant.local-ai-data:6333/health
```

### OAuth2/Keycloak Issues

```bash
# Check OAuth2 Proxy logs
kubectl logs -n local-ai-system deployment/oauth2-proxy -f

# Verify Keycloak connectivity
curl https://keycloak.mylegion5pro.me/realms/homelab/.well-known/openid-configuration
```

See `docs/TROUBLESHOOTING.md` for more detailed solutions.

## Next Steps

1. ✅ Deploy services (you are here)
2. ✅ Configure Keycloak (see `docs/KEYCLOAK-SETUP.md`)
3. ✅ Configure Nginx Proxy Manager (see `docs/NGINX-PROXY-MANAGER.md`)
4. 📚 Read full migration guide: `docs/MIGRATION.md`
5. 🔒 Review security considerations
6. 📊 Set up monitoring and logging
7. 🔄 Configure automated backups
8. 📖 Read service documentation

## Documentation

- **Migration Guide**: `docs/MIGRATION.md` - Complete step-by-step migration from Docker Compose
- **Keycloak Setup**: `docs/KEYCLOAK-SETUP.md` - SSO configuration details
- **Nginx Proxy Manager**: `docs/NGINX-PROXY-MANAGER.md` - Routing and reverse proxy setup
- **Troubleshooting**: `docs/TROUBLESHOOTING.md` - Common issues and solutions
- **Main README**: `README.md` - Project overview

## Support & Help

For issues or questions:
1. Check documentation: `k8s/docs/`
2. Review pod logs: `kubectl logs`
3. Check ArgoCD sync status
4. Verify Keycloak configuration
5. Test service connectivity

## Important Security Notes

⚠️ **Never commit unencrypted secrets to Git!**

```bash
# Always use sealed-secrets:
kubeseal -f secret.yaml -w secret-sealed.yaml
git add secret-sealed.yaml  # ✓ Commit this
git rm secret.yaml          # ✗ Don't commit this
```

⚠️ **Change default passwords!**
- Keycloak admin user
- PostgreSQL root password
- Neo4j admin password

⚠️ **Update domain names** in all configuration files
- Replace `lupulup.com` with your domain
- Replace `mylegion5pro.me` with your domain
- Update Keycloak URLs accordingly

## Success Criteria

You'll know everything is working when:
- ✅ All pods show `READY 1/1` in `kubectl get pods -A`
- ✅ Ingress shows all services with valid IPs
- ✅ Certificates show `READY TRUE`
- ✅ You can access `https://n8n.lupulup.com` and see Keycloak login
- ✅ You can login with Keycloak credentials
- ✅ After login, n8n UI loads successfully
- ✅ ArgoCD shows all applications as `Synced` and `Healthy`

## Questions?

Refer to the comprehensive documentation in the `docs/` directory, particularly:
- `MIGRATION.md` - Most common questions answered
- `KEYCLOAK-SETUP.md` - Authentication issues
- `NGINX-PROXY-MANAGER.md` - Routing and SSL issues
- `TROUBLESHOOTING.md` - Common problems and solutions

Good luck! 🚀
