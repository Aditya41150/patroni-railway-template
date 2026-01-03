#!/bin/sh
set -e

# Get node number from environment variable (1, 2, or 3)
NODE_NUM=${ETCD_NODE_NUM:-1}

# Set node name
NODE_NAME="etcd${NODE_NUM}"

# Railway private network domains for etcd nodes
ETCD1_HOST="${ETCD1_PRIVATE_DOMAIN:-etcd1.railway.internal}"
ETCD2_HOST="${ETCD2_PRIVATE_DOMAIN:-etcd2.railway.internal}"
ETCD3_HOST="${ETCD3_PRIVATE_DOMAIN:-etcd3.railway.internal}"

# Determine this node's host
case $NODE_NUM in
  1) THIS_HOST=$ETCD1_HOST ;;
  2) THIS_HOST=$ETCD2_HOST ;;
  3) THIS_HOST=$ETCD3_HOST ;;
  *) echo "Invalid ETCD_NODE_NUM: $NODE_NUM"; exit 1 ;;
esac

# Build initial cluster string
INITIAL_CLUSTER="etcd1=http://${ETCD1_HOST}:2380,etcd2=http://${ETCD2_HOST}:2380,etcd3=http://${ETCD3_HOST}:2380"

# Determine cluster state
if [ -d "/etcd-data/member" ]; then
  CLUSTER_STATE="existing"
else
  CLUSTER_STATE="new"
fi

echo "Starting etcd node: $NODE_NAME"
echo "This host: $THIS_HOST"
echo "Initial cluster: $INITIAL_CLUSTER"
echo "Cluster state: $CLUSTER_STATE"

# Start etcd
exec /usr/local/bin/etcd \
  --name="${NODE_NAME}" \
  --data-dir="/etcd-data" \
  --listen-client-urls="http://0.0.0.0:2379" \
  --advertise-client-urls="http://${THIS_HOST}:2379" \
  --listen-peer-urls="http://0.0.0.0:2380" \
  --initial-advertise-peer-urls="http://${THIS_HOST}:2380" \
  --initial-cluster="${INITIAL_CLUSTER}" \
  --initial-cluster-state="${CLUSTER_STATE}" \
  --initial-cluster-token="railway-patroni-etcd" \
  --heartbeat-interval=100 \
  --election-timeout=1000 \
  --auto-compaction-retention=1 \
  --max-snapshots=5 \
  --max-wals=5 \
  --quota-backend-bytes=8589934592 \
  --log-level=info
