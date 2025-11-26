#!/usr/bin/env bash
set -euo pipefail

# Deploy script with health check and rollback capability
# Usage: ./deploy.sh <image_tag>
# Example: ./deploy.sh your-dockerhub-username/deploy-demo-app:abc123

IMAGE="${1:-}"
if [ -z "$IMAGE" ]; then
  echo "Error: Image tag required"
  echo "Usage: $0 <image_tag>"
  exit 1
fi

# Configuration
COMPOSE_FILE="docker-compose.yml"
ENV_FILE=".env"
PREV_IMAGE_FILE="prev_image.txt"
DEPLOY_DIR="${DEPLOY_DIR:-$(pwd)}"
DOMAIN="${DOMAIN:-example.com}"
HEALTH_CHECK_URL="https://${DOMAIN}/healthz"
HEALTH_CHECK_TIMEOUT=30
HEALTH_CHECK_INTERVAL=3

cd "$DEPLOY_DIR" || exit 1

echo "=========================================="
echo "Deploying: $IMAGE"
echo "=========================================="

# Load current environment
if [ -f "$ENV_FILE" ]; then
  source "$ENV_FILE"
fi

# Save previous image for rollback
if [ -f "$ENV_FILE" ] && grep -q "APP_IMAGE=" "$ENV_FILE"; then
  PREV_IMAGE=$(grep "APP_IMAGE=" "$ENV_FILE" | cut -d '=' -f2)
  echo "$PREV_IMAGE" > "$PREV_IMAGE_FILE"
  echo "Previous image saved: $PREV_IMAGE"
else
  echo "Warning: No previous image found. Rollback may not work."
fi

# Pull new image
echo "Pulling image: $IMAGE"
docker pull "$IMAGE" || {
  echo "Error: Failed to pull image $IMAGE"
  exit 1
}

# Update .env file with new image
if [ -f "$ENV_FILE" ]; then
  if grep -q "APP_IMAGE=" "$ENV_FILE"; then
    sed -i "s|APP_IMAGE=.*|APP_IMAGE=$IMAGE|" "$ENV_FILE"
  else
    echo "APP_IMAGE=$IMAGE" >> "$ENV_FILE"
  fi
else
  echo "APP_IMAGE=$IMAGE" > "$ENV_FILE"
fi

# Update compose and restart services
echo "Updating containers..."
docker compose pull web || true
docker compose up -d web

# Wait for container to be ready
echo "Waiting for container to start..."
sleep 5

# Health check with retries
echo "Running health check on $HEALTH_CHECK_URL"
HEALTH_CHECK_PASSED=false
ELAPSED=0

while [ $ELAPSED -lt $HEALTH_CHECK_TIMEOUT ]; do
  if curl -fsS --max-time 5 "$HEALTH_CHECK_URL" > /dev/null 2>&1; then
    HEALTH_CHECK_PASSED=true
    break
  fi
  echo "Health check failed, retrying in ${HEALTH_CHECK_INTERVAL}s... (${ELAPSED}/${HEALTH_CHECK_TIMEOUT}s)"
  sleep $HEALTH_CHECK_INTERVAL
  ELAPSED=$((ELAPSED + HEALTH_CHECK_INTERVAL))
done

if [ "$HEALTH_CHECK_PASSED" = true ]; then
  echo "=========================================="
  echo "✓ Deployment successful!"
  echo "✓ Health check passed"
  echo "=========================================="
  
  # Save successful image
  echo "$IMAGE" > "$PREV_IMAGE_FILE"
  exit 0
else
  echo "=========================================="
  echo "✗ Health check failed!"
  echo "Rolling back to previous image..."
  echo "=========================================="
  
  # Rollback
  if [ -f "$PREV_IMAGE_FILE" ] && [ -n "$(cat "$PREV_IMAGE_FILE")" ]; then
    ROLLBACK_IMAGE=$(cat "$PREV_IMAGE_FILE")
    echo "Rolling back to: $ROLLBACK_IMAGE"
    
    # Update .env with previous image
    sed -i "s|APP_IMAGE=.*|APP_IMAGE=$ROLLBACK_IMAGE|" "$ENV_FILE"
    
    # Restart with previous image
    docker compose pull web || true
    docker compose up -d web
    
    echo "Rollback complete. Previous image restored."
  else
    echo "Error: Cannot rollback - no previous image found"
  fi
  
  exit 1
fi

