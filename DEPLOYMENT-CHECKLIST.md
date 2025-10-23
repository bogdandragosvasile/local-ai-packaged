# Local AI Kubernetes Deployment Checklist

Use this checklist to ensure a smooth migration from Docker Compose to Kubernetes with ArgoCD and Keycloak SSO.

## Pre-Deployment Phase

### Prerequisites & Access
- [ ] Talos Kubernetes cluster is running and healthy
  ```bash
  kubectl get nodes
  # All nodes should show STATUS: Ready
  ```
- [ ] Can access Kubernetes cluster via kubectl
  ```bash
  kubectl cluster-info
  ```
- [ ] ArgoCD is installed and accessible
  ```bash
  kubectl get pods -n argocd | grep argocd-server
  ```
- [ ] Cert-manager is installed
  ```bash
  kubectl get pods -n cert-manager
  ```
- [ ] Nginx Ingress Controller is installed
  ```bash
  kubectl get svc -n ingress-nginx
  ```
- [ ] Sealed Secrets controller is installed
  ```bash
  kubectl get deploy -n kube-system sealed-secrets-controller
  ```
- [ ] Keycloak is running with `homelab` realm
  - [ ] Can access `https://keycloak.mylegion5pro.me`
  - [ ] Can login to admin console
  - [ ] Realm `homelab` exists with test users

### Git Repository Setup
- [ ] GitHub/GitLab account ready
- [ ] Git repository created or ready
- [ ] Local git repository cloned
  ```bash
  git clone <your-repo-url>
  cd local-ai-packaged
  ```
- [ ] Can push to repository
  ```bash
  git push origin main
  ```

### Tools & Access
- [ ] kubectl CLI installed and working
- [ ] kubeseal CLI installed (for secrets encryption)
- [ ] argocd CLI installed (optional but recommended)
- [ ] Nginx Proxy Manager accessible (admin panel)
  - [ ] Know the IP addresses: 192.168.1.11, 192.168.1.12
- [ ] Cloudflare/NoIP DNS access
  - [ ] Can create A records
  - [ ] Can modify existing records

### Documentation Review
- [ ] Read `k8s/GETTING-STARTED.md` (15 mins)
- [ ] Read `k8s/README.md` (10 mins)
- [ ] Understand the architecture diagram
- [ ] Know the service URLs and domains

---

## Phase 1: Prepare Kubernetes Cluster

### Create Namespaces
- [ ] Namespaces created
  ```bash
  kubectl apply -f k8s/apps/_common/namespace.yaml
  ```
- [ ] Verify namespaces exist
  ```bash
  kubectl get ns | grep local-ai
  ```
  Should see:
  - local-ai-system
  - local-ai-n8n
  - local-ai-flowise
  - local-ai-data
  - local-ai-search

### Storage Verification
- [ ] Storage class `local-path` exists
  ```bash
  kubectl get storageclass
  ```
- [ ] If not, create it:
  ```bash
  kubectl apply -f k8s/storage-class.yaml
  ```

---

## Phase 2: Encrypt Secrets

### Gather Credentials
- [ ] PostgreSQL root password: _______________
- [ ] Neo4j password: _______________
- [ ] Qdrant API key: _______________
- [ ] n8n encryption key (32 bytes): _______________
- [ ] n8n JWT secret: _______________

### Keycloak Client Setup
- [ ] Log into Keycloak admin console
- [ ] Create OAuth2 client: `oauth2-proxy`
  - [ ] Set to `confidential` access type
  - [ ] Add redirect URIs:
    - [ ] `https://n8n.lupulup.com/oauth2/callback`
    - [ ] `https://flowise.lupulup.com/oauth2/callback`
    - [ ] `https://neo4j.lupulup.com/oauth2/callback`
    - [ ] `https://searxng.lupulup.com/oauth2/callback`
    - [ ] `https://supabase.lupulup.com/oauth2/callback`
  - [ ] Copy client secret: _______________

