# Deploy Without Fear

A practical workshop demo repository showcasing how to deploy a web application to a VPS with Docker, Traefik reverse proxy, automatic SSL certificates, and CI/CD with rollback capabilities.

## 🎯 Workshop Goal

Ship a web app from local development → public HTTPS domain with CI/CD that can automatically rollback on failure.

## 📁 Repository Structure

```
deploy-workshop/
├── app/                      # Demo application (NOT copied to server)
│   ├── Dockerfile           # Container definition
│   ├── package.json         # Node.js dependencies
│   ├── src/
│   │   └── server.js        # Express.js app with /healthz endpoint
│   └── healthcheck.sh       # Health check script
├── traefik/                  # Traefik configuration (synced to server)
│   ├── traefik.yml          # Static Traefik config
│   └── acme/                # ACME certificates (gitignored, created on server)
├── .github/
│   └── workflows/
│       └── ci-deploy.yml    # GitHub Actions CI/CD pipeline
├── scripts/                  # Helper scripts (synced to server)
│   ├── record_prev.sh       # Image tag tracking
│   └── sync-config.sh       # Config sync script
├── docs/                     # Documentation
│   ├── ssl-https-setup.md   # SSL/HTTPS detailed guide
│   └── runbook.md           # Deployment runbook
├── docker-compose.yml        # Service orchestration (synced to server)
├── deploy.sh                 # Deployment script with rollback (synced to server)
├── .env.example              # Environment variables template
└── README.md                 # This file
```

**Note:** Only config files (docker-compose.yml, deploy.sh, traefik/, scripts/) are synced to the server. App code stays in the repository and is built into Docker images.

## 🚀 Quick Start

### Prerequisites

- Docker and Docker Compose installed
- A VPS with Docker installed
- A domain name (or use a subdomain)
- GitHub account with repository

### Local Development

1. **Clone the repository**
   ```bash
   git clone <your-repo-url>
   cd deploy_demo
   ```

2. **Set up environment variables**
   ```bash
   cp .env.example .env
   # Edit .env with your values
   ```

3. **Build and run locally**
   ```bash
   cd app
   docker build -t deploy-demo-app:local .
   cd ..
   docker compose up -d
   ```

4. **Test locally**
   ```bash
   curl http://localhost:3000/healthz
   ```
    
### Production Deployment

#### Step 1: Domain & DNS Setup

1. Purchase a domain (or use a subdomain)
2. Point DNS A record to your VPS IP:
   ```
   Type: A
   Name: @ (or your subdomain)
   Value: <your-vps-ip>
   TTL: 300
   ```

#### Step 2: Server Setup

1. **SSH into your VPS**
   ```bash
   ssh user@your-vps-ip
   ```

2. **Install Docker and Docker Compose**
   ```bash
   # Ubuntu/Debian
   curl -fsSL https://get.docker.com -o get-docker.sh
   sudo sh get-docker.sh
   sudo apt-get install docker-compose-plugin
   ```

3. **Create deployment directory on server**
   ```bash
   mkdir -p ~/deploy
   cd ~/deploy
   ```

4. **Create .env file manually**
   ```bash
   nano .env
   # Add the following (adjust values):
   # APP_IMAGE=your-dockerhub-username/deploy-demo-app:latest
   # DOMAIN=example.com
   # EMAIL=you@example.com
   # TRAEFIK_IMAGE=traefik:v2.10
   ```

5. **Initial config files will be synced by CI/CD**
   - On first push to main branch, GitHub Actions will copy config files
   - Or manually copy these files once: `docker-compose.yml`, `deploy.sh`, `traefik/traefik.yml`, `scripts/`
   - **Note:** App code is NOT copied to server - only Docker images are pulled from Docker Hub

6. **Create deploy user (optional but recommended)**
   ```bash
   sudo useradd -m -s /bin/bash deploy
   sudo usermod -aG docker deploy
   sudo su - deploy
   ```

#### Step 3: GitHub Secrets Configuration

Add these secrets to your GitHub repository (Settings → Secrets and variables → Actions):

- `DOCKERHUB_USERNAME`: Your Docker Hub username
- `DOCKERHUB_TOKEN`: Docker Hub access token (not password)
- `SRV_HOST`: Your VPS IP address or domain
- `SSH_USER`: SSH username (e.g., `deploy`)
- `SSH_KEY`: Private SSH key for server access
- `DOMAIN`: Your domain name (e.g., `example.com`)
- `DEPLOY_DIR`: Deployment directory on server (e.g., `/home/deploy/deploy_demo`)

