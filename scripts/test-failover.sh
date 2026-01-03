#!/bin/bash

# Test Failover Script
# This script tests automatic failover by stopping the primary node

set -e

echo "================================================"
echo "Patroni Failover Test"
echo "================================================"
echo ""

# Check cluster status
echo "Current cluster status:"
docker-compose exec -T patroni1 patronictl -c /tmp/patroni.yml list
echo ""

# Identify the primary
PRIMARY=$(docker-compose exec -T patroni1 patronictl -c /tmp/patroni.yml list | grep Leader | awk '{print $2}')

if [ -z "$PRIMARY" ]; then
    echo "❌ Could not identify primary node"
    exit 1
fi

echo "Current primary: $PRIMARY"
echo ""

# Record start time
START_TIME=$(date +%s)

echo "Stopping primary node: $PRIMARY"
docker-compose stop $PRIMARY
echo ""

echo "Waiting for failover to complete..."
echo "This should take less than 60 seconds..."
echo ""

# Wait for new primary
MAX_WAIT=120
ELAPSED=0
NEW_PRIMARY=""

while [ $ELAPSED -lt $MAX_WAIT ]; do
    sleep 5
    ELAPSED=$((ELAPSED + 5))
    
    # Try to get cluster status from a different node
    for NODE in patroni1 patroni2 patroni3; do
        if [ "$NODE" != "$PRIMARY" ]; then
            STATUS=$(docker-compose exec -T $NODE patronictl -c /tmp/patroni.yml list 2>/dev/null || echo "")
            if [ ! -z "$STATUS" ]; then
                NEW_PRIMARY=$(echo "$STATUS" | grep Leader | awk '{print $2}')
                if [ ! -z "$NEW_PRIMARY" ] && [ "$NEW_PRIMARY" != "$PRIMARY" ]; then
                    break 2
                fi
            fi
        fi
    done
    
    echo "  Elapsed: ${ELAPSED}s"
done

# Record end time
END_TIME=$(date +%s)
FAILOVER_TIME=$((END_TIME - START_TIME))

echo ""
echo "================================================"

if [ ! -z "$NEW_PRIMARY" ]; then
    echo "✅ Failover successful!"
    echo "   Old primary: $PRIMARY"
    echo "   New primary: $NEW_PRIMARY"
    echo "   Failover time: ${FAILOVER_TIME} seconds"
else
    echo "❌ Failover failed or timed out"
    echo "   Elapsed time: ${FAILOVER_TIME} seconds"
fi

echo "================================================"
echo ""

# Show current cluster status
echo "Current cluster status:"
for NODE in patroni1 patroni2 patroni3; do
    if [ "$NODE" != "$PRIMARY" ]; then
        docker-compose exec -T $NODE patronictl -c /tmp/patroni.yml list 2>/dev/null && break
    fi
done
echo ""

# Restart the stopped node
echo "Restarting stopped node: $PRIMARY"
docker-compose start $PRIMARY
echo ""

echo "Waiting for node to rejoin cluster..."
sleep 20
echo ""

echo "Final cluster status:"
docker-compose exec -T patroni1 patronictl -c /tmp/patroni.yml list 2>/dev/null || \
docker-compose exec -T patroni2 patronictl -c /tmp/patroni.yml list 2>/dev/null || \
docker-compose exec -T patroni3 patronictl -c /tmp/patroni.yml list
echo ""

echo "Test complete!"
