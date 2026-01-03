#!/bin/bash

# Monitoring Script
# Continuously monitors the Patroni cluster status

set -e

echo "================================================"
echo "Patroni Cluster Monitor"
echo "================================================"
echo "Press Ctrl+C to stop monitoring"
echo ""

while true; do
    clear
    echo "================================================"
    echo "Patroni Cluster Status - $(date)"
    echo "================================================"
    echo ""
    
    # Show cluster status
    echo "Cluster Members:"
    docker-compose exec -T patroni1 patronictl -c /tmp/patroni.yml list 2>/dev/null || \
    docker-compose exec -T patroni2 patronictl -c /tmp/patroni.yml list 2>/dev/null || \
    docker-compose exec -T patroni3 patronictl -c /tmp/patroni.yml list 2>/dev/null || \
    echo "❌ Unable to connect to any Patroni node"
    echo ""
    
    # Show Docker container status
    echo "Container Status:"
    docker-compose ps
    echo ""
    
    # Show HAProxy stats
    echo "HAProxy Backend Status:"
    curl -s http://localhost:7000/stats 2>/dev/null | grep -A 20 "postgres_write" | head -25 || echo "❌ HAProxy not responding"
    echo ""
    
    # Show etcd health
    echo "etcd Cluster Health:"
    docker-compose exec -T etcd1 etcdctl endpoint health \
        --endpoints=http://etcd1:2379,http://etcd2:2379,http://etcd3:2379 2>/dev/null || \
    echo "❌ etcd cluster not healthy"
    echo ""
    
    echo "Refreshing in 5 seconds..."
    sleep 5
done
