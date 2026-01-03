#!/bin/sh
set -e

echo "Starting HAProxy..."

# Wait for at least one Patroni node to be available
echo "Waiting for Patroni nodes to be ready..."
MAX_RETRIES=60
RETRY_COUNT=0

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
  if curl -s http://${PATRONI1_PRIVATE_DOMAIN}:8008/health >/dev/null 2>&1 || \
     curl -s http://${PATRONI2_PRIVATE_DOMAIN}:8008/health >/dev/null 2>&1 || \
     curl -s http://${PATRONI3_PRIVATE_DOMAIN}:8008/health >/dev/null 2>&1; then
    echo "At least one Patroni node is available"
    break
  fi
  
  RETRY_COUNT=$((RETRY_COUNT + 1))
  echo "Waiting for Patroni nodes... (attempt $RETRY_COUNT/$MAX_RETRIES)"
  sleep 5
done

if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
  echo "WARNING: No Patroni nodes available, starting HAProxy anyway..."
fi

# Set default stats credentials if not provided
export HAPROXY_STATS_USER="${HAPROXY_STATS_USER:-admin}"
export HAPROXY_STATS_PASSWORD="${HAPROXY_STATS_PASSWORD:-changeme}"

# Substitute environment variables in config
envsubst < /usr/local/etc/haproxy/haproxy.cfg.template > /usr/local/etc/haproxy/haproxy.cfg

echo "HAProxy configuration:"
cat /usr/local/etc/haproxy/haproxy.cfg

# Start HAProxy
exec haproxy -f /usr/local/etc/haproxy/haproxy.cfg
