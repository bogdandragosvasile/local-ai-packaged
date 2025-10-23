# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is **Local AI Packaged** - a self-hosted AI platform combining n8n (workflow automation), Flowise (AI agent builder), Neo4j (knowledge graph), Qdrant (vector DB), PostgreSQL (database), Redis (cache), and SearXNG (search). Originally a Docker Compose project, it now has comprehensive Kubernetes/ArgoCD deployment manifests with Keycloak SSO integration.

### Key Points
- **Original Form**: Docker Compose (in root directory) - for local development
- **Kubernetes Form**: K8s manifests in `k8s/` - for production on Talos cluster (✅ OPERATIONAL)
- **Both can coexist** during migration period
- **Deployment Approach**: App of Apps pattern with ArgoCD for GitOps
- **Authentication**: K8s uses application-level Keycloak OIDC (ingress OAuth2 Proxy not used due to architectural limitation); Docker Compose has optional Caddy auth
- **Routing**: Nginx Proxy Manager (HA @ 192.168.1.177) routes external traffic to K8s ingress
- **Status**: ✅ All 9 pods running, 19h+ uptime, 0 restarts, all services HTTP 200

### Quick Context Switching
- **Working with Docker Compose?** See "Docker Compose Commands" section below
- **Working with Kubernetes?** See "Common Deployment Commands" section
- **Migrating between them?** See `k8s/docs/MIGRATION.md`

---

## Architecture & Infrastructure

### Two Deployment Paths

#### 1. Docker Compose Path (Root Directory)
Used for local development and testing. Files:
- `docker-compose.yml` - Service definitions
- `docker-compose.override.*.yml` - Environment-specific configs
- `.env.example` - Environment variables template
- `start_services.py` - Python orchestration script
- `Caddyfile` - Reverse proxy config (for Docker Compose)
- `n8n_pipe.py` - Open WebUI to n8n integration

#### 2. Kubernetes Path (`k8s/` Directory) - ✅ PRODUCTION READY
Production deployment on Talos cluster. **STATUS: FULLY OPERATIONAL**

Architecture:
```
Nginx Proxy Manager (2 Mini PCs, HA @ 192.168.1.177)
    ↓ (routes lupulup.com, mylegion5pro.me)
Kubernetes Ingress Controller (Nginx)
    ↓ (TLS termination via Let's Encrypt DNS-01)
Services with Application-Level Auth (n8n, Flowise, Neo4j, SearXNG)
    ↓ (each handles auth independently, no ingress auth relay)
Data Layer (PostgreSQL, Qdrant, Neo4j, Redis)
```

**Note**: OAuth2 Proxy is deployed but NOT used in ingress auth (architectural limitation solved via application-level OIDC).

