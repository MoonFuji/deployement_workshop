# Deployment Runbook

Quick reference guide for deploying and managing the application.

## Prerequisites Checklist

- [ ] Domain name purchased
- [ ] DNS A record pointing to VPS IP
- [ ] VPS with Docker installed
- [ ] GitHub repository created
- [ ] GitHub Secrets configured
- [ ] SSH access to server configured

## Initial Setup Commands

```bash
# On server
cd ~/deploy
git clone <repo-url> .
cp .env.example .env
# Edit .env with your values
docker compose up -d traefik
```

## Deployment Commands

### Manual Deployment

```bash
# Deploy specific image
./deploy.sh your-dockerhub-username/deploy-demo-app:abc123

# Deploy latest
./deploy.sh your-dockerhub-username/deploy-demo-app:latest
```

### Via CI/CD

```bash
# Push to main branch
git push origin main

# GitHub Actions will automatically:
# 1. Build image
# 2. Push to registry
# 3. Deploy to server
# 4. Run health check
# 5. Rollback if needed
```

## Health Check Endpoint

```bash
# Check application health
curl https://your-domain.com/healthz

# Expected response:
# {"status":"healthy","timestamp":"...","uptime":123.45}
```

## Monitoring Commands

### Container Status

```bash
# List all containers
docker compose ps

# View logs
docker compose logs -f web
docker compose logs -f traefik

# Container health
docker inspect deploy-demo-app | grep -A 10 Health
```

### Traefik Dashboard

```bash
# Access dashboard (if enabled)
# http://traefik.your-domain.com:8080
# Or locally: http://localhost:8080
```

### Network Debugging

```bash
# Check Traefik network
docker network inspect traefik-network

# Test container connectivity
docker exec deploy-demo-app wget -O- http://localhost:3000/healthz
```

## Rollback Procedures

### Automatic Rollback

Rollback happens automatically if health check fails after deployment.

### Manual Rollback

```bash
# Check previous image
cat prev_image.txt

# Rollback to previous image
./deploy.sh $(cat prev_image.txt)

# Or rollback to specific image
./deploy.sh your-dockerhub-username/deploy-demo-app:previous-tag
```

### Emergency Rollback

```bash
# Stop current container
docker compose stop web

# Update .env with previous image
nano .env  # Change APP_IMAGE

# Start with previous image
docker compose up -d web
```

## Troubleshooting Commands

### Certificate Issues

```bash
# Check certificate files
ls -la traefik/letsencrypt/

# View Traefik logs for ACME errors
docker compose logs traefik | grep -i acme

# Test with staging (in traefik.yml)
# Change caServer to staging URL
```

### DNS Issues

```bash
# Check DNS resolution
dig your-domain.com
nslookup your-domain.com

# Test from server
curl -I http://your-domain.com
```

### Container Issues

```bash
# Restart specific service
docker compose restart web

# Rebuild and restart
docker compose up -d --force-recreate web

# View detailed container info
docker inspect deploy-demo-app
```

### Network Issues

```bash
# Recreate network
docker compose down
docker network rm traefik-network
docker compose up -d

# Check port binding
sudo netstat -tlnp | grep -E ':(80|443|3000)'
```

## Common Issues & Solutions

### Issue: Health check always fails

**Solution:**
```bash
# Check if app is running
docker exec deploy-demo-app ps aux

# Test health endpoint directly
docker exec deploy-demo-app wget -O- http://localhost:3000/healthz

# Check app logs
docker compose logs web
```

### Issue: Certificate not issued

**Solution:**
```bash
# Check Traefik logs
docker compose logs traefik | grep -i certificate

# Verify DNS is correct
dig your-domain.com

# Check firewall (ports 80/443 must be open)
sudo ufw status
```

### Issue: Container won't start

**Solution:**
```bash
# Check container logs
docker compose logs web

# Check image exists
docker images | grep your-app

# Try pulling image manually
docker pull your-dockerhub-username/deploy-demo-app:latest
```

### Issue: GitHub Actions failing

**Solution:**
- Verify all secrets are set
- Check SSH key permissions
- Verify server is accessible
- Check Actions logs for specific error

## Maintenance Tasks

### Update Traefik

```bash
# Update image tag in docker-compose.yml
docker compose pull traefik
docker compose up -d traefik
```

### Clean Up Old Images

```bash
# Remove unused images
docker image prune -a

# Remove old containers
docker container prune
```

### Backup Certificates

```bash
# Backup ACME certificates
tar -czf certs-backup-$(date +%Y%m%d).tar.gz traefik/letsencrypt/
```

### View Deployment History

```bash
# Check previous deployments
cat prev_image.txt

# View git history
git log --oneline
```

## Quick Reference

| Task | Command |
|------|---------|
| Deploy | `./deploy.sh <image-tag>` |
| View logs | `docker compose logs -f web` |
| Health check | `curl https://your-domain.com/healthz` |
| Restart app | `docker compose restart web` |
| Rollback | `./deploy.sh $(cat prev_image.txt)` |
| Check status | `docker compose ps` |
| View Traefik | `docker compose logs traefik` |

## Emergency Contacts

- GitHub Actions: Check repository Actions tab
- Server Access: SSH to VPS
- Domain/DNS: Check domain registrar
- Certificate Issues: Check Let's Encrypt rate limits

## Notes

- Health check timeout: 30 seconds
- Health check interval: 3 seconds
- Previous image stored in: `prev_image.txt`
- Environment variables in: `.env`
- Traefik dashboard: Port 8080 (if enabled)

