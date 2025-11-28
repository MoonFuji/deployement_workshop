#!/usr/bin/env bash
# Script to sync only deployment config files to server
# This script is run from GitHub Actions to copy only necessary files

set -e

DEPLOY_DIR="${1:-}"
if [ -z "$DEPLOY_DIR" ]; then
  echo "Error: Deployment directory required"
  exit 1
fi

# Files and directories to sync (config files only, no app code)
CONFIG_FILES=(
  "docker-compose.yml"
  "deploy.sh"
  "traefik/traefik.yml"
  "scripts/record_prev.sh"
)

echo "Syncing deployment config files to server..."

# Create necessary directories on server
mkdir -p "$DEPLOY_DIR/traefik"
mkdir -p "$DEPLOY_DIR/scripts"
mkdir -p "$DEPLOY_DIR/traefik/letsencrypt"

# Copy each config file
for file in "${CONFIG_FILES[@]}"; do
  if [ -f "$file" ]; then
    echo "Copying $file..."
    cp "$file" "$DEPLOY_DIR/$file"
    # Make scripts executable
    if [[ "$file" == *.sh ]]; then
      chmod +x "$DEPLOY_DIR/$file"
    fi
  else
    echo "Warning: $file not found, skipping"
  fi
done

echo "Config files synced successfully"

