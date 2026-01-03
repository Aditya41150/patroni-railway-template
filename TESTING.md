# Testing Guide for Patroni HA Template

## Local Testing with Docker Compose

Before deploying to Railway, you can test the setup locally using Docker Compose.

### Prerequisites

- Docker and Docker Compose installed
- At least 4GB of available RAM
- Basic understanding of PostgreSQL

### Create docker-compose.yml

```yaml
version: '3.8'

services:
  etcd1:
    build: ./etcd
    environment:
      - ETCD_NODE_NUM=1
      - ETCD1_PRIVATE_DOMAIN=etcd1
      - ETCD2_PRIVATE_DOMAIN=etcd2
      - ETCD3_PRIVATE_DOMAIN=etcd3
    volumes:
      - etcd1_data:/etcd-data
    networks:
      - patroni-net

  etcd2:
    build: ./etcd
    environment:
      - ETCD_NODE_NUM=2
      - ETCD1_PRIVATE_DOMAIN=etcd1
      - ETCD2_PRIVATE_DOMAIN=etcd2
      - ETCD3_PRIVATE_DOMAIN=etcd3
    volumes:
      - etcd2_data:/etcd-data
    networks:
      - patroni-net

  etcd3:
    build: ./etcd
    environment:
      - ETCD_NODE_NUM=3
      - ETCD1_PRIVATE_DOMAIN=etcd1
      - ETCD2_PRIVATE_DOMAIN=etcd2
      - ETCD3_PRIVATE_DOMAIN=etcd3
    volumes:
      - etcd3_data:/etcd-data
    networks:
      - patroni-net

  patroni1:
    build: ./patroni
    environment:
      - PATRONI_SCOPE=local-patroni
      - PATRONI_NAME=patroni1
      - PATRONI_PRIVATE_DOMAIN=patroni1
      - ETCD1_PRIVATE_DOMAIN=etcd1
      - ETCD2_PRIVATE_DOMAIN=etcd2
      - ETCD3_PRIVATE_DOMAIN=etcd3
      - POSTGRES_PASSWORD=testpassword
      - REPLICATION_PASSWORD=replpassword
    volumes:
      - patroni1_data:/var/lib/postgresql/data
    networks:
      - patroni-net
    depends_on:
      - etcd1
      - etcd2
      - etcd3

  patroni2:
    build: ./patroni
    environment:
      - PATRONI_SCOPE=local-patroni
      - PATRONI_NAME=patroni2
      - PATRONI_PRIVATE_DOMAIN=patroni2
      - ETCD1_PRIVATE_DOMAIN=etcd1
      - ETCD2_PRIVATE_DOMAIN=etcd2
      - ETCD3_PRIVATE_DOMAIN=etcd3
      - POSTGRES_PASSWORD=testpassword
      - REPLICATION_PASSWORD=replpassword
    volumes:
      - patroni2_data:/var/lib/postgresql/data
    networks:
      - patroni-net
    depends_on:
      - etcd1
      - etcd2
      - etcd3

  patroni3:
    build: ./patroni
    environment:
      - PATRONI_SCOPE=local-patroni
      - PATRONI_NAME=patroni3
      - PATRONI_PRIVATE_DOMAIN=patroni3
      - ETCD1_PRIVATE_DOMAIN=etcd1
      - ETCD2_PRIVATE_DOMAIN=etcd2
      - ETCD3_PRIVATE_DOMAIN=etcd3
      - POSTGRES_PASSWORD=testpassword
      - REPLICATION_PASSWORD=replpassword
    volumes:
      - patroni3_data:/var/lib/postgresql/data
    networks:
      - patroni-net
    depends_on:
      - etcd1
      - etcd2
      - etcd3

  haproxy:
    build: ./haproxy
    environment:
      - PATRONI1_PRIVATE_DOMAIN=patroni1
      - PATRONI2_PRIVATE_DOMAIN=patroni2
      - PATRONI3_PRIVATE_DOMAIN=patroni3
      - HAPROXY_STATS_USER=admin
      - HAPROXY_STATS_PASSWORD=admin
    ports:
      - "5432:5432"  # Write port
      - "5433:5433"  # Read port
      - "7000:7000"  # Stats UI
    networks:
      - patroni-net
    depends_on:
      - patroni1
      - patroni2
      - patroni3

volumes:
  etcd1_data:
  etcd2_data:
  etcd3_data:
  patroni1_data:
  patroni2_data:
  patroni3_data:

networks:
  patroni-net:
    driver: bridge
```

