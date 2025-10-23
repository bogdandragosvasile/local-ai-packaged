# Nginx Proxy Manager Configuration

This guide explains how to configure Nginx Proxy Manager (NPM) to route traffic to your Kubernetes cluster.

## Architecture

```
Internet (lupulup.com / mylegion5pro.me)
    ↓
Nginx Proxy Manager (HA on 2 Mini PCs)
    ↓
Kubernetes Cluster Ingress Controller
    ↓
Services (n8n, Flowise, etc.)
```

## Prerequisites

- Nginx Proxy Manager running on 192.168.1.11 and 192.168.1.12 (HA)
- Kubernetes cluster with Ingress Controller (Nginx)
- DNS records configured

## Step 1: Identify Kubernetes Ingress Controller IP

```bash
# Get the Ingress Controller service
kubectl get svc -n ingress-nginx

# Get the external IP or LoadBalancer IP
kubectl get svc -n ingress-nginx ingress-nginx-controller

# Example output:
# ingress-nginx-controller   LoadBalancer   10.96.1.100   192.168.1.30   80:32080/TCP,443:32443/TCP
```

Note the **External IP** (e.g., `192.168.1.30`). This is what NPM will route to.

## Step 2: Create Proxy Hosts in Nginx Proxy Manager

### Access NPM Admin Panel

1. Navigate to `https://nginx.your-domain.com` (or the IP address)
2. Login with your credentials
3. Go to **Proxy Hosts**

### Create Proxy Host for n8n

1. **Click "Add Proxy Host"**

2. **Details Tab**:
   - **Domain Names**: `n8n.lupulup.com`
   - **Scheme**: `https`
   - **Forward Hostname/IP**: `192.168.1.30` (Kubernetes Ingress IP)
   - **Forward Port**: `443`
   - **Cache Assets**: OFF (n8n is dynamic)
   - **Block Common Exploits**: ON
   - **Websockets Support**: ON (required for n8n)

3. **SSL Tab**:
   - **SSL Certificate**: Select your Cloudflare certificate or use Let's Encrypt
   - **Force SSL**: ON
   - **HSTS Enabled**: ON
   - **HSTS Subdomains**: ON

4. **Custom Locations** (if needed):
   ```
   Location: /
   Scheme: https
   Forward Hostname/IP: 192.168.1.30
   Forward Port: 443
   ```

5. **Click "Save"**

### Create Proxy Host for Flowise

1. **Click "Add Proxy Host"**

2. **Details Tab**:
   - **Domain Names**: `flowise.lupulup.com`
   - **Scheme**: `https`
   - **Forward Hostname/IP**: `192.168.1.30`
   - **Forward Port**: `443`
   - **Block Common Exploits**: ON
   - **Websockets Support**: ON

3. **SSL Tab**:
   - **SSL Certificate**: Your certificate
   - **Force SSL**: ON

4. **Click "Save"**

### Create Proxy Host for Neo4j

1. **Click "Add Proxy Host"**

2. **Details Tab**:
   - **Domain Names**: `neo4j.lupulup.com`
   - **Scheme**: `https`
   - **Forward Hostname/IP**: `192.168.1.30`
   - **Forward Port**: `443`
   - **Block Common Exploits**: ON

3. **SSL Tab**:
   - **SSL Certificate**: Your certificate
   - **Force SSL**: ON

4. **Click "Save"**

### Create Proxy Host for SearXNG

1. **Click "Add Proxy Host"**

2. **Details Tab**:
   - **Domain Names**: `searxng.lupulup.com`
   - **Scheme**: `https`
   - **Forward Hostname/IP**: `192.168.1.30`
   - **Forward Port**: `443`
   - **Block Common Exploits**: ON

3. **SSL Tab**:
   - **SSL Certificate**: Your certificate
   - **Force SSL**: ON

4. **Click "Save"**

### Create Proxy Host for Supabase

1. **Click "Add Proxy Host"**

2. **Details Tab**:
   - **Domain Names**: `supabase.lupulup.com`
   - **Scheme**: `https`
   - **Forward Hostname/IP**: `192.168.1.30`
   - **Forward Port**: `443`
   - **Block Common Exploits**: ON

3. **SSL Tab**:
   - **SSL Certificate**: Your certificate
   - **Force SSL**: ON

4. **Click "Save"**

## Step 3: Configure Cloudflare DNS Records

In Cloudflare for `lupulup.com`:

| Subdomain | Type | Content | TTL | Proxy |
|-----------|------|---------|-----|-------|
| n8n | A | 192.168.1.11 or 192.168.1.12 | Auto | ⚡ Proxied |
| flowise | A | 192.168.1.11 or 192.168.1.12 | Auto | ⚡ Proxied |
| neo4j | A | 192.168.1.11 or 192.168.1.12 | Auto | ⚡ Proxied |
| searxng | A | 192.168.1.11 or 192.168.1.12 | Auto | ⚡ Proxied |
| supabase | A | 192.168.1.11 or 192.168.1.12 | Auto | ⚡ Proxied |

**Note**: Use whichever NPM instance you want primary, or use both with round-robin DNS.

## Step 4: Configure NoIP DNS Records

For `mylegion5pro.me` (NoIP):

Update your NoIP account to point to NPM's IP:
- A record: `192.168.1.11` (primary) or `192.168.1.12` (secondary)

