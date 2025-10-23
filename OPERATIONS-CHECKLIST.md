# Local AI Packaged - Operations Checklist

**Quick reference for daily operations, monitoring, and maintenance.**

---

## Daily Operations

### Morning Health Check (5 minutes)

```bash
# 1. Check all pods are running
kubectl get pods -A | grep local-ai

# Expected output:
# local-ai-flowise    flowise-*                    1/1     Running
# local-ai-n8n        n8n-*                        1/1     Running
# local-ai-data       neo4j-0                      1/1     Running
# local-ai-data       qdrant-0                     1/1     Running
# local-ai-data       supabase-postgres-0          1/1     Running
# local-ai-search     searxng-*                    1/1     Running
# local-ai-system     oauth2-proxy-*               2/2     Running
# local-ai-system     redis-*                      1/1     Running

# 2. Check service accessibility
for service in flowise n8n neo4j searxng; do
  curl -s -o /dev/null -w "$service: %{http_code}\n" https://$service.lupulup.com
done

# Expected: All return 200

# 3. Check certificate validity
kubectl get certificate -A | grep local-ai

# Expected: All READY=True
```

### Keycloak Access (if needed)

```bash
# Admin Console
https://keycloak.mylegion5pro.me/admin

# Homelab Realm
https://keycloak.mylegion5pro.me/realms/homelab

# OIDC Discovery
https://keycloak.mylegion5pro.me/realms/homelab/.well-known/openid-configuration
```

---

## Monitoring & Alerts

### Check Pod Resource Usage
```bash
# All local-ai pods
kubectl top pods -A | grep local-ai

# Specific namespace
kubectl top pods -n local-ai-flowise
kubectl top pods -n local-ai-n8n
kubectl top pods -n local-ai-data
```

### View Pod Logs
```bash
# Flowise logs
kubectl logs -n local-ai-flowise deployment/flowise -f

# n8n logs
kubectl logs -n local-ai-n8n deployment/n8n -f

# OAuth2 Proxy logs
kubectl logs -n local-ai-system deployment/oauth2-proxy -f

# Cert-manager logs (for certificate issues)
kubectl logs -n cert-manager deployment/cert-manager -f
```

### Check Ingress Status
```bash
# View all ingresses
kubectl get ingress -A | grep local-ai

# Describe specific ingress
kubectl describe ingress flowise -n local-ai-flowise
```

### Monitor Certificate Status
```bash
# List all certificates
kubectl get certificate -A | grep local-ai

# Check certificate details
kubectl describe certificate flowise-tls -n local-ai-flowise

# Check cert-manager status
kubectl get clusterissuer | grep letsencrypt
```

---

## Common Maintenance Tasks

### Restart a Pod
```bash
# Restart Flowise deployment
kubectl rollout restart deployment/flowise -n local-ai-flowise

# Restart n8n deployment
kubectl rollout restart deployment/n8n -n local-ai-n8n

# Restart OAuth2 Proxy
kubectl rollout restart deployment/oauth2-proxy -n local-ai-system

# Check rollout status
kubectl rollout status deployment/flowise -n local-ai-flowise
```

### Update Service Configuration (ConfigMap)
```bash
# Edit ConfigMap
kubectl edit configmap flowise-config -n local-ai-flowise

# Or patch it
kubectl patch configmap flowise-config -n local-ai-flowise \
  -p '{"data":{"FLOWISE_USERNAME":"newname"}}'

# Restart deployment to apply
kubectl rollout restart deployment/flowise -n local-ai-flowise
```

### Update Secrets
```bash
# Edit secret
kubectl edit secret flowise-secrets -n local-ai-flowise

# Or patch it
kubectl patch secret flowise-secrets -n local-ai-flowise \
  -p '{"stringData":{"KEYCLOAK_CLIENT_SECRET":"newsecret"}}'

# Restart deployment to apply
kubectl rollout restart deployment/flowise -n local-ai-flowise
```

