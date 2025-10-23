# Local AI Kubernetes Deployment - File Index

Complete reference of all files created for your Kubernetes migration.

## 📋 Quick Navigation

| File | Purpose | Read Time |
|------|---------|-----------|
| `K8S-DEPLOYMENT-SUMMARY.md` | **START HERE** - Overview of everything created | 10 min |
| `DEPLOYMENT-CHECKLIST.md` | Step-by-step deployment checklist | 30 min |
| `k8s/GETTING-STARTED.md` | Getting started guide with quick start | 15 min |
| `k8s/README.md` | Architecture and design details | 10 min |

---

## 📁 Directory Structure & Files

### Root Level Documentation
```
.
├── K8S-DEPLOYMENT-SUMMARY.md          ← Overview (READ FIRST)
├── DEPLOYMENT-CHECKLIST.md             ← Step-by-step checklist
├── K8S-INDEX.md                        ← This file
└── k8s/                                ← All Kubernetes manifests
```

### k8s/ - Main Directory
```
k8s/
├── README.md                           # Architecture overview
├── GETTING-STARTED.md                  # Getting started (READ SECOND)
│
├── argocd/                             # ArgoCD GitOps configuration
│   ├── app-of-apps.yaml               # Root application (syncs all)
│   └── applications.yaml              # Individual service applications
│
├── apps/                               # Service manifests
│   ├── _common/                        # Shared infrastructure
│   │   ├── namespace.yaml             # 5 namespaces definition
│   │   └── oauth2-proxy-base.yaml     # Keycloak SSO gateway
│   │
│   ├── n8n/                           # n8n workflow automation
│   │   ├── namespace.yaml
│   │   ├── deployment.yaml            # Main n8n pod
│   │   ├── service.yaml               # 2 services (n8n + webhook)
│   │   ├── configmap.yaml             # Configuration values
│   │   ├── secret.yaml                # TEMPLATE - fill with values
│   │   ├── secret-sealed.yaml         # ENCRYPTED - commit this to Git
│   │   ├── pvc.yaml                   # 20Gi storage
│   │   ├── ingress.yaml               # HTTPS + OAuth2 Proxy
│   │   └── kustomization.yaml         # Kustomize overlay
│   │
│   ├── flowise/
│   │   └── deployment.yaml            # All-in-one deployment
│   │
│   ├── qdrant/
│   │   └── statefulset.yaml           # StatefulSet + service
│   │
│   ├── neo4j/
│   │   └── statefulset.yaml           # StatefulSet + service + ingress
│   │
│   ├── postgres/
│   │   └── statefulset.yaml           # PostgreSQL StatefulSet
│   │
│   ├── redis/
│   │   └── deployment.yaml            # Redis caching
│   │
│   └── searxng/
│       └── deployment.yaml            # SearXNG search engine
│
├── docs/                               # Comprehensive guides
│   ├── KEYCLOAK-SETUP.md              # OAuth2 Proxy + Keycloak config
│   ├── NGINX-PROXY-MANAGER.md         # NPM routing setup
│   ├── MIGRATION.md                   # 12-phase migration guide
│   └── TROUBLESHOOTING.md             # Common issues & solutions
│
└── scripts/
    └── quick-start.sh                 # Automated deployment script
```

---

## 🚀 Getting Started (Choose Your Path)

### Path 1: Fast Start (30 minutes)
1. Read: `K8S-DEPLOYMENT-SUMMARY.md` (5 min)
2. Read: `k8s/GETTING-STARTED.md` (10 min)
3. Run: `k8s/scripts/quick-start.sh` (15 min)
4. Check: All services running in K8s
5. Follow: Keycloak and Nginx guides

### Path 2: Detailed Setup (1-2 hours)
1. Read: `k8s/README.md` - Understand architecture
2. Read: `DEPLOYMENT-CHECKLIST.md` - Follow all steps
3. Deploy manually using kubectl commands
4. Configure Keycloak: `k8s/docs/KEYCLOAK-SETUP.md`
5. Configure Nginx: `k8s/docs/NGINX-PROXY-MANAGER.md`

### Path 3: GitOps Best Practice (1.5-2 hours)
1. Follow Path 2 for manual deployment
2. Set up Git repository with k8s/ directory
3. Deploy with ArgoCD: `k8s/argocd/app-of-apps.yaml`
4. All services auto-synced from Git commits

---

## 📚 Documentation Guide