### Start the Cluster

```bash
docker-compose up -d
```

### Monitor Logs

```bash
# Watch all services
docker-compose logs -f

# Watch specific service
docker-compose logs -f patroni1
```

## Testing Scenarios

### 1. Test Basic Connectivity

```bash
# Connect to PostgreSQL via HAProxy
psql "postgresql://postgres:testpassword@localhost:5432/postgres"

# Run a simple query
SELECT version();
```

### 2. Test Replication

```bash
# Connect to primary and create a table
psql "postgresql://postgres:testpassword@localhost:5432/postgres" -c "
CREATE TABLE test_replication (
    id SERIAL PRIMARY KEY,
    data TEXT,
    created_at TIMESTAMP DEFAULT NOW()
);

INSERT INTO test_replication (data) VALUES ('test data 1'), ('test data 2');
"

# Wait a few seconds for replication

# Connect to read port (replicas) and verify data
psql "postgresql://postgres:testpassword@localhost:5433/postgres" -c "
SELECT * FROM test_replication;
"
```

### 3. Test Automatic Failover

```bash
# Check current cluster status
docker-compose exec patroni1 patronictl -c /tmp/patroni.yml list

# Identify the current primary (Leader)
# Stop the primary node (e.g., if patroni1 is primary)
docker-compose stop patroni1

# Wait 30-60 seconds for failover

# Check cluster status again
docker-compose exec patroni2 patronictl -c /tmp/patroni.yml list

# Verify a new primary was elected

# Restart the stopped node
docker-compose start patroni1

# Verify it rejoins as a replica
docker-compose exec patroni1 patronictl -c /tmp/patroni.yml list
```

### 4. Test Manual Failover

```bash
# Trigger manual failover
docker-compose exec patroni1 patronictl -c /tmp/patroni.yml failover local-patroni

# Follow the prompts to select new primary

# Verify the failover
docker-compose exec patroni1 patronictl -c /tmp/patroni.yml list
```

### 5. Test Load Balancing

```bash
# Create a test script
cat > test_load_balancing.sh << 'EOF'
#!/bin/bash
for i in {1..10}; do
  psql "postgresql://postgres:testpassword@localhost:5433/postgres" -c "
    SELECT inet_server_addr() as server_ip, current_database();
  "
  sleep 1
done
EOF

chmod +x test_load_balancing.sh
./test_load_balancing.sh
```

You should see connections distributed across different replica nodes.

### 6. Test HAProxy Health Checks

```bash
# Check HAProxy stats
curl http://localhost:7000/stats

# Check health endpoint
curl http://localhost:8008/health

# Check which node is primary
curl http://localhost:8008/primary
```

### 7. Test Data Persistence

```bash
# Create test data
psql "postgresql://postgres:testpassword@localhost:5432/postgres" -c "
CREATE TABLE persistence_test (id SERIAL PRIMARY KEY, data TEXT);
INSERT INTO persistence_test (data) VALUES ('persistent data');
"

# Stop all services
docker-compose down

# Start services again
docker-compose up -d

# Wait for cluster to initialize (2-3 minutes)

# Verify data persisted
psql "postgresql://postgres:testpassword@localhost:5432/postgres" -c "
SELECT * FROM persistence_test;
"
```

### 8. Test Split-Brain Prevention

```bash
# This test verifies etcd prevents split-brain

# Partition the network (simulate network failure)
docker network disconnect patroni-railway-template_patroni-net patroni1

# Wait 30 seconds

# Check cluster status from patroni2
docker-compose exec patroni2 patronictl -c /tmp/patroni.yml list

# Verify patroni1 is marked as failed and a new primary is elected if needed

# Reconnect the network
docker network connect patroni-railway-template_patroni-net patroni1

# Verify patroni1 rejoins the cluster
docker-compose exec patroni1 patronictl -c /tmp/patroni.yml list
```