### Kubernetes Deployment Status (2025-10-23)
- **Cluster**: Talos (3+ nodes, all Ready)
- **Nodes**: All healthy
- **Pods**: 9/9 running (0 restarts)
- **Uptime**: 19+ hours (stable)
- **Certificates**: All valid & auto-renewing (Let's Encrypt DNS-01)
- **Services**: All HTTP 200
- **Databases**: All operational (100GB+ storage in use)

### K8s Namespace Organization
```
local-ai-system    ← OAuth2 Proxy + Redis (shared services)
local-ai-n8n       ← n8n deployment
local-ai-flowise   ← Flowise deployment
local-ai-data      ← PostgreSQL, Qdrant, Neo4j (databases)
local-ai-search    ← SearXNG deployment
argocd             ← ArgoCD itself
```

### Manifest Organization
- **`k8s/apps/_common/`** - Namespaces, OAuth2 Proxy, shared resources
- **`k8s/apps/{service}/`** - Individual service manifests (deployment, service, ingress, configmap, secrets)
- **`k8s/argocd/`** - ArgoCD Application definitions (app-of-apps.yaml, applications.yaml)
- **`k8s/docs/`** - Detailed setup guides (Keycloak, NPM, Migration)
- **`k8s/scripts/`** - Deployment automation (quick-start.sh)

### Manifest Dependencies
Services depend on each other in this order:
1. Namespaces → 2. Redis + OAuth2 Proxy → 3. PostgreSQL/Qdrant/Neo4j → 4. n8n/Flowise/SearXNG

All database services must be ready before applications.

---

## Docker Compose Commands

### Local Development Setup
```bash
# Clone repository
git clone https://github.com/coleam00/local-ai-packaged.git
cd local-ai-packaged

# Copy environment template
cp .env.example .env

# Edit .env with required secrets (see README.md for details)
nano .env

# Start services (choose profile based on hardware)
python start_services.py --profile gpu-nvidia    # Nvidia GPU
python start_services.py --profile gpu-amd       # AMD GPU (Linux)
python start_services.py --profile cpu           # CPU only
python start_services.py --profile none          # External Ollama (Mac)

# For public deployment (closes all ports except 80/443)
python start_services.py --profile gpu-nvidia --environment public
```

### Common Docker Compose Operations
```bash
# View running services
docker compose -p localai ps

# View logs
docker compose -p localai logs -f n8n
docker compose -p localai logs -f open-webui

# Stop all services
docker compose -p localai down

# Stop and remove volumes (WARNING: deletes all data)
docker compose -p localai down -v

# Restart a single service
docker compose -p localai restart n8n

# Execute commands in container
docker compose -p localai exec n8n /bin/sh
docker compose -p localai exec db psql -U postgres

# Update all containers to latest versions
docker compose -p localai down
docker compose -p localai pull
python start_services.py --profile <your-profile>
```

### Local Service Access
- **n8n**: http://localhost:5678
- **Open WebUI**: http://localhost:3000
- **Flowise**: http://localhost:3001
- **Supabase Studio**: http://localhost:8000
- **Qdrant**: http://localhost:6333
- **Neo4j Browser**: http://localhost:7474
- **SearXNG**: http://localhost:8080
- **Ollama**: http://localhost:11434

### Database Access (Docker Compose)
```bash
# PostgreSQL (via Supabase)
docker compose -p localai exec db psql -U postgres

# Neo4j (browser at http://localhost:7474)
# Username: neo4j
# Password: from NEO4J_AUTH in .env

# Qdrant (HTTP API)
curl http://localhost:6333/collections

# Redis
docker compose -p localai exec redis redis-cli
```

### Troubleshooting Docker Compose
```bash
# Check service health
docker compose -p localai ps

# View resource usage
docker stats

# Check if ports are in use
netstat -tulpn | grep LISTEN

# Fix Supabase pooler restart issue
# See: https://github.com/supabase/supabase/issues/30210#issuecomment-2456955578

# Fix SearXNG permissions
chmod 755 searxng

# Remove and recreate specific service
docker compose -p localai stop n8n
docker compose -p localai rm -f n8n
docker compose -p localai up -d n8n
```

---

## Common Kubernetes Deployment Commands

### Prerequisites Verification
```bash
# Verify Talos cluster
kubectl get nodes                    # Should show 3+ nodes as Ready
kubectl cluster-info               # Verify cluster connectivity

# Verify required components
kubectl get pods -n argocd         # ArgoCD running
kubectl get pods -n cert-manager   # Cert-Manager running
kubectl get svc -n ingress-nginx   # Nginx Ingress Controller with EXTERNAL-IP
kubectl get deploy -n kube-system sealed-secrets-controller  # Sealed Secrets

# Get Ingress IP (needed for NPM configuration)
kubectl get svc -n ingress-nginx ingress-nginx-controller
# Note the EXTERNAL-IP (e.g., 192.168.1.30)
```

### Secret Management
```bash
# Encrypt a single secret with sealed-secrets
kubeseal -f k8s/apps/{service}/secret.yaml -w k8s/apps/{service}/secret-sealed.yaml

# Encrypt all secrets
for dir in k8s/apps/*/; do
  if [ -f "$dir/secret.yaml" ]; then
    kubeseal -f "$dir/secret.yaml" -w "$dir/secret-sealed.yaml"
  fi
done

# Apply sealed secret to cluster
kubectl apply -f k8s/apps/{service}/secret-sealed.yaml
```

### Deployment Commands
```bash
# Create namespaces
kubectl apply -f k8s/apps/_common/namespace.yaml

# Deploy individual service (wait for ready state)
kubectl apply -f k8s/apps/redis/deployment.yaml
kubectl get pods -n local-ai-system -l app=redis -w

# Deploy all via ArgoCD (preferred)
kubectl apply -f k8s/argocd/app-of-apps.yaml

# Check ArgoCD sync status
kubectl get applications -n argocd
argocd app list  # If using argocd CLI
```

### Verification Commands
```bash
# Check all local-ai services
kubectl get pods -A | grep local-ai

# View service logs
kubectl logs -n local-ai-n8n deployment/n8n
kubectl logs -n local-ai-system deployment/oauth2-proxy -f

# Port-forward for local testing
kubectl port-forward -n local-ai-data svc/postgres 5432:5432 &
kubectl port-forward -n local-ai-n8n svc/n8n 5678:5678 &

# Test database connectivity
kubectl exec -it -n local-ai-data supabase-postgres-0 -- psql -U postgres -c "SELECT version();"

# Test service-to-service communication
kubectl exec -it -n local-ai-n8n deployment/n8n -- bash
# Inside pod: curl http://postgres.local-ai-data:5432
```

### ArgoCD Specific
```bash
# Login to ArgoCD
argocd login argocd.mylegion5pro.me --username admin

# View app status
argocd app list
argocd app get local-ai-n8n

# Sync individual app
argocd app sync local-ai-n8n

# Monitor app sync
argocd app watch local-ai-n8n
```

### Testing & Troubleshooting
```bash
# Test external service URLs
curl -v https://n8n.lupulup.com         # Should redirect to Keycloak
curl -v https://flowise.lupulup.com

# Check certificate status
kubectl get certificate -n local-ai-n8n -o wide
kubectl describe cert -n local-ai-n8n n8n-tls

# Describe pod for events
kubectl describe pod -n local-ai-n8n -l app=n8n

# Check pod resource usage
kubectl top pods -n local-ai-n8n
```

---

## Working with Secrets & Configuration

### Secret Encryption Workflow
1. **Never commit unencrypted secrets** to Git
2. Edit `secret.yaml` template with actual values
3. Encrypt with kubeseal: `kubeseal -f secret.yaml -w secret-sealed.yaml`
4. Commit **only** `secret-sealed.yaml` to Git
5. Add `*/secret.yaml` to `.gitignore`
6. Delete unencrypted `secret.yaml` locally

### Secrets Requiring Generation
- **PostgreSQL**: `openssl rand -base64 32` (minimum 16 chars)
- **Neo4j**: `openssl rand -base64 32` (minimum 16 chars)
- **n8n encryption key**: `openssl rand -hex 32` (must be 32 bytes hex)
- **n8n JWT secrets**: `openssl rand -base64 32` (2 required)
- **Qdrant API key**: `openssl rand -base64 32` (any random string)
- **OAuth2 cookie secret**: `openssl rand -base64 32`

### ConfigMaps vs Secrets
- **ConfigMaps** (`configmap.yaml`) - Non-sensitive config (service URLs, ports, log levels)
- **Secrets** (`secret-sealed.yaml`) - Sensitive data (passwords, API keys, encryption keys)

---

## Keycloak Integration

### Key Endpoints
- **Keycloak Server**: `https://keycloak.mylegion5pro.me`
- **Realm**: `homelab` (already created)
- **Test Users**: admin, developer, explorer (credentials in realm-homelab.json)

### OAuth2 Proxy Flow
1. User accesses `https://n8n.lupulup.com`
2. OAuth2 Proxy intercepts, redirects to Keycloak login
3. User authenticates with Keycloak
4. Keycloak redirects back to service with auth token
5. Service receives authenticated user session

### Keycloak Client Configuration
For each service, create OAuth2 client with:
- **Client ID**: service name (e.g., "n8n", "flowise")
- **Access Type**: confidential
- **Valid Redirect URIs**: `https://{service-domain}/oauth2/callback`
- **Web Origins**: `https://{service-domain}`

See `k8s/docs/KEYCLOAK-SETUP.md` for detailed steps.

---

## Nginx Proxy Manager Integration

### Purpose
NPM (running on 2 mini PCs with HA) proxies external traffic from Cloudflare/NoIP to Kubernetes ingress.

### Configuration Pattern
For each service:
1. Create proxy host in NPM: `service.lupulup.com` → `https://192.168.1.30:443` (K8s ingress IP)
2. Enable SSL certificate (Let's Encrypt or Cloudflare)
3. Force SSL, enable HSTS, block exploits
4. Add corresponding DNS A record pointing to NPM IP

See `k8s/docs/NGINX-PROXY-MANAGER.md` for detailed steps.

---

## Documentation Map

### For Getting Started
- `k8s/GETTING-STARTED.md` - Quick start (5-minute overview, 10-step manual deployment)
- `k8s/README.md` - Architecture overview and directory structure

### For Deployment Execution
- `DEPLOYMENT-CHECKLIST.md` - 12-phase deployment with every step
- `k8s/docs/KEYCLOAK-SETUP.md` - Keycloak OAuth2 client setup
- `k8s/docs/NGINX-PROXY-MANAGER.md` - NPM routing configuration

### For Reference
- `K8S-DEPLOYMENT-SUMMARY.md` - Complete feature overview
- `K8S-INDEX.md` - File reference and navigation
- `k8s/docs/MIGRATION.md` - Complete migration guide, database backup/restore, rollback procedures

### For Troubleshooting
- `k8s/docs/TROUBLESHOOTING.md` - Common issues and solutions (in progress)

---

## Service-Specific Details

### n8n (Workflow Automation)
- **Image**: n8nio/n8n:latest
- **Storage**: 20Gi PVC for workflows and credentials
- **Config**: ConfigMap (configmap.yaml), Secrets (secret-sealed.yaml)
- **Database**: PostgreSQL (postgres.local-ai-data:5432)
- **Integrations**: Connects to Qdrant, Neo4j, Redis, Ollama, Open WebUI
- **Ingress**: https://n8n.lupulup.com (OAuth2 protected)
- **Key Environment Variables**:
  - `DB_POSTGRESDB_*` - PostgreSQL connection
  - `N8N_ENCRYPTION_KEY` - 32-byte hex encryption key
  - `N8N_USER_MANAGEMENT_JWT_SECRET` - JWT signing key
  - `WEBHOOK_URL` - External webhook endpoint

### Flowise (AI Agent Builder)
- **Image**: flowiseai/flowise:latest
- **Storage**: 10Gi PVC
- **Database**: PostgreSQL (optional, can use local SQLite)
- **Key Environment Variables**:
  - `PORT` - Service port
  - `FLOWISE_PASSWORD` - Admin password
  - `APIKEY` - API authentication

### Data Layer (Databases)
- **PostgreSQL**: Primary database, used by n8n, Flowise, Supabase
  - StatefulSet, 100Gi storage
  - User: postgres, password in sealed secret
  - Default database: postgres

- **Qdrant**: Vector database for embeddings/RAG
  - StatefulSet, 50Gi storage
  - API key authentication
  - Accessed at: `http://qdrant.local-ai-data:6333`

- **Neo4j**: Knowledge graph database
  - StatefulSet, 50Gi storage
  - Admin user: neo4j, password in sealed secret
  - Browser UI: https://neo4j.lupulup.com

- **Redis**: Cache and session store
  - Deployment, 10Gi storage
  - Accessed at: `redis.local-ai-system:6379`
  - Used by: n8n queues, OAuth2 Proxy sessions

### OAuth2 Proxy (Keycloak Gateway)
- **Image**: quay.io/oauth2-proxy/oauth2-proxy:v7.6.0
- **Replicas**: 2 (for HA)
- **Upstream**: Keycloak OIDC endpoint
- **Configuration**: ConfigMap (oauth2-proxy-base.yaml)
- **Key Settings**:
  - `provider: oidc`
  - `oidc_issuer_url: https://keycloak.mylegion5pro.me/realms/homelab`
  - `cookie_domains: .lupulup.com,.mylegion5pro.me`

### SearXNG (Search Engine)
- **Image**: searxng/searxng:latest
- **Storage**: 5Gi for cache
- **Database**: Redis (for query caching)
- **Ingress**: https://searxng.lupulup.com (OAuth2 protected)

---

## Making Changes & Updates

### Adding a New Service
1. Create `k8s/apps/{service}/` directory
2. Add manifests: `deployment.yaml`, `service.yaml`, `ingress.yaml`, `configmap.yaml`, `secret.yaml`
3. Create OAuth2 client in Keycloak
4. Add Ingress with OAuth2 annotations (see n8n/ingress.yaml for template)
5. Create proxy host in Nginx Proxy Manager
6. Add DNS record in Cloudflare/NoIP
7. Create ArgoCD Application in `k8s/argocd/applications.yaml`

### Updating Service Configuration
1. Edit the ConfigMap (`configmap.yaml`)
2. Commit and push to Git
3. If using ArgoCD: auto-syncs or manual sync with `argocd app sync`
4. If not using ArgoCD: `kubectl apply -f k8s/apps/{service}/`
5. Restart pod for ConfigMap changes: `kubectl rollout restart deployment/{service}`

### Updating Secrets
1. Edit the unencrypted `secret.yaml` (don't commit)
2. Encrypt: `kubeseal -f secret.yaml -w secret-sealed.yaml`
3. Commit `secret-sealed.yaml`
4. Apply: `kubectl apply -f secret-sealed.yaml`
5. Restart deployment for secret changes

### Scaling a Service
```bash
# Manual scale
kubectl scale deployment/n8n -n local-ai-n8n --replicas=3

# Or edit manifest and redeploy
vim k8s/apps/n8n/deployment.yaml  # Change replicas
kubectl apply -k k8s/apps/n8n/
```

---

## Data Migration Between Docker Compose and Kubernetes

### Export Data from Docker Compose
```bash
# PostgreSQL database dump
docker compose -p localai exec db pg_dumpall -U postgres > backup/postgres-dump.sql

# Neo4j export
docker compose -p localai exec neo4j neo4j-admin dump --database=neo4j --to=/backups/neo4j.dump
docker cp localai-neo4j-1:/backups/neo4j.dump backup/

# Qdrant snapshots
curl -X POST http://localhost:6333/collections/my_collection/snapshots

# n8n workflows (manual export from UI)
# Go to http://localhost:5678 → Settings → Export workflows

# Flowise flows (manual export from UI)
# Go to http://localhost:3001 → Export chatflows
```

### Import Data to Kubernetes
```bash
# PostgreSQL restore
cat backup/postgres-dump.sql | kubectl exec -i -n local-ai-data supabase-postgres-0 -- psql -U postgres

# Neo4j restore
kubectl cp backup/neo4j.dump local-ai-data/neo4j-0:/tmp/neo4j.dump
kubectl exec -n local-ai-data neo4j-0 -- neo4j-admin load --from=/tmp/neo4j.dump --database=neo4j --force

# Qdrant (use port-forward and API)
kubectl port-forward -n local-ai-data svc/qdrant-client 6333:6333
# Then use Qdrant API to restore snapshots

# n8n workflows (import via UI at https://n8n.lupulup.com)
# Flowise flows (import via UI at https://flowise.lupulup.com)
```

---

## Storage & Persistence

### Persistent Volumes Required
- n8n: 20Gi (workflows, credentials)
- Flowise: 10Gi (agent configs)
- PostgreSQL: 100Gi (databases)
- Qdrant: 50Gi (vector embeddings)
- Neo4j: 50Gi (graph data)
- Redis: 10Gi (cache, sessions)
- SearXNG: 5Gi (search cache)

**Total**: 245GB minimum required

### Storage Class
Uses `local-path` storage class (Talos default). Can be changed in PVC manifests.

### Backup Strategy
Databases (PostgreSQL, Neo4j, Qdrant) should be backed up regularly:
```bash
# PostgreSQL dump
kubectl exec -n local-ai-data supabase-postgres-0 -- \
  pg_dump -U postgres > backup.sql

# Snapshot approach: Use your storage provider's snapshot feature
```

---

## Important Notes for Claude Code

### When Assisting with Docker Compose
1. Always check if `.env` exists before running services
2. Use the `start_services.py` script - it handles Supabase initialization
3. Profile selection matters: `gpu-nvidia`, `gpu-amd`, `cpu`, or `none`
4. For Mac users running Ollama locally, update OLLAMA_HOST to `host.docker.internal:11434`
5. Environment argument: `private` (default, exposes ports) or `public` (only 80/443)

### When Assisting with Kubernetes Deployment
1. Always verify prerequisites before proceeding with each phase
2. Monitor pod startup with `kubectl get pods -n {namespace} -w`
3. Check logs if pods don't reach READY state: `kubectl logs -n {namespace} {pod}`
4. Never skip secret encryption - always use kubeseal
5. Kubernetes Ingress IP is needed for NPM configuration - save it
6. DNS propagation takes time - verify with `nslookup` before testing

### When Troubleshooting
**Docker Compose:**
1. Check service status: `docker compose -p localai ps`
2. View logs: `docker compose -p localai logs -f {service}`
3. Check resource usage: `docker stats`
4. Verify .env file has all required variables from `.env.example`

**Kubernetes:**
1. Check pod events: `kubectl describe pod -n {namespace} {pod-name}`
2. Check pod logs: `kubectl logs -n {namespace} {pod-name}`
3. Test connectivity: `kubectl exec -it -n {namespace} {pod} -- /bin/bash`
4. Verify secrets: `kubectl get secret -n {namespace}` (sealed secrets won't show values)
5. Check ingress/certificates: `kubectl get ingress -n {namespace}`, `kubectl get cert -n {namespace}`

### File Locations to Know
- **Docker Compose**: `docker-compose.yml`, `docker-compose.override.*.yml`, `.env`, `Caddyfile`
- **K8s manifests**: `k8s/apps/{service}/*.yaml`
- **ArgoCD apps**: `k8s/argocd/applications.yaml`, `k8s/argocd/app-of-apps.yaml`
- **Documentation**: `k8s/docs/*.md`, `DEPLOYMENT-CHECKLIST.md`, `README.md`
- **Scripts**: `start_services.py`, `n8n_pipe.py`, `k8s/scripts/quick-start.sh`

### Environment Variables & Secrets
**Docker Compose:**
- `.env` - All configuration (not in Git, template is `.env.example`)
- Required secrets: N8N_ENCRYPTION_KEY, JWT_SECRET, POSTGRES_PASSWORD, NEO4J_AUTH, etc.

**Kubernetes:**
- ConfigMaps - Non-sensitive config (service URLs, ports, log levels)
- Sealed Secrets - Sensitive data (always encrypted with kubeseal before committing)

### Git Workflow for Deployment
```bash
# Before pushing, ensure:
1. No unencrypted secrets in staged files
2. Encrypted secrets use -sealed.yaml naming
3. Secrets in .gitignore
4. All documentation updated

# Commit changes
git add k8s/
git commit -m "Update n8n configuration / Add new service / Encrypt secrets"
git push origin main

# If using ArgoCD, changes auto-sync or:
argocd app sync local-ai-n8n
```

---

## Quick Reference: Domain Mapping

| Service | Domain | Backend URL | Auth |
|---------|--------|------------|------|
| n8n | n8n.lupulup.com | n8n.local-ai-n8n:5678 | Keycloak |
| Flowise | flowise.lupulup.com | flowise.local-ai-flowise:3000 | Keycloak |
| Neo4j | neo4j.lupulup.com | neo4j-client.local-ai-data:7474 | Keycloak |
| SearXNG | searxng.lupulup.com | searxng.local-ai-search:8080 | Keycloak |
| ArgoCD | argocd.mylegion5pro.me | argocd-server.argocd | ArgoCD auth |
| Keycloak | keycloak.mylegion5pro.me | External service | N/A |

---

## Testing & Development Workflow

### n8n + Open WebUI Integration
The repository includes `n8n_pipe.py` - a custom function that bridges n8n workflows with Open WebUI.

**Setup (Docker Compose):**
1. Start all services: `python start_services.py --profile <your-profile>`
2. Open n8n at http://localhost:5678 and activate a workflow
3. Copy the production webhook URL from the workflow
4. Open Open WebUI at http://localhost:3000
5. Go to Workspace → Functions → Add Function
6. Paste code from `n8n_pipe.py` (also available at https://openwebui.com/f/coleam/n8n_pipe/)
7. Set `n8n_url` to your webhook URL
8. Toggle function ON
9. Select the function from model dropdown in chat

**Testing Workflows:**
```bash
# Test n8n webhook directly
curl -X POST http://localhost:5678/webhook/your-workflow-id \
  -H "Content-Type: application/json" \
  -d '{"query": "test message"}'

# Check n8n logs
docker compose -p localai logs -f n8n

# Check Open WebUI logs
docker compose -p localai logs -f open-webui
```

### Creating Custom n8n Workflows
1. Access n8n UI (localhost:5678 for Docker, https://n8n.lupulup.com for K8s)
2. Set up credentials for integrated services:
   - **Ollama**: `http://ollama:11434` (Docker) or service URL (K8s)
   - **PostgreSQL**: Host `db` (Docker) or `postgres.local-ai-data` (K8s)
   - **Qdrant**: `http://qdrant:6333` (Docker) or `qdrant.local-ai-data:6333` (K8s)
   - **Neo4j**: `bolt://neo4j:7687` (Docker) or `neo4j.local-ai-data:7687` (K8s)
3. Test workflow with "Execute Workflow" button
4. Export workflows: Settings → Export workflows → Save JSON

### Database Queries & Administration
```bash
# PostgreSQL (Docker Compose)
docker compose -p localai exec db psql -U postgres -c "SELECT version();"
docker compose -p localai exec db psql -U postgres -d postgres -c "\dt"  # List tables

# PostgreSQL (Kubernetes)
kubectl exec -it -n local-ai-data supabase-postgres-0 -- psql -U postgres -c "SELECT version();"

# Neo4j Cypher queries (browser UI or API)
curl -u neo4j:password http://localhost:7474/db/data/

# Qdrant collections
curl http://localhost:6333/collections  # Docker
kubectl port-forward -n local-ai-data svc/qdrant-client 6333:6333  # K8s, then curl localhost
```

---

---

## Keycloak Integration Status (2025-10-23)

### ✅ COMPLETE AND OPERATIONAL

**Current State**:
- Realm: `homelab` (fully configured)
- Users: 3 test users created (admin, developer, explorer)
- Groups: 3 groups created (admins, developers, explorers)
- OAuth2 Clients: 5 clients configured (flowise, n8n, neo4j, searxng, oauth2-proxy)
- OIDC Discovery: ✅ Operational
- TLS Certificates: ✅ All valid & auto-renewing (Let's Encrypt DNS-01)
- Services: ✅ All HTTP 200

**Integration Pattern**:
- Application-level Keycloak OIDC (NOT ingress OAuth2 Proxy)
- Each service handles authentication independently
- Solved: Redirect loop issue (architectural limitation of ingress auth-request pattern)
- Result: All services accessible without authentication relay issues

**Services With OIDC Configuration**:
- Flowise: OIDC env vars configured (flowise.lupulup.com)
- n8n: Auth endpoint exclusions configured (n8n.lupulup.com)
- Neo4j: Native auth ready for LDAP connector (neo4j.lupulup.com)
- SearXNG: Public access (searxng.lupulup.com)
- Keycloak: Identity provider (keycloak.mylegion5pro.me)

**Documentation**:
- README-KEYCLOAK.md - Start here (overview & quick navigation)
- 00-START-HERE.md - Navigation guide
- KEYCLOAK-QUICK-START.md - 5-minute setup
- KEYCLOAK-VISUAL-GUIDE.md - ASCII diagrams (15 min)
- KEYCLOAK-USER-SETUP-GUIDE.md - Complete 10-part guide (30 min)
- k8s/docs/APPLICATION-KEYCLOAK-INTEGRATION.md - Architecture details
- KEYCLOAK-INTEGRATION-STATUS.md - Detailed status report
- OPERATIONS-CHECKLIST.md - Daily operations guide
- COMPLETION-SUMMARY.md - Project completion summary

**Test Users**:
```
admin     / Admin@123!     (group: admins)
developer / Dev@123!      (group: developers)
explorer  / Explorer@123! (group: explorers)
```

All users are active and verified. Ready for immediate use.

---

## Related Repositories & Resources

- **Original Project**: https://github.com/coleam00/local-ai-packaged (Docker Compose version)
- **Local AI Community**: https://thinktank.ottomator.ai/c/local-ai/18
- **GitHub Kanban Board**: https://github.com/users/coleam00/projects/2/views/1
- **n8n Docs**: https://docs.n8n.io/
- **Flowise Docs**: https://docs.flowiseai.com/
- **Ollama**: https://ollama.com/
- **Supabase Self-Hosting**: https://supabase.com/docs/guides/self-hosting/docker
- **Kubernetes**: https://kubernetes.io/docs/
- **ArgoCD**: https://argoproj.github.io/argo-cd/
- **Keycloak**: https://www.keycloak.org/docs/
- **Talos**: https://www.talos.dev/