### View Service Details
```bash
# Get service endpoints
kubectl get svc -n local-ai-flowise flowise -o wide

# Test service connectivity
kubectl exec -it -n local-ai-flowise deployment/flowise -- \
  curl -I http://flowise.local-ai-flowise:3000

# Port-forward for local testing
kubectl port-forward -n local-ai-flowise svc/flowise 3000:3000 &
# Then visit: http://localhost:3000
```

---

## Keycloak Management

### View Users
```bash
# List users in homelab realm
# Go to: https://keycloak.mylegion5pro.me/admin
# Navigate to: Manage → Users

# Current test users:
# - admin (Admin@123!)
# - developer (Dev@123!)
# - explorer (Explorer@123!)
```

### Reset User Password
```bash
# In Keycloak Admin Console:
# 1. Manage → Users → Select user
# 2. Credentials tab → [Reset password]
# 3. Enter new password
# 4. Toggle "Temporary" = OFF
# 5. Click [Set password]
```

### Create New User
```bash
# In Keycloak Admin Console:
# 1. Manage → Users → [Create new user]
# 2. Fill in details (Username, Email, First/Last Name)
# 3. Toggle "Enabled" = ON
# 4. Click [Create]
# 5. Set password in Credentials tab
# 6. Assign to group in Groups tab
```

### View Groups
```bash
# In Keycloak Admin Console:
# Manage → Groups

# Current groups:
# - admins (admin user)
# - developers (developer user)
# - explorers (explorer user)
```

### Verify OAuth2 Clients
```bash
# In Keycloak Admin Console:
# Configure → Clients

# Should see 5 clients:
# 1. flowise     (Rxw3PxcTggcYa2oN9vUDx5MSWCL0PAGQ)
# 2. n8n         (TN7cydhZ8S6FLYtRNw9jcuOoIMb6wnyW)
# 3. neo4j       (hOWJY5INqvb15chOPGO7ooLUP7eZ2voI)
# 4. searxng     (bGYFuos4ZLw3k84SbV7ggOOflGlyApU2)
# 5. oauth2-proxy(fNAht42qDGtMx5xedt7B10AXmmKJ5C8A)

# All should have:
# - Valid Redirect URIs
# - Web Origins set
# - PKCE Code Challenge = S256
```

---

## Database Maintenance

### PostgreSQL

#### Connect to Database
```bash
# Interactive psql session
kubectl exec -it -n local-ai-data supabase-postgres-0 -- \
  psql -U postgres

# Or specific database
kubectl exec -it -n local-ai-data supabase-postgres-0 -- \
  psql -U postgres -d flowise
```

#### Dump Database
```bash
# Full backup
kubectl exec -n local-ai-data supabase-postgres-0 -- \
  pg_dumpall -U postgres > postgres-backup-$(date +%Y%m%d).sql

# Specific database
kubectl exec -n local-ai-data supabase-postgres-0 -- \
  pg_dump -U postgres flowise > flowise-backup-$(date +%Y%m%d).sql
```

### Neo4j

#### Check Neo4j Status
```bash
# View Neo4j logs
kubectl logs -n local-ai-data neo4j-0

# Neo4j Browser: https://neo4j.lupulup.com
# Username: neo4j
# Password: neo4j_secure_123
```

#### Execute Cypher Query
```bash
# Port-forward to Neo4j
kubectl port-forward -n local-ai-data svc/neo4j-client 7687:7687 &

# Then use neo4j client or browser UI
```

### Qdrant

#### Check Qdrant Collections
```bash
# Port-forward
kubectl port-forward -n local-ai-data svc/qdrant-client 6333:6333 &

# List collections
curl http://localhost:6333/collections

# Get collection info
curl http://localhost:6333/collections/my_collection
```

### Redis

#### Connect to Redis
```bash
# Check Redis status
kubectl exec -it -n local-ai-system redis-c7fb49fbd-rdwxd -- redis-cli

# Common commands:
# PING                 - Test connection
# INFO                 - Server info
# KEYS *               - List all keys
# DBSIZE               - Database size
# FLUSHDB              - Clear current database (careful!)
```

---

## Troubleshooting