For subdomains like `argocd.mylegion5pro.me`:
- Create CNAME records pointing to main domain

Or use wildcard:
- `*.mylegion5pro.me` → `192.168.1.11`

## Step 5: Test Connectivity

```bash
# Test from your local machine
curl -v https://n8n.lupulup.com

# Expected:
# - Should redirect to Keycloak login (due to OAuth2 Proxy)
# - Certificate should be valid
# - Status: 200 or 302 (redirect)
```

## Step 6: Configure Advanced Settings (Optional)

### Custom Headers

Add security headers in NPM:

1. Go to **Proxy Host** → **Edit**
2. **Advanced** Tab → **Custom Locations**
3. Add custom Nginx directives:

```nginx
# Security headers
add_header X-Frame-Options "DENY" always;
add_header X-Content-Type-Options "nosniff" always;
add_header X-XSS-Protection "1; mode=block" always;
add_header Referrer-Policy "strict-origin-when-cross-origin" always;

# Compression
gzip on;
gzip_types text/plain text/css application/json application/javascript;
gzip_min_length 1000;
```

### Rate Limiting

To protect against brute force:

```nginx
# In NPM custom directives:
limit_req_zone $binary_remote_addr zone=general:10m rate=10r/s;
limit_req zone=general burst=20 nodelay;
```

## Step 7: Monitor NPM

### Check NPM Status

```bash
# SSH to NPM VM
ssh root@192.168.1.11

# Check Nginx status
sudo systemctl status nginx

# Check Nginx logs
sudo tail -f /var/log/nginx/proxy_host_*.log

# Check SSL certificate status
sudo certbot certificates
```

### Monitor in NPM Dashboard

1. Go to **Dashboard**
2. View **Active Connections**
3. Check **Data Usage**
4. Monitor **SSL Certificates**

## Step 8: HA Setup (NPM on 2 Mini PCs)

### Configuration on Both NPM Instances

Each NPM instance should have identical proxy host configurations.

### External IP Failover

Use one of these approaches:

**Option A: DNS Round-Robin**
```
n8n.lupulup.com → A 192.168.1.11
n8n.lupulup.com → A 192.168.1.12
```

**Option B: Keepalived/HAProxy**
```
Virtual IP: 192.168.1.20
- NPM Primary: 192.168.1.11
- NPM Secondary: 192.168.1.12
```

**Option C: Load Balancer (if available)**
Configure your network load balancer to balance between NPM instances.

## Step 9: Test Each Service

### Test n8n
```bash
curl -v https://n8n.lupulup.com
# Should redirect to Keycloak
```

### Test Flowise
```bash
curl -v https://flowise.lupulup.com
# Should redirect to Keycloak
```

### Test with Authentication
```bash
# After entering credentials in browser, check:
curl -v https://n8n.lupulup.com \
  -H "Cookie: _oauth2_proxy=<your-session-cookie>"
# Should return 200 with n8n UI
```

## Troubleshooting

### Certificate Issues

**Problem**: "SSL certificate problem"

**Solution**:
```bash
# In NPM:
1. Delete the proxy host
2. Re-create with correct SSL certificate
3. Verify certificate is not expired

# Check certificate:
openssl s_client -connect n8n.lupulup.com:443
```

### Connection Refused

**Problem**: "Connection refused to 192.168.1.30"

**Solution**:
```bash
# Verify Kubernetes Ingress IP
kubectl get svc -n ingress-nginx

# If IP changed, update NPM proxy hosts

# Test direct connection
curl https://192.168.1.30:443 -k
```

### Slow Performance

**Problem**: Requests are slow

**Solution**:
1. Check NPM CPU/Memory usage
2. Enable caching in proxy host
3. Check Kubernetes pod CPU/Memory
4. Monitor network latency between NPM and K8s

### OAuth2 Redirect Loop

**Problem**: Stuck in redirect loop between NPM and Keycloak

**Solution**:
```bash
# Check OAuth2 Proxy logs
kubectl logs -n local-ai-system deployment/oauth2-proxy

# Verify redirect URLs in Keycloak
# Common issue: HTTP vs HTTPS mismatch

# Clear browser cookies and cache
# Try incognito mode
```

## SSL Certificate Management

### Let's Encrypt (Automatic)

NPM can automatically renew Let's Encrypt certificates:

1. Go to **SSL Certificates** → **Add**
2. **Email Address**: your@email.com
3. **Domain Names**: `n8n.lupulup.com`
4. **Use a DNS challenge**: ON (for wildcard)
5. Click **Save**

### Cloudflare (Manual)

If using Cloudflare SSL:

1. In Cloudflare: **SSL/TLS** → **Origin Server** → **Create Certificate**
2. Download the certificate
3. In NPM: Upload the certificate
4. Set expiry reminder

## References

- [Nginx Proxy Manager Docs](https://nginxproxymanager.com/)
- [Nginx Ingress Controller](https://kubernetes.github.io/ingress-nginx/)
- [Cloudflare DNS](https://www.cloudflare.com/dns/)

## Next Steps

1. ✅ Configure all proxy hosts
2. ✅ Test each service
3. Configure monitoring alerts
4. Set up auto-renewal for certificates
5. Document your NPM configuration
