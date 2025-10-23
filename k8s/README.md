# Local AI Package - Kubernetes Deployment

This directory contains the Kubernetes manifests for deploying the Local AI Package as an App of Apps using ArgoCD on a Talos cluster with Keycloak SSO integration.

## Directory Structure

```
k8s/
├── argocd/                          # ArgoCD App of Apps configuration
│   ├── app-of-apps.yaml             # Root application that manages all apps
│   ├── app-project.yaml             # AppProject for RBAC and policies
│   └── applicationset.yaml          # Auto-generates apps from directories
│
├── apps/                            # Individual service applications
│   ├── _common/                     # Shared configurations
│   │   ├── namespace.yaml           # local-ai-system namespace
│   │   ├── oauth2-proxy.yaml        # OAuth2 Proxy for Keycloak SSO
│   │   ├── oauth2-proxy-values.yaml # OAuth2 Proxy Helm values
│   │   └── sealed-secrets.yaml      # Sealed Secrets controller
│   │
│   ├── n8n/
│   │   ├── kustomization.yaml
│   │   ├── namespace.yaml
│   │   ├── deployment.yaml
│   │   ├── service.yaml
│   │   ├── ingress.yaml
│   │   ├── configmap.yaml
│   │   ├── secret-sealed.yaml
│   │   └── pvc.yaml
│   │
│   ├── flowise/
│   ├── neo4j/
│   ├── qdrant/
│   ├── supabase-postgres/
│   ├── searxng/
│   └── redis/
│
└── docs/
    ├── MIGRATION.md                 # Step-by-step migration guide
    ├── KEYCLOAK-SETUP.md            # Keycloak configuration
    ├── NGINX-PROXY-MANAGER.md       # NPM routing configuration
    └── TROUBLESHOOTING.md           # Common issues and solutions
```

## Quick Start

### 1. Prerequisites
- Talos Kubernetes cluster running
- ArgoCD installed and accessible
- Keycloak running with `homelab` realm
- kubectl configured

### 2. Prepare Git Repository
```bash
# Create a separate Git repository for ArgoCD (recommended)
git clone https://github.com/your-username/local-ai-k8s.git
cd local-ai-k8s

# Or use this repository with k8s/ subdirectory
```

### 3. Create Sealed Secrets Key (if not already created)
```bash
kubectl get secret -n kube-system sealed-secrets-key
# If not exists, sealed-secrets-controller will create one
```

### 4. Encrypt Sensitive Data
```bash
# Encrypt database passwords and API keys
kubeseal -f k8s/apps/n8n/secret.yaml -w k8s/apps/n8n/secret-sealed.yaml

# Or use the helper script
./scripts/encrypt-secrets.sh
```

### 5. Create ArgoCD Applications
```bash
# Apply the App of Apps
kubectl apply -f k8s/argocd/app-of-apps.yaml

# ArgoCD will automatically sync all applications
kubectl get applications -n argocd
```

### 6. Configure Keycloak
```bash
# Import the new OAuth2 clients
./scripts/setup-keycloak-clients.sh

# Or manually create clients:
# - n8n
# - flowise
# - neo4j
# - searxng
# - supabase
```

### 7. Configure Nginx Proxy Manager
Update routing rules to point to Kubernetes Ingress endpoints instead of Docker containers.

## Architecture

### App of Apps Pattern
The root application (`app-of-apps.yaml`) manages all child applications:
- Each service has its own ArgoCD Application
- Applications are synced automatically
- Cleanup handled by finalizers

### Namespace Strategy
- `local-ai-system`: Shared services (OAuth2 Proxy, Sealed Secrets)
- `local-ai-n8n`: n8n and related resources
- `local-ai-flowise`: Flowise and related resources
- `local-ai-data`: Data services (Postgres, Qdrant, Neo4j)
- `local-ai-search`: SearXNG
- `argocd`: ArgoCD system

### SSO Flow
```
User Browser
    ↓
Nginx Proxy Manager (NPM)
    ↓
Kubernetes Ingress (TLS termination)
    ↓
OAuth2 Proxy Service
    ↓
Keycloak Authentication
    ↓
Protected Service (n8n, Flowise, etc.)
```

## Service URLs

### Cloudflare (lupulup.com)
- n8n: https://n8n.lupulup.com
- Flowise: https://flowise.lupulup.com
- Neo4j: https://neo4j.lupulup.com
- SearXNG: https://searxng.lupulup.com
- Supabase: https://supabase.lupulup.com

### NoIP (mylegion5pro.me)
- ArgoCD: https://argocd.mylegion5pro.me (already configured)
- Ollama: https://ollama.mylegion5pro.me (already configured)
- Open WebUI: https://openwebui.mylegion5pro.me (already configured)

## Database & Storage

### PostgreSQL (Supabase)
- Used by: n8n, Supabase itself, Flowise
- Storage: StatefulSet with PersistentVolume

### Qdrant Vector Database
- Used by: n8n RAG workflows, Flowise
- Storage: StatefulSet with PersistentVolume

### Neo4j Knowledge Graph
- Used by: RAG workflows for knowledge graphs
- Storage: StatefulSet with PersistentVolume

### Redis
- Used by: Session caching, job queues
- Storage: StatefulSet with PersistentVolume

## Configuration

### Environment Variables
All sensitive configuration (database passwords, API keys, JWT secrets) is stored in Sealed Secrets.

See `k8s/apps/[service]/secret-sealed.yaml` for encrypted values.

### OAuth2 Proxy Configuration
Located in `k8s/apps/_common/oauth2-proxy-values.yaml`:
- Keycloak integration endpoint
- Cookie encryption
- OAuth2 client credentials
- Redirect URIs per service

## Monitoring & Observability

Langfuse is not yet included in this setup but can be added following the same pattern.

## Backup & Recovery

### Automatic Backups
Configure external snapshots:
```bash
./scripts/setup-velero-backups.sh
```

### Manual Backup
```bash
# Backup all persistent volumes
kubectl get pvc --all-namespaces -o json | jq '.items[]'

# Backup Keycloak realm
kubectl exec -n keycloak keycloak-0 -- keycloak.sh export --realm homelab
```

## Troubleshooting

See `docs/TROUBLESHOOTING.md` for:
- Certificate issues
- SSO authentication failures
- Database connectivity
- Service communication

## FAQ

**Q: Can I keep using Docker Compose for development?**
A: Yes! Run Docker Compose on your local machine while K8s handles production.

**Q: How do I update service configurations?**
A: Edit the YAML files and push to Git. ArgoCD will automatically sync.

**Q: What if a service crashes?**
A: Kubernetes will automatically restart failed pods. Check logs with `kubectl logs`.

**Q: How do I add a new service?**
A: Create a new directory under `k8s/apps/` following the pattern, create ArgoCD Application, and commit to Git.

## Support

For issues related to:
- **Kubernetes**: Check talos-manual documentation
- **ArgoCD**: Review argocd-example-apps
- **Keycloak**: Consult realm-homelab.json configuration
- **Services**: Check individual service documentation

## Next Steps

1. Review migration guide: `docs/MIGRATION.md`
2. Set up Keycloak clients: `docs/KEYCLOAK-SETUP.md`
3. Configure Nginx Proxy Manager: `docs/NGINX-PROXY-MANAGER.md`
4. Test each service with SSO
5. Monitor ArgoCD sync status
