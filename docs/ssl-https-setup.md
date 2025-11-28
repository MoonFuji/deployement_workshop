# SSL/HTTPS Setup with Traefik and Let's Encrypt

This document explains how SSL/HTTPS is automatically configured in this deployment setup using Traefik and Let's Encrypt.

## Overview

Traefik acts as a reverse proxy that automatically:
1. Detects your Docker containers via labels
2. Issues SSL certificates from Let's Encrypt
3. Renews certificates automatically before expiration
4. Redirects HTTP (port 80) to HTTPS (port 443)

**No manual certificate management required!**

## How It Works

### 1. Traefik Configuration

Traefik is configured in `docker-compose.yml` with:

```yaml
traefik:
  command:
    - "--certificatesresolvers.le.acme.tlschallenge=true"
    - "--certificatesresolvers.le.acme.email=${EMAIL}"
    - "--certificatesresolvers.le.acme.storage=/letsencrypt/acme.json"
```

**Key Components:**
- **`le`**: Name of the certificate resolver (Let's Encrypt)
- **`tlschallenge`**: Uses TLS-ALPN-01 challenge (works on port 443)
- **`email`**: Email for Let's Encrypt notifications (expiry warnings)
- **`storage`**: Where certificates are stored (`/letsencrypt/acme.json`)

### 2. TLS Challenge (TLS-ALPN-01)

Traefik uses the **TLS-ALPN-01 challenge** which:
- Works entirely on port 443 (HTTPS)
- No need to expose port 80 for HTTP-01 challenge
- More secure and simpler setup
- Requires Traefik to handle port 443 directly

**How it works:**
1. Let's Encrypt connects to your domain on port 443
2. Traefik responds with a special TLS handshake
3. Let's Encrypt verifies you control the domain
4. Certificate is issued and stored

### 3. Automatic Certificate Management

Traefik automatically:
- **Issues certificates** when a new service with TLS labels is detected
- **Renews certificates** 30 days before expiration (Let's Encrypt certs last 90 days)
- **Stores certificates** in `traefik/letsencrypt/acme.json`
- **Applies certificates** to all routes using the `le` resolver

### 4. Service Labels for HTTPS

Your application service uses labels to enable HTTPS:

```yaml
web:
  labels:
    - "traefik.enable=true"
    - "traefik.http.routers.web.rule=Host(`example.com`)"
    - "traefik.http.routers.web.entrypoints=websecure"
    - "traefik.http.routers.web.tls.certresolver=le"
```

**Label Breakdown:**
- `traefik.enable=true`: Enable Traefik for this service
- `traefik.http.routers.web.rule=Host(...)`: Route requests for this domain
- `traefik.http.routers.web.entrypoints=websecure`: Use HTTPS entrypoint (port 443)
- `traefik.http.routers.web.tls.certresolver=le`: Use Let's Encrypt for certificates

### 5. HTTP to HTTPS Redirect

Traefik automatically redirects all HTTP traffic to HTTPS:

```yaml
command:
  - "--entrypoints.web.http.redirections.entrypoint.to=websecure"
  - "--entrypoints.web.http.redirections.entrypoint.scheme=https"
  - "--entrypoints.web.http.redirections.entrypoint.permanent=true"
```

**What happens:**
- User visits `http://example.com` (port 80)
- Traefik responds with `301 Permanent Redirect` to `https://example.com`
- Browser automatically follows redirect to HTTPS

## Setup Requirements

### 1. DNS Configuration

**Critical:** DNS must be configured BEFORE starting Traefik.

```dns
Type: A
Name: @ (or subdomain like www)
Value: <your-vps-ip>
TTL: 300 (or lower for faster propagation)
```

**Verify DNS:**
```bash
dig example.com
nslookup example.com
# Should return your VPS IP
```

### 2. Firewall Configuration

Open required ports on your VPS:

```bash
# Allow HTTP (for redirects)
sudo ufw allow 80/tcp

# Allow HTTPS (for SSL and TLS challenge)
sudo ufw allow 443/tcp

# Allow SSH (for management)
sudo ufw allow 22/tcp
```

### 3. Email Configuration

Set your email in `.env`:

```bash
EMAIL=your-email@example.com
```

This email receives:
- Certificate expiration warnings
- Let's Encrypt rate limit notifications
- Important account updates

## Certificate Storage

Certificates are stored in: `traefik/letsencrypt/acme.json`

**Important:**
- This file contains private keys - **never commit to git** (already in `.gitignore`)
- Backup this file for disaster recovery
- File permissions should be `600` (read/write for owner only)

**Backup certificates:**
```bash
tar -czf certs-backup-$(date +%Y%m%d).tar.gz traefik/letsencrypt/
```

## Let's Encrypt Rate Limits

Let's Encrypt has rate limits to prevent abuse:

- **Certificates per Registered Domain**: 50 per week
- **Duplicate Certificates**: 5 per week
- **Failed Validations**: 5 per account per hostname per hour

**For Testing:**
Use Let's Encrypt staging server first:

```yaml
# In traefik.yml or docker-compose.yml
certificatesResolvers:
  le:
    acme:
      caServer: https://acme-staging-v02.api.letsencrypt.org/directory
```

**Staging certificates:**
- Won't be trusted by browsers (expected)
- Don't count against rate limits
- Perfect for testing your setup

## Troubleshooting SSL Issues

### Certificate Not Issued

**Check Traefik logs:**
```bash
docker compose logs traefik | grep -i acme
docker compose logs traefik | grep -i certificate
```

**Common issues:**
1. **DNS not propagated**: Wait 5-60 minutes, verify with `dig`
2. **Port 443 blocked**: Check firewall `sudo ufw status`
3. **Wrong domain in labels**: Verify `DOMAIN` env var matches DNS
4. **Rate limit exceeded**: Wait or use staging server

### Certificate Expired

Traefik should auto-renew, but if expired:

```bash
# Restart Traefik to trigger renewal
docker compose restart traefik

# Or force renewal by removing old cert
rm traefik/letsencrypt/acme.json
docker compose restart traefik
```

### Mixed Content Warnings

If your app serves HTTP resources (images, scripts) over HTTPS:

**Fix in your app:**
- Use relative URLs: `/images/logo.png` instead of `http://example.com/images/logo.png`
- Use protocol-relative URLs: `//example.com/api` (uses current protocol)
- Force HTTPS in your application code

## Security Best Practices

### 1. Certificate Security

```bash
# Set proper permissions
chmod 600 traefik/letsencrypt/acme.json
```

### 2. Traefik Dashboard

The dashboard is exposed on port 8080. In production:

**Option 1: Disable dashboard**
```yaml
# Remove or comment out:
# - "--api.dashboard=true"
# - "--api.insecure=true"
```

**Option 2: Add authentication**
```yaml
# Use Traefik's built-in auth
labels:
  - "traefik.http.middlewares.auth.basicauth.users=admin:$$apr1$$..."
```

### 3. HSTS (HTTP Strict Transport Security)

Add HSTS header for extra security:

```yaml
labels:
  - "traefik.http.middlewares.secure-headers.headers.stsSeconds=31536000"
  - "traefik.http.middlewares.secure-headers.headers.stsIncludeSubdomains=true"
  - "traefik.http.routers.web.middlewares=secure-headers"
```

## How Certificates Are Applied

1. **Container starts** with Traefik labels
2. **Traefik detects** the new service via Docker socket
3. **Traefik checks** if certificate exists for the domain
4. **If missing**, Traefik requests certificate from Let's Encrypt
5. **TLS challenge** completes automatically
6. **Certificate stored** in `acme.json`
7. **HTTPS enabled** for the route

**Timeline:**
- First certificate: 10-30 seconds
- Certificate renewal: Automatic, 30 days before expiry
- No downtime during renewal

## Verification

**Check certificate:**
```bash
# From your local machine
openssl s_client -connect example.com:443 -servername example.com

# Check certificate details
echo | openssl s_client -connect example.com:443 2>/dev/null | openssl x509 -noout -dates
```

**Test HTTPS:**
```bash
curl -I https://example.com
# Should return 200 OK with no certificate errors
```

**Browser check:**
- Visit `https://example.com`
- Click the lock icon in address bar
- Verify certificate is from "Let's Encrypt"
- Check expiration date (should be ~90 days from now)

## Summary

**What you need to do:**
1. ✅ Set DNS A record to your VPS IP
2. ✅ Set `EMAIL` in `.env`
3. ✅ Set `DOMAIN` in `.env`
4. ✅ Open ports 80 and 443
5. ✅ Start Traefik: `docker compose up -d traefik`

**What Traefik does automatically:**
- ✅ Issues SSL certificates
- ✅ Renews certificates
- ✅ Redirects HTTP → HTTPS
- ✅ Applies certificates to your services

**No manual certificate management needed!** 🎉