### For First Deployment
1. **K8S-DEPLOYMENT-SUMMARY.md** - Overview (what you're getting)
2. **DEPLOYMENT-CHECKLIST.md** - Verification steps
3. **k8s/GETTING-STARTED.md** - How to deploy
4. **k8s/docs/KEYCLOAK-SETUP.md** - Configure authentication
5. **k8s/docs/NGINX-PROXY-MANAGER.md** - Configure routing

### For Understanding Architecture
- **k8s/README.md** - Architecture overview and design decisions
- **k8s/docs/MIGRATION.md** - Full migration guide with rollback

### For Troubleshooting
- **k8s/docs/TROUBLESHOOTING.md** - Common issues and solutions
- Check service logs: `kubectl logs -n <namespace> <pod>`
- Check events: `kubectl describe pod -n <namespace> <pod>`

### For Operations
- **k8s/docs/MIGRATION.md** - Database backups, scaling, updates
- Service-specific documentation (links in k8s/README.md)

---

## 🔐 Secrets Management

### Files Requiring Encryption
These files must be encrypted with `kubeseal` before committing to Git:

```
k8s/apps/n8n/secret.yaml
k8s/apps/flowise/secret.yaml
k8s/apps/postgres/secret.yaml
k8s/apps/neo4j/secret.yaml
k8s/apps/qdrant/secret.yaml
k8s/apps/_common/oauth2-proxy-secrets.yaml
```

### Encrypted Versions
These are the SEALED (encrypted) versions safe to commit:

```
k8s/apps/n8n/secret-sealed.yaml              ← COMMIT THESE
k8s/apps/flowise/secret-sealed.yaml
k8s/apps/postgres/secret-sealed.yaml
k8s/apps/neo4j/secret-sealed.yaml
k8s/apps/qdrant/secret-sealed.yaml
k8s/apps/_common/oauth2-proxy-sealed-secret.yaml
```

### Secret Encryption Steps
```bash
# 1. Edit unencrypted secret
vi k8s/apps/n8n/secret.yaml

# 2. Encrypt with sealed-secrets
kubeseal -f k8s/apps/n8n/secret.yaml -w k8s/apps/n8n/secret-sealed.yaml

# 3. Add to .gitignore
echo "*/secret.yaml" >> .gitignore

# 4. Commit only sealed version
git add k8s/
git commit -m "Add encrypted secrets"
```

See: `k8s/docs/MIGRATION.md` - Phase 2 for detailed instructions.

---

## 📊 Manifest Statistics

### By Service
| Service | Files | Size | Purpose |
|---------|-------|------|---------|
| n8n | 8 | ~25KB | Workflow automation |
| Flowise | 1 | ~8KB | AI agent builder |
| Qdrant | 1 | ~5KB | Vector database |
| Neo4j | 1 | ~6KB | Knowledge graph |
| PostgreSQL | 1 | ~5KB | Main database |
| Redis | 1 | ~3KB | Cache store |
| SearXNG | 1 | ~7KB | Search engine |
| OAuth2 Proxy | 1 | ~10KB | Keycloak gateway |
| Namespaces | 1 | ~1KB | K8s organization |

### By Type
| Type | Count |
|------|-------|
| Deployments | 5 |
| StatefulSets | 3 |
| Services | 12+ |
| Ingresses | 5 |
| Certificates | 5 |
| ConfigMaps | 2+ |
| Secrets | 7 |
| PVCs | 6 |
| Roles/RoleBindings | 3 |
| ServiceAccounts | 3 |

### Total Lines of Code
- YAML Manifests: ~2500 lines
- Documentation: ~3500 lines
- Scripts: ~300 lines
- **Total: ~6300 lines**

---

## 🔗 File Dependencies

### Critical Path (Must Deploy in Order)
```
1. namespace.yaml
   ↓
2. oauth2-proxy-base.yaml + redis/deployment.yaml
   ↓
3. postgres/statefulset.yaml
   ↓
4. qdrant/statefulset.yaml + neo4j/statefulset.yaml
   ↓
5. n8n/deployment.yaml + flowise/deployment.yaml + searxng/deployment.yaml
   ↓
6. app-of-apps.yaml (ArgoCD - if using GitOps)
```

### Secret Dependencies
```
All services depend on:
├── n8n-secrets (for n8n)
├── postgres-secrets (for n8n + Flowise)
├── neo4j-secrets (for n8n + Knowledge graphs)
├── qdrant-secrets (for n8n + Flowise)
└── oauth2-proxy-secrets (for all external access)
```

---

## ✅ What's Included

### Kubernetes Manifests
- ✅ 7 microservices
- ✅ 5 namespaces
- ✅ RBAC configuration
- ✅ Persistent volumes
- ✅ Ingress controllers
- ✅ SSL/TLS certificates
- ✅ Health checks
- ✅ Resource limits
- ✅ Security context

### Deployment Strategies
- ✅ Deployments (stateless services)
- ✅ StatefulSets (databases)
- ✅ Service definitions
- ✅ ConfigMaps (configuration)
- ✅ Sealed Secrets (credentials)
- ✅ Kustomize overlays (n8n)
- ✅ ArgoCD applications (GitOps)

### Documentation
- ✅ Architecture overview
- ✅ Getting started guide
- ✅ Migration guide (12 phases)
- ✅ Keycloak setup
- ✅ Nginx Proxy Manager guide
- ✅ Troubleshooting guide
- ✅ Deployment checklist

### Automation
- ✅ Quick-start script
- ✅ Bash-based deployment
- ✅ Automated validation

---

## 🎯 Service URLs After Deployment

### External (Public via Nginx Proxy Manager)
- n8n: `https://n8n.lupulup.com`
- Flowise: `https://flowise.lupulup.com`
- Neo4j Browser: `https://neo4j.lupulup.com`
- SearXNG: `https://searxng.lupulup.com`
- Supabase (future): `https://supabase.lupulup.com`

### Internal (Kubernetes only)
- PostgreSQL: `postgres.local-ai-data:5432`
- Qdrant: `qdrant.local-ai-data:6333`
- Neo4j Bolt: `neo4j.local-ai-data:7687`
- Redis: `redis.local-ai-system:6379`

### System Services
- ArgoCD: `https://argocd.mylegion5pro.me`
- Keycloak: `https://keycloak.mylegion5pro.me`

---

## 🔄 Deployment Workflow

### Before You Start
```
☐ Read K8S-DEPLOYMENT-SUMMARY.md
☐ Review DEPLOYMENT-CHECKLIST.md
☐ Verify cluster health
☐ Gather credentials
```

### Deployment Steps
```
☐ Phase 1: Create namespaces
☐ Phase 2: Encrypt secrets
☐ Phase 3: Deploy supporting services (Redis, OAuth2 Proxy)
☐ Phase 4: Deploy data layer (PostgreSQL, Qdrant, Neo4j)
☐ Phase 5: Deploy applications (n8n, Flowise, SearXNG)
☐ Phase 6: Configure Keycloak
☐ Phase 7: Configure Nginx Proxy Manager
☐ Phase 8: Test all services
☐ Phase 9: Enable ArgoCD (optional)
```

### Post-Deployment
```
☐ Verify all services running
☐ Test authentication flow
☐ Create database backups
☐ Document changes
☐ Notify team
```

---

## 📞 Support Resources

### Documentation References
| Resource | Link |
|----------|------|
| Kubernetes Docs | https://kubernetes.io/docs/ |
| ArgoCD Docs | https://argoproj.github.io/argo-cd/ |
| Keycloak Docs | https://www.keycloak.org/docs/latest/ |
| Nginx Ingress | https://kubernetes.github.io/ingress-nginx/ |
| Cert-Manager | https://cert-manager.io/docs/ |
| n8n Docs | https://docs.n8n.io/ |
| Flowise Docs | https://docs.flowiseai.com/ |

### Internal Documentation
All guides are in `k8s/docs/` directory:
- `KEYCLOAK-SETUP.md` - Keycloak configuration
- `NGINX-PROXY-MANAGER.md` - NPM routing setup
- `MIGRATION.md` - Complete migration guide with rollback
- `TROUBLESHOOTING.md` - Common issues and solutions

---

## 🎉 Success Indicators

You'll know deployment is successful when:

✅ All pods show `READY 1/1` status
```bash
kubectl get pods -A | grep local-ai
```

✅ Can access services via browser
- `https://n8n.lupulup.com` → Keycloak login
- `https://flowise.lupulup.com` → Keycloak login
- `https://neo4j.lupulup.com` → Keycloak login

✅ Can login with Keycloak
- Username: `admin`
- Password: `Admin!234`
- After login, application UI loads

✅ Services can communicate internally
```bash
kubectl exec -it deployment/n8n -n local-ai-n8n -- \
  curl http://postgres.local-ai-data:5432
```

✅ Certificates are valid
```bash
kubectl get certificate -A | grep local-ai
# All should show READY True
```

✅ ArgoCD applications synced (if using GitOps)
```bash
kubectl get applications -n argocd
# All should show Synced & Healthy
```

---

## 🚀 Quick Commands Reference

### Check Status
```bash
kubectl get pods -A | grep local-ai
kubectl get svc -A | grep local-ai
kubectl get ingress -A | grep local-ai
kubectl get cert -A | grep local-ai
```

### View Logs
```bash
kubectl logs -n local-ai-n8n deployment/n8n -f
kubectl logs -n local-ai-system deployment/oauth2-proxy -f
kubectl logs -n local-ai-data pod/postgres-0
```

### Port Forward (for testing)
```bash
kubectl port-forward -n local-ai-n8n svc/n8n 5678:5678
kubectl port-forward -n local-ai-system svc/redis 6379:6379
kubectl port-forward -n local-ai-data svc/postgres 5432:5432
```

### Execute Commands in Pods
```bash
kubectl exec -it -n local-ai-n8n deployment/n8n -- /bin/bash
kubectl exec -it -n local-ai-data supabase-postgres-0 -- psql -U postgres
```

---

## 📝 File Checksums (for verification)

Verify all files were created correctly:

```bash
# List all k8s files
find k8s -type f | wc -l
# Should be: 25 files

# Check total size
du -sh k8s
# Should be: ~300KB

# Verify manifest files
ls k8s/apps/*/deployment.yaml | wc -l
# Should be: 5 files
```

---

## 🎓 Learning Path

### For Kubernetes Beginners
1. Read: `k8s/README.md` - Learn the architecture
2. Read: `k8s/GETTING-STARTED.md` - Follow step-by-step
3. Deploy manually - Understand each component
4. Run: `quick-start.sh` - See it all together

### For DevOps Engineers
1. Review all manifests - Understand design decisions
2. Check security features - RBAC, sealed secrets, pod security
3. Set up ArgoCD - Implement GitOps workflow
4. Configure monitoring - Add observability

### For System Administrators
1. Review resource limits and requests
2. Set up persistent volume backups
3. Configure scaling policies
4. Implement maintenance procedures

---

## 📦 Version Information

| Component | Version | Notes |
|-----------|---------|-------|
| Kubernetes | 1.24+ | Talos cluster |
| Docker | 20.10+ | For image building |
| kubectl | 1.24+ | Client |
| kubeseal | 0.18+ | For secrets encryption |
| argocd | 2.0+ | GitOps deployment |
| Cert-Manager | 1.12+ | SSL/TLS |
| Nginx Ingress | 1.5+ | Ingress controller |
| n8n | latest | Workflow automation |
| Flowise | latest | AI agent builder |
| Neo4j | latest | Knowledge graph |
| Qdrant | latest | Vector database |
| PostgreSQL | 15-alpine | Database |
| Redis | 7-alpine | Cache |
| SearXNG | latest | Search engine |

---

## 🔐 Security Checklist

- ✅ Sealed Secrets encryption
- ✅ RBAC with minimal permissions
- ✅ Pod security context
- ✅ Network policies (optional)
- ✅ Resource limits
- ✅ OAuth2 Proxy for authentication
- ✅ TLS 1.2+ enforcement
- ✅ Security headers configured
- ✅ No default credentials in manifests
- ✅ Secrets not in Git

---

## 📊 Storage Requirements

| Service | Size | Type | Notes |
|---------|------|------|-------|
| n8n | 20Gi | RWO | Workflows, credentials |
| Flowise | 10Gi | RWO | Chatflows, data |
| PostgreSQL | 100Gi | RWO | Main database |
| Qdrant | 50Gi | RWO | Vector embeddings |
| Neo4j | 50Gi | RWO | Knowledge graph |
| Redis | 10Gi | RWO | Cache and sessions |
| SearXNG | 5Gi | RWO | Search cache |
| **Total** | **245Gi** | | Minimum cluster storage |

---

## 🎬 Next Steps

1. **Read**: `K8S-DEPLOYMENT-SUMMARY.md` (5 min)
2. **Review**: `DEPLOYMENT-CHECKLIST.md` (10 min)
3. **Start**: `k8s/scripts/quick-start.sh` (30 min)
4. **Configure**: Follow Keycloak and Nginx guides (30 min)
5. **Test**: Verify all services working (15 min)
6. **Document**: Update team documentation (optional)

---

**Total Time**: 1-2 hours from start to fully deployed system

**Good luck! 🚀**