### Service Returning 503 (Service Unavailable)
```bash
# 1. Check pod status
kubectl get pods -n local-ai-flowise

# 2. Check pod events
kubectl describe pod -n local-ai-flowise <pod-name>

# 3. View logs
kubectl logs -n local-ai-flowise <pod-name>

# 4. Check service endpoints
kubectl get endpoints -n local-ai-flowise flowise

# 5. Restart deployment
kubectl rollout restart deployment/flowise -n local-ai-flowise
```

### Certificate Issues
```bash
# 1. Check certificate status
kubectl get certificate -n local-ai-flowise flowise-tls

# 2. Describe certificate for details
kubectl describe certificate flowise-tls -n local-ai-flowise

# 3. Check cert-manager logs
kubectl logs -n cert-manager deployment/cert-manager -f

# 4. Force cert renewal
kubectl delete certificate flowise-tls -n local-ai-flowise
# (Will be recreated by ArgoCD if using GitOps)

# 5. Check DNS propagation
nslookup flowise.lupulup.com
```

### Can't Connect to Keycloak from Pod
```bash
# 1. Test from pod
kubectl exec -it -n local-ai-flowise deployment/flowise -- \
  curl -I https://keycloak.mylegion5pro.me/realms/homelab

# 2. Check DNS from pod
kubectl exec -it -n local-ai-flowise deployment/flowise -- nslookup keycloak.mylegion5pro.me

# 3. Check firewall rules
kubectl exec -it -n local-ai-flowise deployment/flowise -- curl -v https://keycloak.mylegion5pro.me/realms/homelab

# 4. Verify Keycloak is running
kubectl get pods -A | grep keycloak
```

### Redirect Loop (if OAuth2 Proxy re-enabled)
```bash
# 1. Check ingress annotations
kubectl get ingress -n local-ai-flowise flowise -o yaml

# 2. Remove auth annotations if present
kubectl annotate ingress flowise -n local-ai-flowise \
  nginx.ingress.kubernetes.io/auth-url- \
  nginx.ingress.kubernetes.io/auth-signin- \
  nginx.ingress.kubernetes.io/auth-response-headers- \
  --overwrite

# 3. Verify annotations removed
kubectl get ingress -n local-ai-flowise flowise -o yaml
```

### Pod Crash Loop
```bash
# 1. Get pod status
kubectl get pods -n local-ai-flowise

# 2. Check events
kubectl describe pod -n local-ai-flowise <pod-name>

# 3. View recent logs (last 100 lines)
kubectl logs -n local-ai-flowise <pod-name> --tail=100

# 4. Check if container image exists
kubectl describe deployment -n local-ai-flowise flowise

# 5. Check resource limits/requests
kubectl get deployment -n local-ai-flowise flowise -o yaml | grep -A 10 "resources:"
```

---

## Performance Optimization

### Check Resource Limits
```bash
# View deployment resources
kubectl get deployment -n local-ai-flowise flowise -o yaml | grep -A 10 "resources:"

# Edit resources
kubectl edit deployment flowise -n local-ai-flowise
# Look for: resources: limits: memory, cpu
```

### Scale Deployments (Horizontal)
```bash
# Check current replicas
kubectl get deployment -n local-ai-flowise flowise

# Scale to 3 replicas
kubectl scale deployment/flowise -n local-ai-flowise --replicas=3

# Verify scaling
kubectl get deployment -n local-ai-flowise flowise
```

### Check Node Health
```bash
# View all nodes
kubectl get nodes

# Check node status
kubectl describe node talos-master

# Check node resource usage
kubectl top nodes
```

---

## Backup & Recovery

### Backup Everything
```bash
# 1. Backup PostgreSQL
kubectl exec -n local-ai-data supabase-postgres-0 -- \
  pg_dumpall -U postgres > backup-postgres-$(date +%Y%m%d-%H%M%S).sql

# 2. Backup Kubernetes resources
kubectl get all -A -o yaml > backup-k8s-$(date +%Y%m%d-%H%M%S).yaml

# 3. Backup Keycloak (export realm)
# Via Keycloak Admin Console: Realm settings → Export → Realm JSON

# 4. Store in safe location
# Move backups to external storage or cloud backup
```