### Encrypt Secrets
- [ ] Edit each secret.yaml with actual values:
  - [ ] `k8s/apps/n8n/secret.yaml`
  - [ ] `k8s/apps/postgres/secret.yaml`
  - [ ] `k8s/apps/neo4j/secret.yaml`
  - [ ] `k8s/apps/qdrant/secret.yaml`
  - [ ] `k8s/apps/flowise/secret.yaml`
  - [ ] `k8s/apps/_common/oauth2-proxy-secrets.yaml`

- [ ] Encrypt each secret:
  ```bash
  kubeseal -f k8s/apps/n8n/secret.yaml -w k8s/apps/n8n/secret-sealed.yaml
  kubeseal -f k8s/apps/postgres/secret.yaml -w k8s/apps/postgres/secret-sealed.yaml
  # ... repeat for all services
  ```

- [ ] Verify sealed secrets were created
  ```bash
  ls k8s/apps/*/secret-sealed.yaml
  ```

### Secure Git Repository
- [ ] Add unencrypted secrets to .gitignore
  ```bash
  echo "*/secret.yaml" >> .gitignore
  echo "!*/secret-sealed.yaml" >> .gitignore
  ```

- [ ] Verify unencrypted secrets are NOT in Git
  ```bash
  git status
  # Should not show secret.yaml files
  ```

- [ ] Commit sealed secrets to Git
  ```bash
  git add k8s/ .gitignore
  git commit -m "Add encrypted secrets and k8s manifests"
  git push origin main
  ```

---

## Phase 3: Deploy Supporting Services

### Deploy Redis
- [ ] Apply Redis manifests
  ```bash
  kubectl apply -f k8s/apps/redis/deployment.yaml
  ```

- [ ] Verify Redis is running
  ```bash
  kubectl get pods -n local-ai-system -l app=redis -w
  # Wait for READY: 1/1
  ```

### Deploy OAuth2 Proxy
- [ ] Verify sealed secret exists
  ```bash
  kubectl get secret -n local-ai-system oauth2-proxy-sealed-secret
  ```

- [ ] Apply OAuth2 Proxy manifests
  ```bash
  kubectl apply -f k8s/apps/_common/oauth2-proxy-base.yaml
  ```

- [ ] Verify OAuth2 Proxy is running
  ```bash
  kubectl get pods -n local-ai-system -l app=oauth2-proxy -w
  # Wait for READY: 2/2 (2 replicas)
  ```

- [ ] Check OAuth2 Proxy logs
  ```bash
  kubectl logs -n local-ai-system deployment/oauth2-proxy
  # Should show successful startup
  ```

---

## Phase 4: Deploy Data Layer

### Deploy PostgreSQL
- [ ] Apply PostgreSQL manifests
  ```bash
  kubectl apply -f k8s/apps/postgres/statefulset.yaml
  ```

- [ ] Wait for PostgreSQL to be ready (may take 3-5 minutes)
  ```bash
  kubectl get pods -n local-ai-data -l app=postgres -w
  # Wait for READY: 1/1
  ```

- [ ] Verify database is accessible
  ```bash
  kubectl exec -it -n local-ai-data supabase-postgres-0 -- \
    psql -U postgres -c "SELECT version();"
  ```

### Deploy Qdrant
- [ ] Apply Qdrant manifests
  ```bash
  kubectl apply -f k8s/apps/qdrant/statefulset.yaml
  ```

- [ ] Wait for Qdrant to be ready
  ```bash
  kubectl get pods -n local-ai-data -l app=qdrant -w
  # Wait for READY: 1/1
  ```

- [ ] Verify Qdrant health
  ```bash
  kubectl port-forward -n local-ai-data svc/qdrant-client 6333:6333 &
  curl http://localhost:6333/health
  # Should return: {"status":"ok"}
  ```

