#!/usr/bin/env bash
# Helper script to record previous image tag
# Called by deploy.sh

PREV_IMAGE_FILE="${PREV_IMAGE_FILE:-prev_image.txt}"
CURRENT_IMAGE="${1:-}"

if [ -n "$CURRENT_IMAGE" ]; then
  echo "$CURRENT_IMAGE" > "$PREV_IMAGE_FILE"
  echo "Recorded previous image: $CURRENT_IMAGE"
else
  echo "Error: No image tag provided"
  exit 1
fi

