# Deployment Architecture

This document explains how the deployment system works and why app code is not stored on the server.

## Architecture Overview

```
┌─────────────────┐
│  GitHub Repo    │
│  (Source Code)  │
│                 │
│  - app/         │ ← App code stays here
│  - config files │ ← Synced to server
└────────┬────────┘
         │
         │ CI/CD Pipeline
         ▼
┌─────────────────┐
│ GitHub Actions  │
│                 │
│  1. Build       │ ← Builds Docker image from app/
│  2. Push        │ ← Pushes to Docker Hub
│  3. Sync Config │ ← Copies only config files
│  4. Deploy      │ ← Pulls image & deploys
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│   Docker Hub    │
│                 │
│  Docker Images  │ ← App code is here (in images)
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│   VPS Server    │
│                 │
│  Config Files:  │
│  - docker-compose.yml
│  - deploy.sh
│  - traefik/
│  - scripts/
│                 │
│  Docker Images: │ ← Pulled from Docker Hub
│  - Traefik      │
│  - Your App     │
└─────────────────┘
```

## Why App Code Isn't on the Server

### Benefits

1. **Security**: Source code never touches production server
2. **Separation of Concerns**: Development code separate from deployment config
3. **Smaller Server Footprint**: Only essential files on server
4. **Faster Deployments**: No need to sync large codebases
5. **Version Control**: All code changes tracked in Git, not on server

### What's on the Server

**Config Files (Synced by CI/CD):**
- `docker-compose.yml` - Service orchestration
- `deploy.sh` - Deployment script with rollback
- `traefik/traefik.yml` - Reverse proxy configuration
- `scripts/` - Helper scripts
- `.env` - Environment variables (created manually, not synced)

**Docker Images (Pulled from Registry):**
- Traefik image (from Docker Hub)
- Your application image (from Docker Hub)

**Runtime Data:**
- SSL certificates (`traefik/letsencrypt/`)
- Previous image tracking (`prev_image.txt`)
- Container logs

## Deployment Flow

### 1. Code Push
```bash
git push origin main
```

### 2. CI/CD Pipeline

**Build Job:**
1. Checks out repository
2. Builds Docker image from `app/` directory
3. Tags image with git SHA and `latest`
4. Pushes to Docker Hub

**Deploy Job:**
1. Checks out repository (for config files)
2. Syncs config files to server via SCP:
   - `docker-compose.yml`
   - `deploy.sh`
   - `traefik/traefik.yml`
   - `scripts/`
3. Makes scripts executable
4. Restarts Traefik (if config changed)
5. Runs `deploy.sh` with new image tag
6. Runs smoke test
7. Rolls back on failure

### 3. Server Deployment

**deploy.sh script:**
1. Pulls new Docker image from Docker Hub
2. Updates `.env` with new image tag
3. Runs `docker compose up -d web`
4. Waits for container to start
5. Health checks via HTTPS
6. Rolls back to previous image if health check fails

## File Sync Strategy

### Always Synced
Config files are always synced to ensure server has latest:
- Deployment scripts
- Docker Compose configuration
- Traefik configuration

### Conditionally Restarted
Traefik is only restarted if config files changed (detected by path filter).

### Never Synced
- `app/` directory - Code stays in repository
- `.github/` - CI/CD config not needed on server
- `docs/` - Documentation not needed on server
- `.env` - Created manually on server (contains secrets)

## Security Considerations

### Source Code Protection
- App code never on production server
- Only Docker images (compiled/built) are deployed
- Source code access requires repository access

### Secret Management
- `.env` file created manually on server
- Never committed to repository
- GitHub Secrets used for CI/CD authentication

### Access Control
- SSH keys for server access
- Docker Hub tokens for image registry
- No direct code access from server

## Benefits of This Architecture

1. **Clean Separation**: Development and deployment are separate
2. **Fast Deployments**: Only small config files synced
3. **Security**: Source code not exposed on server
4. **Scalability**: Easy to add more servers (just copy config)
5. **Version Control**: All changes tracked in Git
6. **Rollback**: Previous images tracked and easily restored

## Comparison: Traditional vs This Approach

### Traditional (Full Repo on Server)
```
Server contains:
- Full git repository
- All source code
- Config files
- Build tools
- Dependencies
```

**Issues:**
- Large server footprint
- Source code exposed
- Slower deployments
- More attack surface

### This Approach (Config Only)
```
Server contains:
- Config files only
- Docker images (pulled)
- Runtime data
```

**Benefits:**
- Minimal server footprint
- Source code protected
- Faster deployments
- Smaller attack surface

## Troubleshooting

### Config Files Not Syncing

Check GitHub Actions logs:
- Verify SCP action succeeded
- Check SSH key permissions
- Verify DEPLOY_DIR path

### Images Not Pulling

Check on server:
```bash
docker pull your-image:tag
docker images | grep your-image
```

### Config Changes Not Applied

Restart Traefik manually:
```bash
cd ~/deploy
docker compose restart traefik
```

## Summary

This architecture provides a clean, secure, and efficient deployment process where:
- **Source code** stays in the repository
- **Config files** are synced automatically
- **Docker images** are pulled from registry
- **Deployment** is automated via CI/CD
- **Rollback** is built-in and automatic