### Deploy Neo4j
- [ ] Apply Neo4j manifests
  ```bash
  kubectl apply -f k8s/apps/neo4j/statefulset.yaml
  ```

- [ ] Wait for Neo4j to be ready (may take 3-5 minutes)
  ```bash
  kubectl get pods -n local-ai-data -l app=neo4j -w
  # Wait for READY: 1/1
  ```

- [ ] Verify Neo4j health
  ```bash
  kubectl port-forward -n local-ai-data svc/neo4j-client 7474:7474 &
  curl http://localhost:7474/
  # Should return Neo4j HTML page
  ```

---

## Phase 5: Deploy Applications

### Deploy n8n
- [ ] Apply n8n manifests using Kustomize
  ```bash
  kubectl apply -k k8s/apps/n8n/
  ```

- [ ] Verify n8n is running
  ```bash
  kubectl get pods -n local-ai-n8n -w
  # Wait for READY: 1/1
  ```

- [ ] Check n8n logs
  ```bash
  kubectl logs -n local-ai-n8n deployment/n8n
  # Should show "Server is now ready"
  ```

### Deploy Flowise
- [ ] Apply Flowise manifests
  ```bash
  kubectl apply -f k8s/apps/flowise/deployment.yaml
  ```

- [ ] Verify Flowise is running
  ```bash
  kubectl get pods -n local-ai-flowise -w
  # Wait for READY: 1/1
  ```

### Deploy SearXNG
- [ ] Apply SearXNG manifests
  ```bash
  kubectl apply -f k8s/apps/searxng/deployment.yaml
  ```

- [ ] Verify SearXNG is running
  ```bash
  kubectl get pods -n local-ai-search -w
  # Wait for READY: 1/1
  ```

### Verify All Pods
- [ ] All pods show READY 1/1
  ```bash
  kubectl get pods -A | grep local-ai
  # All should show: READY 1/1, STATUS Running
  ```

---

## Phase 6: Verify Networking & Certificates

### Check Ingress
- [ ] Ingress endpoints created
  ```bash
  kubectl get ingress -A | grep local-ai
  ```

- [ ] Ingress has CLASS: nginx
- [ ] All services listed in Ingress

### Check Certificates
- [ ] Certificates were created
  ```bash
  kubectl get certificate -A | grep local-ai
  ```

- [ ] Certificates show STATUS: True, READY: True
  ```bash
  kubectl get certificate -n local-ai-n8n -o wide
  ```

- [ ] Certificate secrets exist
  ```bash
  kubectl get secret -A | grep tls | grep local-ai
  ```

---

## Phase 7: Configure DNS & Nginx Proxy Manager

### Get Kubernetes Ingress IP
- [ ] Identify Ingress Controller external IP
  ```bash
  kubectl get svc -n ingress-nginx ingress-nginx-controller
  # Note the EXTERNAL-IP (e.g., 192.168.1.30)
  ```

### Configure Nginx Proxy Manager

#### Create Proxy Hosts
- [ ] **n8n proxy host**
  - [ ] Domain: `n8n.lupulup.com`
  - [ ] Forward to: `https://192.168.1.30:443`
  - [ ] Enable SSL certificate
  - [ ] Force SSL: ON

- [ ] **Flowise proxy host**
  - [ ] Domain: `flowise.lupulup.com`
  - [ ] Forward to: `https://192.168.1.30:443`
  - [ ] Enable SSL certificate
  - [ ] Force SSL: ON

- [ ] **Neo4j proxy host**
  - [ ] Domain: `neo4j.lupulup.com`
  - [ ] Forward to: `https://192.168.1.30:443`
  - [ ] Enable SSL certificate
  - [ ] Force SSL: ON

- [ ] **SearXNG proxy host**
  - [ ] Domain: `searxng.lupulup.com`
  - [ ] Forward to: `https://192.168.1.30:443`
  - [ ] Enable SSL certificate
  - [ ] Force SSL: ON