### 9. Test Backup and Restore

```bash
# Create a backup
docker-compose exec patroni1 pg_dump -U postgres postgres > backup.sql

# Create test data
psql "postgresql://postgres:testpassword@localhost:5432/postgres" -c "
CREATE TABLE backup_test (id SERIAL PRIMARY KEY, data TEXT);
INSERT INTO backup_test (data) VALUES ('will be deleted');
"

# Restore from backup (this will drop the new table)
psql "postgresql://postgres:testpassword@localhost:5432/postgres" < backup.sql

# Verify backup_test table doesn't exist
psql "postgresql://postgres:testpassword@localhost:5432/postgres" -c "\dt"
```

### 10. Stress Test

```bash
# Install pgbench if not already installed
# Then run a benchmark

# Initialize pgbench
docker-compose exec patroni1 pgbench -i -U postgres postgres

# Run benchmark (10 clients, 100 transactions each)
docker-compose exec patroni1 pgbench -c 10 -t 100 -U postgres postgres

# Monitor replication lag during the test
watch -n 1 'docker-compose exec patroni1 patronictl -c /tmp/patroni.yml list'
```

## Performance Testing

### Measure Replication Lag

```bash
# Create a monitoring script
cat > monitor_lag.sh << 'EOF'
#!/bin/bash
while true; do
  docker-compose exec patroni1 patronictl -c /tmp/patroni.yml list
  sleep 5
done
EOF

chmod +x monitor_lag.sh
./monitor_lag.sh
```

### Measure Failover Time

```bash
# Script to measure failover time
cat > measure_failover.sh << 'EOF'
#!/bin/bash

echo "Starting failover test..."
START=$(date +%s)

# Stop primary
docker-compose stop patroni1

# Wait for new primary
while true; do
  STATUS=$(docker-compose exec patroni2 patronictl -c /tmp/patroni.yml list 2>/dev/null | grep Leader)
  if [ ! -z "$STATUS" ]; then
    break
  fi
  sleep 1
done

END=$(date +%s)
DURATION=$((END - START))

echo "Failover completed in $DURATION seconds"

# Restart stopped node
docker-compose start patroni1
EOF

chmod +x measure_failover.sh
./measure_failover.sh
```

## Cleanup

```bash
# Stop all services
docker-compose down

# Remove volumes (WARNING: This deletes all data)
docker-compose down -v

# Remove images
docker-compose down --rmi all
```

## CI/CD Testing

### GitHub Actions Example

```yaml
name: Test Patroni Template

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    
    steps:
      - uses: actions/checkout@v3
      
      - name: Start services
        run: docker-compose up -d
      
      - name: Wait for cluster
        run: sleep 120
      
      - name: Test connectivity
        run: |
          psql "postgresql://postgres:testpassword@localhost:5432/postgres" -c "SELECT 1"
      
      - name: Test replication
        run: |
          psql "postgresql://postgres:testpassword@localhost:5432/postgres" -c "CREATE TABLE test (id INT)"
          sleep 5
          psql "postgresql://postgres:testpassword@localhost:5433/postgres" -c "SELECT * FROM test"
      
      - name: Test failover
        run: |
          docker-compose stop patroni1
          sleep 60
          docker-compose exec patroni2 patronictl -c /tmp/patroni.yml list
      
      - name: Cleanup
        run: docker-compose down -v
```

## Expected Results

All tests should pass with:
- ✅ Cluster forms successfully
- ✅ Replication works correctly
- ✅ Failover completes in < 60 seconds
- ✅ No data loss during failover
- ✅ Load balancing distributes connections
- ✅ Data persists across restarts
- ✅ Health checks report correctly

## Troubleshooting Test Failures

If tests fail, check:
1. Docker logs: `docker-compose logs`
2. Service status: `docker-compose ps`
3. Network connectivity: `docker network inspect patroni-railway-template_patroni-net`
4. Volume mounts: `docker volume ls`
5. Resource usage: `docker stats`
