# Complete Migration Guide: Docker Compose → Kubernetes + ArgoCD

This guide walks you through migrating the Local AI Package from Docker Compose to a Kubernetes deployment with ArgoCD and Keycloak SSO.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Pre-Migration Checklist](#pre-migration-checklist)
3. [Phase 1: Prepare Git Repository](#phase-1-prepare-git-repository)
4. [Phase 2: Encrypt Secrets](#phase-2-encrypt-secrets)
5. [Phase 3: Deploy Supporting Services](#phase-3-deploy-supporting-services)
6. [Phase 4: Deploy Data Layer](#phase-4-deploy-data-layer)
7. [Phase 5: Deploy Applications](#phase-5-deploy-applications)
8. [Phase 6: Configure Keycloak](#phase-6-configure-keycloak)
9. [Phase 7: Update Nginx Proxy Manager](#phase-7-update-nginx-proxy-manager)
10. [Phase 8: Testing & Validation](#phase-8-testing--validation)
11. [Phase 9: Cleanup Docker Compose](#phase-9-cleanup-docker-compose)
12. [Rollback Procedure](#rollback-procedure)

## Prerequisites

### Required Tools
```bash
# Kubernetes CLI
kubectl version --client

# Talos CLI
talosctl --version

# Helm (optional, for package management)
helm version

# Sealed Secrets CLI (for secret encryption)
# Install: https://github.com/bitnami-labs/sealed-secrets/releases
kubeseal --version

# Git
git --version
```

### Access Requirements
- SSH access to Talos control plane
- ArgoCD admin credentials
- Keycloak admin access
- Nginx Proxy Manager access
- Git repository access (GitHub, GitLab, etc.)

### Cluster Requirements
```bash
# Verify cluster is healthy
kubectl get nodes
# Output: Should show all nodes as Ready

# Verify ArgoCD is running
kubectl get pods -n argocd
# Output: argocd-* pods should be Running

# Verify cert-manager is installed
kubectl get pods -n cert-manager
# Output: cert-manager pods should be Running

# Verify Nginx Ingress Controller
kubectl get pods -n ingress-nginx
# Output: ingress-nginx-controller pods should be Running
```

## Pre-Migration Checklist

- [ ] Backup Docker Compose volumes
- [ ] Create database exports
- [ ] Test Keycloak connectivity
- [ ] Test ArgoCD connectivity
- [ ] Verify Nginx Proxy Manager is running
- [ ] Ensure sufficient cluster storage
- [ ] Review service dependencies
- [ ] Document current Docker Compose configuration
- [ ] Plan maintenance window (optional, but recommended)

## Phase 1: Prepare Git Repository

### Option A: Create Separate Repository

```bash
# Create new repository
mkdir ~/local-ai-k8s
cd ~/local-ai-k8s
git init
git remote add origin https://github.com/YOUR-USERNAME/local-ai-k8s.git

# Copy Kubernetes manifests
cp -r /path/to/local-ai-packaged/k8s/* .

# Commit
git add .
git commit -m "Initial K8s manifests for Local AI"
git push -u origin main
```

### Option B: Use Existing Repository

```bash
# In local-ai-packaged directory
cd ~/local-ai-packaged

# Ensure k8s directory is tracked
git add k8s/
git commit -m "Add Kubernetes manifests for App of Apps migration"
git push origin main
```

### Update ArgoCD App Reference

Edit `k8s/argocd/app-of-apps.yaml`:

```yaml
spec:
  source:
    repoURL: https://github.com/YOUR-USERNAME/local-ai-packaged.git  # Your repo URL
    targetRevision: HEAD
    path: k8s/apps  # Path to apps directory
```

## Phase 2: Encrypt Secrets

### Step 1: Get Sealed Secrets Public Key

```bash
# Verify sealed-secrets controller is running
kubectl get pods -n kube-system | grep sealed

# Get the public key
kubectl get secret -n kube-system \
  -l sealedsecrets.bitnami.com/status=active \
  -o jsonpath='{.items[0].data.tls\.crt}' | \
  base64 -d > /tmp/sealed-secrets-pub.crt
```

### Step 2: Encrypt Each Service Secret

```bash
# For n8n
cd k8s/apps/n8n

# Edit secret.yaml with actual values
vi secret.yaml

# Encrypt the secret
kubeseal -f secret.yaml -w secret-sealed.yaml

# Verify sealed secret was created
cat secret-sealed.yaml

# Push to Git
git add secret-sealed.yaml
git commit -m "Add sealed secrets for n8n"
```

Repeat for each service:
- `k8s/apps/flowise/secret.yaml`
- `k8s/apps/postgres/secret.yaml`
- `k8s/apps/neo4j/secret.yaml`
- `k8s/apps/qdrant/secret.yaml`
- `k8s/apps/_common/oauth2-proxy-sealed-secret.yaml`

### Step 3: Verify Secrets are Sealed

```bash
# Check that secret-sealed.yaml files exist
find k8s -name "*sealed*.yaml" -type f

# Verify sealed-secrets controller can decrypt
kubectl apply -f k8s/apps/n8n/secret-sealed.yaml --dry-run=client

# Should succeed without errors
```

### Step 4: Remove Unencrypted Secrets from Git

```bash
# Remove secret.yaml (unencrypted) from Git
git rm --cached k8s/apps/*/secret.yaml
git rm --cached k8s/apps/_common/oauth2-proxy-secrets.yaml

# Add to .gitignore
echo "*/secret.yaml" >> .gitignore
echo "!*/secret-sealed.yaml" >> .gitignore

git add .gitignore
git commit -m "Remove unencrypted secrets from Git"
```

## Phase 3: Deploy Supporting Services

### Step 1: Create Namespaces

```bash
kubectl apply -f k8s/apps/_common/namespace.yaml

# Verify
kubectl get ns | grep local-ai
```

### Step 2: Deploy Redis

```bash
kubectl apply -f k8s/apps/redis/deployment.yaml

# Wait for pod to be ready
kubectl get pods -n local-ai-system -w

# Verify Redis is accessible
kubectl port-forward -n local-ai-system svc/redis 6379:6379 &
redis-cli PING
# Output: PONG
```

### Step 3: Deploy OAuth2 Proxy

```bash
# Apply the sealed secret first
kubectl apply -f k8s/apps/_common/oauth2-proxy-sealed-secret.yaml

# Deploy OAuth2 Proxy
kubectl apply -f k8s/apps/_common/oauth2-proxy-base.yaml

# Wait for deployment
kubectl get deploy -n local-ai-system -w

# Check logs
kubectl logs -n local-ai-system deployment/oauth2-proxy
```

## Phase 4: Deploy Data Layer

### Step 1: Deploy PostgreSQL

```bash
# Apply sealed secret
kubectl apply -f k8s/apps/postgres/secret.yaml

# Deploy StatefulSet
kubectl apply -f k8s/apps/postgres/statefulset.yaml

# Wait for pod to be ready (can take 2-3 minutes)
kubectl get pods -n local-ai-data -w

# Verify database connectivity
kubectl exec -it -n local-ai-data supabase-postgres-0 -- \
  psql -U postgres -d postgres -c "SELECT version();"
```

### Step 2: Deploy Qdrant

```bash
# Apply sealed secret
kubectl apply -f k8s/apps/qdrant/secret.yaml

# Deploy StatefulSet
kubectl apply -f k8s/apps/qdrant/statefulset.yaml

# Wait for pod to be ready
kubectl get pods -n local-ai-data -w

# Verify Qdrant is accessible
kubectl port-forward -n local-ai-data svc/qdrant-client 6333:6333 &
curl http://localhost:6333/health
```

### Step 3: Deploy Neo4j

```bash
# Apply sealed secret
kubectl apply -f k8s/apps/neo4j/secret.yaml

# Deploy StatefulSet
kubectl apply -f k8s/apps/neo4j/statefulset.yaml

# Wait for pod to be ready (can take 3-5 minutes)
kubectl get pods -n local-ai-data -w

# Verify Neo4j is accessible
kubectl port-forward -n local-ai-data svc/neo4j-client 7474:7474 &
curl http://localhost:7474
```

## Phase 5: Deploy Applications

### Step 1: Deploy n8n

```bash
# Apply sealed secret
kubectl apply -f k8s/apps/n8n/secret-sealed.yaml

# Deploy using Kustomize
kubectl apply -k k8s/apps/n8n/

# Wait for pod to be ready
kubectl get pods -n local-ai-n8n -w

# Check logs
kubectl logs -n local-ai-n8n deployment/n8n
```

### Step 2: Deploy Flowise

```bash
# Apply sealed secret
kubectl apply -f k8s/apps/flowise/secret.yaml

# Deploy
kubectl apply -f k8s/apps/flowise/deployment.yaml

# Wait for pod to be ready
kubectl get pods -n local-ai-flowise -w
```

### Step 3: Deploy SearXNG

```bash
kubectl apply -f k8s/apps/searxng/deployment.yaml

# Wait for pod to be ready
kubectl get pods -n local-ai-search -w
```

## Phase 6: Configure Keycloak

### Step 1: Create OAuth2 Client

Follow the detailed guide: `docs/KEYCLOAK-SETUP.md`

Key steps:
1. Create `oauth2-proxy` client in Keycloak
2. Set redirect URIs for all services
3. Copy client secret to sealed secret
4. Deploy updated sealed secret

### Step 2: Test OAuth2 Flow

```bash
# Port-forward to a service
kubectl port-forward -n local-ai-n8n svc/n8n 5678:5678 &

# Open browser and visit http://localhost:5678
# Should redirect to Keycloak login
```

### Step 3: Verify User Access

Test with each user:
- admin: Access to all services
- developer: Access to dev services
- explorer: Read-only access

## Phase 7: Update Nginx Proxy Manager

Follow the detailed guide: `docs/NGINX-PROXY-MANAGER.md`

Key steps:
1. Identify Kubernetes Ingress Controller IP
2. Create proxy hosts for each service
3. Configure SSL certificates
4. Update DNS records in Cloudflare

Example:
```
n8n.lupulup.com → https → 192.168.1.30:443 (K8s Ingress IP)
```

## Phase 8: Testing & Validation

### Test Each Service

```bash
# Test n8n
curl https://n8n.lupulup.com -k

# Test Flowise
curl https://flowise.lupulup.com -k

# Test Neo4j
curl https://neo4j.lupulup.com -k

# Test SearXNG
curl https://searxng.lupulup.com -k
```

### Test with Browser

1. Open `https://n8n.lupulup.com`
2. Should redirect to Keycloak
3. Login with test user
4. Should be redirected back to n8n
5. Verify you're authenticated

### Verify Service Connectivity

```bash
# From n8n pod, test connection to other services
kubectl exec -it -n local-ai-n8n deployment/n8n -- bash

# Inside the pod:
curl http://redis.local-ai-system:6379 -v
curl http://qdrant.local-ai-data:6333/health
curl http://neo4j.local-ai-data:7474/ -u neo4j:PASSWORD
```

### Check ArgoCD Sync Status

```bash
# Login to ArgoCD
argocd login argocd.mylegion5pro.me --username admin --password <PASSWORD>

# Check application status
argocd app list

# Sync individual application if needed
argocd app sync local-ai-n8n
```

## Phase 9: Cleanup Docker Compose

Only perform this step after verifying all K8s services are working!

### Step 1: Backup Docker Volumes

```bash
# On the host running Docker Compose
cd /path/to/local-ai-packaged

# Backup all volumes
docker-compose exec n8n tar czf /tmp/n8n-backup.tar.gz -C / home/node/.n8n
docker cp <container>:/tmp/n8n-backup.tar.gz ./backups/

# Backup database
docker-compose exec postgres pg_dump -U postgres > ./backups/postgres-backup.sql

# Backup Neo4j
docker-compose exec neo4j neo4j-admin dump --database=neo4j --to=/var/lib/neo4j/dumps/
```

### Step 2: Stop Docker Compose

```bash
# Stop all services
docker-compose down

# Verify they're stopped
docker-compose ps

# Remove volumes (only after backup!)
docker-compose down -v
```

### Step 3: Archive Docker Compose Files

```bash
# Archive the docker-compose setup for future reference
tar czf ./backups/docker-compose-archive-$(date +%Y%m%d).tar.gz \
  docker-compose.yml \
  docker-compose.override.*.yml \
  .env \
  Caddyfile \
  start_services.py \
  n8n/ \
  flowise/ \
  searxng/ \
  neo4j/

# Store the archive safely
```

## Rollback Procedure

If you need to rollback to Docker Compose:

### Option 1: Quick Rollback (if you have recent backup)

```bash
# Stop Kubernetes applications
kubectl delete -f k8s/argocd/applications.yaml

# Restore Docker Compose from backup
docker-compose down -v
# Restore volumes from backup
# Re-apply docker-compose

docker-compose up -d
```

### Option 2: Gradual Rollback

Keep Docker Compose running in parallel:

```bash
# Run Docker Compose on different port
docker-compose --file docker-compose.yml -p legacy up -d

# Keep both systems running while validating
# Once validated, remove one system
```

## Post-Migration Checklist

- [ ] All services are accessible
- [ ] Users can login via Keycloak
- [ ] n8n workflows are working
- [ ] Flowise agents are working
- [ ] Database connections verified
- [ ] Search functionality (SearXNG) working
- [ ] API endpoints responding
- [ ] SSL certificates are valid
- [ ] ArgoCD applications synced
- [ ] Monitoring/alerting configured
- [ ] Backups are working
- [ ] Documentation updated

## Troubleshooting Common Issues

### Service Not Responding

```bash
# Check pod status
kubectl get pods -n <namespace>

# Check logs
kubectl logs -n <namespace> deployment/<service>

# Describe pod for events
kubectl describe pod -n <namespace> <pod-name>
```

### Database Connection Errors

```bash
# Test connection from pod
kubectl exec -it -n <namespace> deployment/<service> -- bash
psql -h postgres.local-ai-data -U postgres -d postgres
```

### SSL Certificate Issues

```bash
# Check certificate status
kubectl get certificates -A

# Check certificate details
kubectl describe cert -n <namespace> <cert-name>

# Renew certificate if expired
kubectl delete secret <cert-secret> -n <namespace>
```

### OAuth2/Keycloak Issues

```bash
# Check OAuth2 Proxy logs
kubectl logs -n local-ai-system deployment/oauth2-proxy

# Verify Keycloak connectivity
kubectl exec -it -n local-ai-system deployment/oauth2-proxy -- \
  curl https://keycloak.mylegion5pro.me/realms/homelab/.well-known/openid-configuration
```

## References

- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [ArgoCD Documentation](https://argoproj.github.io/argo-cd/)
- [OAuth2 Proxy Documentation](https://oauth2-proxy.github.io/oauth2-proxy/)
- [Keycloak Documentation](https://www.keycloak.org/docs/latest/)
- [Sealed Secrets Documentation](https://github.com/bitnami-labs/sealed-secrets)

## Support

For issues during migration:
1. Check `docs/TROUBLESHOOTING.md`
2. Review service logs: `kubectl logs -f <pod>`
3. Check ArgoCD sync status
4. Verify network connectivity between services
5. Review Keycloak logs for auth issues