### Configure DNS Records

#### Cloudflare (lupulup.com)
- [ ] n8n A record → 192.168.1.11 (or 192.168.1.12)
- [ ] flowise A record → 192.168.1.11
- [ ] neo4j A record → 192.168.1.11
- [ ] searxng A record → 192.168.1.11
- [ ] supabase A record → 192.168.1.11 (if deploying)
- [ ] All records proxied through Cloudflare (⚡ Proxied)

#### NoIP (mylegion5pro.me)
- [ ] Main domain A record → 192.168.1.11
- [ ] Verify DNS propagation (may take 5-15 mins)
  ```bash
  nslookup n8n.lupulup.com
  # Should resolve to Cloudflare IP
  ```

---

## Phase 8: Test Services

### Test HTTP/HTTPS Connectivity
- [ ] Test n8n endpoint
  ```bash
  curl -v https://n8n.lupulup.com
  # Should get 302 redirect to Keycloak
  ```

- [ ] Test Flowise endpoint
  ```bash
  curl -v https://flowise.lupulup.com
  ```

- [ ] Test Neo4j endpoint
  ```bash
  curl -v https://neo4j.lupulup.com
  ```

- [ ] Test SearXNG endpoint
  ```bash
  curl -v https://searxng.lupulup.com
  ```

### Test in Browser
- [ ] Open `https://n8n.lupulup.com` in browser
  - [ ] Page loads (no certificate errors)
  - [ ] Redirected to Keycloak login
  - [ ] Can see Keycloak login form

- [ ] Login with Keycloak credentials
  - [ ] Username: `admin`
  - [ ] Password: `Admin!234`
  - [ ] Successfully authenticated
  - [ ] Redirected back to n8n
  - [ ] n8n UI loads completely

- [ ] Repeat for other services:
  - [ ] `https://flowise.lupulup.com`
  - [ ] `https://neo4j.lupulup.com`
  - [ ] `https://searxng.lupulup.com`

### Test Service Connectivity
- [ ] n8n can connect to PostgreSQL
  ```bash
  kubectl logs -n local-ai-n8n deployment/n8n | grep -i "database\|postgres"
  ```

- [ ] n8n can connect to Qdrant
  ```bash
  kubectl logs -n local-ai-n8n deployment/n8n | grep -i "qdrant"
  ```

- [ ] n8n can connect to Neo4j
  ```bash
  kubectl logs -n local-ai-n8n deployment/n8n | grep -i "neo4j"
  ```

---

## Phase 9: Deploy with ArgoCD (Optional - GitOps)

### Set Up ArgoCD Applications
- [ ] Update repository URL in app-of-apps.yaml
  ```bash
  vi k8s/argocd/app-of-apps.yaml
  # Change: repoURL: https://github.com/YOUR-USERNAME/local-ai-packaged.git
  ```

- [ ] Commit updated app-of-apps.yaml
  ```bash
  git add k8s/argocd/app-of-apps.yaml
  git commit -m "Configure ArgoCD for GitOps"
  git push origin main
  ```

- [ ] Apply App of Apps
  ```bash
  kubectl apply -f k8s/argocd/app-of-apps.yaml
  ```

- [ ] Verify ArgoCD applications created
  ```bash
  kubectl get application -n argocd
  # Should see multiple applications
  ```

- [ ] Check ArgoCD dashboard
  ```bash
  # Login to: https://argocd.mylegion5pro.me
  # All applications should show as "Synced" and "Healthy"
  ```

---

## Phase 10: Final Verification

### Overall Health Check
- [ ] All pods running
  ```bash
  kubectl get pods -A | grep local-ai
  # All should show: Ready 1/1, Status Running
  ```

- [ ] All services accessible
  - [ ] n8n: ✅
  - [ ] Flowise: ✅
  - [ ] Neo4j: ✅
  - [ ] SearXNG: ✅