### Restore from Backup
```bash
# 1. Restore PostgreSQL
cat backup-postgres-*.sql | \
  kubectl exec -i -n local-ai-data supabase-postgres-0 -- \
  psql -U postgres

# 2. Restore Keycloak (import realm)
# Via Keycloak Admin Console: Realm settings → Import → Upload JSON

# 3. Verify restoration
kubectl exec -it -n local-ai-data supabase-postgres-0 -- \
  psql -U postgres -c "SELECT version();"
```

---

## Useful Aliases

Add to your `.bashrc` or `.zshrc`:

```bash
# Local AI Quick Commands
alias lai-status='kubectl get pods -A | grep local-ai'
alias lai-flowise='kubectl logs -f -n local-ai-flowise deployment/flowise'
alias lai-n8n='kubectl logs -f -n local-ai-n8n deployment/n8n'
alias lai-certs='kubectl get certificate -A | grep local-ai'
alias lai-health='for service in flowise n8n neo4j searxng; do curl -s -o /dev/null -w "$service: %{http_code}\n" https://$service.lupulup.com; done'

# Kubernetes shortcuts
alias k='kubectl'
alias kgp='kubectl get pods -A'
alias kdesc='kubectl describe'
alias klogs='kubectl logs -f'
```

Then use:
```bash
lai-status      # Quick pod status
lai-health      # Check all service health
lai-flowise     # Watch Flowise logs
k get pods      # Get all pods (alias)
```

---

## Emergency Procedures

### Emergency Restart All Services
```bash
# Restart all deployments
for ns in local-ai-flowise local-ai-n8n local-ai-search local-ai-system; do
  kubectl rollout restart deployment -n $ns
done

# Wait for rollout
for ns in local-ai-flowise local-ai-n8n local-ai-search local-ai-system; do
  kubectl rollout status deployment -n $ns
done
```

### Emergency Delete and Recreate Service
```bash
# WARNING: Data will be lost!

# 1. Delete deployment
kubectl delete deployment/flowise -n local-ai-flowise

# 2. Wait for pod to terminate
kubectl get pods -n local-ai-flowise

# 3. Reapply manifest
kubectl apply -f k8s/apps/flowise/deployment.yaml

# 4. Wait for pod to start
kubectl get pods -n local-ai-flowise -w
```

### Emergency Access Keycloak
```bash
# If Keycloak URL not accessible:

# 1. Check if pod is running
kubectl get pods -n keycloak

# 2. Port-forward to admin console
kubectl port-forward -n keycloak svc/keycloak 8080:80

# 3. Access locally
# http://localhost:8080/admin
```

---

## Documentation Reference

**Quick Setup**
- [00-START-HERE.md](00-START-HERE.md) - Navigation and overview
- [KEYCLOAK-QUICK-START.md](KEYCLOAK-QUICK-START.md) - 5-minute setup
- [KEYCLOAK-REFERENCE-CARD.txt](KEYCLOAK-REFERENCE-CARD.txt) - Printable reference

**Detailed Guides**
- [KEYCLOAK-USER-SETUP-GUIDE.md](KEYCLOAK-USER-SETUP-GUIDE.md) - Comprehensive guide
- [KEYCLOAK-VISUAL-GUIDE.md](KEYCLOAK-VISUAL-GUIDE.md) - With diagrams
- [k8s/docs/APPLICATION-KEYCLOAK-INTEGRATION.md](k8s/docs/APPLICATION-KEYCLOAK-INTEGRATION.md) - Architecture

**Operations**
- [KEYCLOAK-INTEGRATION-STATUS.md](KEYCLOAK-INTEGRATION-STATUS.md) - Current status
- [OPERATIONS-CHECKLIST.md](OPERATIONS-CHECKLIST.md) - This file
- [DEPLOYMENT-CHECKLIST.md](DEPLOYMENT-CHECKLIST.md) - Initial setup

---

## Contact & Support

- **GitHub**: https://github.com/coleam00/local-ai-packaged
- **Community**: https://thinktank.ottomator.ai/c/local-ai/18
- **Keycloak Docs**: https://www.keycloak.org/docs/latest/
- **Kubernetes Docs**: https://kubernetes.io/docs/

---

**Last Updated**: 2025-10-23
**Status**: ✅ Operational
