#!/bin/sh
# Health check script for docker-compose
# Returns 0 if healthy, 1 if unhealthy

curl -f http://localhost:3000/healthz > /dev/null 2>&1
exit $?