- [ ] All databases functional
  - [ ] PostgreSQL: ✅
  - [ ] Qdrant: ✅
  - [ ] Neo4j: ✅
  - [ ] Redis: ✅

- [ ] Keycloak authentication working
  - [ ] Can login with admin account: ✅
  - [ ] Can login with developer account: ✅
  - [ ] Can login with explorer account: ✅

- [ ] SSL certificates valid
  - [ ] No certificate warnings in browser: ✅
  - [ ] All domains have valid certs: ✅

### Performance Baseline
- [ ] Record current resource usage
  ```bash
  kubectl top nodes
  kubectl top pods -A
  ```

- [ ] Document baseline response times
  - [ ] n8n response time: _______ ms
  - [ ] Flowise response time: _______ ms
  - [ ] Neo4j response time: _______ ms

---

## Phase 11: Post-Deployment Configuration

### Backup Configuration
- [ ] Create database backups
  ```bash
  kubectl exec -n local-ai-data supabase-postgres-0 -- \
    pg_dump -U postgres > /backup/postgres.sql
  ```

- [ ] Document backup procedure
- [ ] Test backup restoration

### Monitoring Setup
- [ ] Set up alerting (optional)
- [ ] Configure log aggregation
- [ ] Set up metrics collection

### Documentation
- [ ] Document any custom configurations
- [ ] Update service access instructions
- [ ] Share access credentials securely with team

---

## Phase 12: Optional Cleanup (Only After Validation)

### Remove Docker Compose (if keeping both systems)
- [ ] [ SKIP FOR NOW - keep Docker Compose as fallback ]

### Archive Docker Compose Setup
- [ ] Backup docker-compose setup
  ```bash
  tar czf ~/backup/docker-compose-archive-$(date +%Y%m%d).tar.gz \
    docker-compose.yml \
    docker-compose.override*.yml \
    .env \
    Caddyfile
  ```

---

## Deployment Completion

### Final Status
- [ ] All 7 services deployed and running
- [ ] All users can access via SSO
- [ ] Databases synchronized
- [ ] Backups configured
- [ ] ArgoCD managing deployments (optional)

### Team Notification
- [ ] Team informed of new URLs
- [ ] Access credentials shared
- [ ] Documentation distributed
- [ ] Training session scheduled (if needed)

### Sign-Off
- **Deployed by**: _________________
- **Date**: _________________
- **Approved by**: _________________
- **Notes**: _________________________________________

---

## Rollback Procedure (If Needed)

If issues arise during deployment:

1. [ ] Document issue
2. [ ] Check `k8s/docs/TROUBLESHOOTING.md`
3. [ ] If unresolvable:
   ```bash
   # Keep Kubernetes deployed, revert to Docker Compose
   docker-compose up -d

   # Or: Full rollback
   kubectl delete -f k8s/argocd/applications.yaml
   docker-compose up -d
   ```

4. [ ] Post-incident review
5. [ ] Update documentation

---

## Maintenance Reminders

Schedule these recurring tasks:

**Weekly**:
- [ ] Check pod health: `kubectl get pods -A`
- [ ] Monitor resource usage: `kubectl top nodes`
- [ ] Review logs for errors

**Monthly**:
- [ ] Test backup restoration
- [ ] Verify certificate expiration: `kubectl get cert -A`
- [ ] Update security patches

**Quarterly**:
- [ ] Full disaster recovery test
- [ ] Performance review
- [ ] Capacity planning

---

## Contact & Support

For issues:
1. Check: `k8s/docs/TROUBLESHOOTING.md`
2. Review logs: `kubectl logs -n <namespace> <pod>`
3. Check ArgoCD sync status
4. Contact infrastructure team

**Support Resources**:
- Kubernetes docs: https://kubernetes.io/docs/
- ArgoCD docs: https://argoproj.github.io/argo-cd/
- Keycloak docs: https://www.keycloak.org/docs/

---

**Good luck with your deployment! 🚀**
