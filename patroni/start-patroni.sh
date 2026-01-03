#!/bin/bash
set -e

echo "Starting Patroni node: ${PATRONI_NAME}"

# Wait for etcd to be available
echo "Waiting for etcd cluster to be ready..."
MAX_RETRIES=30
RETRY_COUNT=0

while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
  if curl -s http://${ETCD1_PRIVATE_DOMAIN}:2379/health >/dev/null 2>&1 || \
     curl -s http://${ETCD2_PRIVATE_DOMAIN}:2379/health >/dev/null 2>&1 || \
     curl -s http://${ETCD3_PRIVATE_DOMAIN}:2379/health >/dev/null 2>&1; then
    echo "etcd cluster is available"
    break
  fi
  
  RETRY_COUNT=$((RETRY_COUNT + 1))
  echo "Waiting for etcd... (attempt $RETRY_COUNT/$MAX_RETRIES)"
  sleep 5
done

if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
  echo "ERROR: etcd cluster not available after $MAX_RETRIES attempts"
  exit 1
fi

# Ensure data directory has correct permissions
chown -R postgres:postgres /var/lib/postgresql/data
chmod 700 /var/lib/postgresql/data

# Export environment variables for Patroni
export PATRONI_SCOPE="${PATRONI_SCOPE:-railway-patroni}"
export PATRONI_NAME="${PATRONI_NAME}"
export PATRONI_PRIVATE_DOMAIN="${PATRONI_PRIVATE_DOMAIN}"
export ETCD1_PRIVATE_DOMAIN="${ETCD1_PRIVATE_DOMAIN}"
export ETCD2_PRIVATE_DOMAIN="${ETCD2_PRIVATE_DOMAIN}"
export ETCD3_PRIVATE_DOMAIN="${ETCD3_PRIVATE_DOMAIN}"
export POSTGRES_PASSWORD="${POSTGRES_PASSWORD}"
export REPLICATION_PASSWORD="${REPLICATION_PASSWORD}"

# Process the configuration file with envsubst
envsubst < /etc/patroni/patroni.yml > /tmp/patroni.yml

echo "Patroni configuration:"
cat /tmp/patroni.yml

# Start Patroni
echo "Starting Patroni..."
exec python3 -m patroni /tmp/patroni.yml