**Generate SSH Key:**
```bash
ssh-keygen -t ed25519 -C "github-actions" -f ~/.ssh/github_actions
# Add public key to server: ~/.ssh/authorized_keys
# Use private key content as SSH_KEY secret
```

**Generate Docker Hub Access Token:**
1. Log in to [Docker Hub](https://hub.docker.com/)
2. Go to Account Settings → Security → New Access Token
3. Create a token with read/write permissions
4. Copy the token immediately (it won't be shown again)
5. Add token to `DOCKERHUB_TOKEN` secret
6. Add your Docker Hub username to `DOCKERHUB_USERNAME` secret

#### Step 4: Initial Server Setup

1. **Copy config files to server (one-time setup)**
   
   Option A: Let CI/CD do it (recommended)
   - Push to main branch - GitHub Actions will sync config files automatically
   
   Option B: Manual copy
   ```bash
   # From your local machine
   scp docker-compose.yml deploy.sh user@your-vps:~/deploy/
   scp -r traefik/ user@your-vps:~/deploy/
   scp -r scripts/ user@your-vps:~/deploy/
   
   # On server, make scripts executable
   ssh user@your-vps "chmod +x ~/deploy/deploy.sh ~/deploy/scripts/*.sh"
   ```

2. **Start Traefik on server**
   ```bash
   ssh user@your-vps
   cd ~/deploy
   docker compose up -d traefik
   ```

3. **Build and push image (from your local machine)**
   ```bash
   docker login -u your-dockerhub-username
   # Enter your Docker Hub access token when prompted
   
   docker build -t your-dockerhub-username/deploy-demo-app:latest ./app
   docker push your-dockerhub-username/deploy-demo-app:latest
   ```

4. **Deploy manually (first time)**
   ```bash
   ssh user@your-vps
   cd ~/deploy
   ./deploy.sh your-dockerhub-username/deploy-demo-app:latest
   ```

3. **Verify deployment**
   ```bash
   curl https://your-domain.com/healthz
   ```

#### Step 5: Enable CI/CD

1. Push to `main` branch
2. GitHub Actions will automatically:
   - Build Docker image
   - Push to Docker Hub
   - Deploy to server via SSH
   - Run smoke test
   - Rollback on failure

## 🔄 Rollback Demo

To demonstrate rollback functionality:

1. **Create a broken version** (temporarily):
   ```javascript
   // In app/src/server.js, modify /healthz endpoint:
   app.get('/healthz', (req, res) => {
     res.status(500).json({ status: 'unhealthy' }); // Broken!
   });
   ```

2. **Commit and push**
   ```bash
   git add app/src/server.js
   git commit -m "Break health check for demo"
   git push origin main
   ```

3. **Watch CI/CD fail and rollback**
   - GitHub Actions will deploy
   - Health check will fail
   - Automatic rollback to previous working version

4. **Fix and redeploy**
   ```bash
   # Restore working version
   git revert HEAD
   git push origin main
   ```

## 🛠️ Troubleshooting

### Port Conflicts with Existing nginx/Reverse Proxy

**Problem:** If you already have nginx or another reverse proxy using ports 80/443, Traefik cannot bind to these ports.

**Check for conflicts:**
```bash
# On your VPS, check what's using ports 80 and 443
sudo netstat -tlnp | grep -E ':(80|443)'
# or
sudo ss -tlnp | grep -E ':(80|443)'
```

**Solutions:**

**Option 1: Use Traefik as Main Reverse Proxy (Recommended)**
- Stop nginx container or remove port bindings from nginx
- Let Traefik handle all traffic on ports 80/443
- Route your existing nginx project through Traefik:
  ```yaml
  # Add to your existing nginx project's docker-compose.yml
  labels:
    - "traefik.enable=true"
    - "traefik.http.routers.nginx-project.rule=Host(`your-existing-domain.com`)"
    - "traefik.http.routers.nginx-project.entrypoints=websecure"
    - "traefik.http.routers.nginx-project.tls.certresolver=le"
    - "traefik.http.services.nginx-project.loadbalancer.server.port=80"
  ```
- Connect nginx container to `traefik-network`:
  ```yaml
  networks:
    - traefik-network
  ```

**Option 2: Use Different Ports for Traefik (Not Recommended)**
- Modify `docker-compose.yml` to use different host ports:
  ```yaml
  ports:
    - "8080:80"   # HTTP on 8080
    - "8443:443"  # HTTPS on 8443
  ```
- **Note:** This breaks standard HTTP/HTTPS and requires custom port access

**Option 3: Multiple IP Addresses**
- If your VPS has multiple IPs, bind each service to different IPs:
  ```yaml
  ports:
    - "1.2.3.4:80:80"    # Traefik on IP 1
    - "1.2.3.4:443:443"
    # nginx uses IP 2 (5.6.7.8:80:80)
  ```

**Option 4: Run nginx on Different Ports**
- Change nginx to use ports 8080/8443 internally
- Route through Traefik (see Option 1)

### Certificate Issues

- **Let's Encrypt rate limits**: Use staging first:
  ```yaml
  # In traefik.yml, change to:
  certificatesResolvers:
    le:
      acme:
        caServer: https://acme-staging-v02.api.letsencrypt.org/directory
  ```

### Container Not Starting

```bash
# Check logs
docker compose logs web
docker compose logs traefik

# Check container status
docker compose ps

# Restart services
docker compose restart web
```

### Health Check Failing

```bash
# Test health endpoint directly
curl http://localhost:3000/healthz

# Check container health
docker inspect deploy-demo-app | grep -A 10 Health
```

### DNS Not Resolving

```bash
# Check DNS propagation
dig your-domain.com
nslookup your-domain.com

# Wait for DNS propagation (can take up to 48 hours, usually < 1 hour)
```

### GitHub Actions Failing

- Check Actions logs in GitHub
- Verify all secrets are set correctly
- Ensure SSH key has correct permissions
- Verify server is accessible from GitHub Actions runner

## 📚 Key Concepts

### Why Traefik?

- **Automatic SSL**: Zero-touch TLS certificate management with Let's Encrypt
- **Docker Integration**: Automatic service discovery via Docker labels
- **Dynamic Configuration**: No need to restart proxy when adding services

### Why Docker Compose?

- **Simple Orchestration**: Define all services in one file
- **Network Management**: Automatic networking between containers
- **Environment Variables**: Easy configuration management

### Why GitHub Actions?

- **Integrated CI/CD**: Built into GitHub, no external services needed
- **Free for Public Repos**: Cost-effective for open source projects
- **Flexible Workflows**: Easy to customize deployment steps

### Rollback Strategy

1. **Image Tagging**: Each deployment tagged with git SHA
2. **Previous Image Tracking**: `prev_image.txt` stores last working version
3. **Health Check**: Validates deployment before marking success
4. **Automatic Rollback**: On health check failure, restore previous image

### SSL/HTTPS Setup

Traefik automatically handles SSL certificates using Let's Encrypt:

- **Automatic Certificate Issuance**: Certificates are issued when services start
- **Automatic Renewal**: Certificates renew 30 days before expiration (90-day lifetime)
- **TLS-ALPN-01 Challenge**: Uses port 443 only, no need to expose port 80 for validation
- **HTTP to HTTPS Redirect**: All HTTP traffic automatically redirected to HTTPS
- **Zero Configuration**: Just set `DOMAIN` and `EMAIL` in `.env`

**For detailed SSL/HTTPS documentation, see:** [SSL/HTTPS Setup Guide](docs/ssl-https-setup.md)

## 🔒 Security Considerations

- **Never commit secrets**: Use `.env` and GitHub Secrets
- **SSH Key Security**: Use deploy keys with restricted access
- **Firewall**: Only open ports 80, 443, and SSH (22)
- **Traefik Dashboard**: Disable or add authentication in production
- **Rate Limiting**: Consider adding rate limits to your app

## 📖 Additional Resources

- [Architecture Overview](docs/architecture.md) - How the deployment system works
- [SSL/HTTPS Setup Guide](docs/ssl-https-setup.md) - Detailed explanation of SSL/HTTPS with Traefik
- [Deployment Runbook](docs/runbook.md) - Quick reference for deployment operations
- [Traefik Documentation](https://doc.traefik.io/traefik/)
- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [Let's Encrypt Documentation](https://letsencrypt.org/docs/)

## 🎓 Workshop Checklist

Before the workshop, ensure:

- [ ] Repository is public and accessible
- [ ] All secrets are configured in GitHub
- [ ] VPS is set up with Docker
- [ ] Domain DNS is configured
- [ ] Traefik is running and certificates are issued
- [ ] First deployment is successful
- [ ] Rollback demo is tested

## 📝 License

This is a demo repository for educational purposes.

## 🤝 Contributing

This is a workshop demo repository. Feel free to fork and adapt for your own workshops!

