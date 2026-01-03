# Quick Reference Guide

## Connection Strings

### Production (Railway)
```bash
# Write operations (primary)
postgresql://postgres:${POSTGRES_PASSWORD}@${HAPROXY_DOMAIN}:5432/postgres

# Read operations (replicas, load-balanced)
postgresql://postgres:${POSTGRES_PASSWORD}@${HAPROXY_DOMAIN}:5433/postgres
```

### Local Testing
```bash
# Write operations
postgresql://postgres:testpassword123@localhost:5432/postgres

# Read operations
postgresql://postgres:testpassword123@localhost:5433/postgres
```

## Common Commands

### Check Cluster Status
```bash
# Railway
railway run --service patroni1 patronictl -c /tmp/patroni.yml list

# Local
docker-compose exec patroni1 patronictl -c /tmp/patroni.yml list
```

### Manual Failover
```bash
# Railway
railway run --service patroni1 patronictl -c /tmp/patroni.yml failover

# Local
docker-compose exec patroni1 patronictl -c /tmp/patroni.yml failover railway-patroni
```

### View Logs
```bash
# Railway
railway logs --service patroni1

# Local
docker-compose logs -f patroni1
```

### Connect to Database
```bash
# Railway (via HAProxy)
railway run --service haproxy psql "postgresql://postgres:PASSWORD@haproxy.railway.internal:5432/postgres"

# Local
psql "postgresql://postgres:testpassword123@localhost:5432/postgres"
```

### Check etcd Health
```bash
# Railway
railway run --service etcd1 etcdctl endpoint health --endpoints=http://etcd1.railway.internal:2379

# Local
docker-compose exec etcd1 etcdctl endpoint health --endpoints=http://localhost:2379
```

### HAProxy Stats
```bash
# Railway
https://${HAPROXY_DOMAIN}:7000/stats

# Local
http://localhost:7000/stats
```

## Service Ports

| Service | Port | Purpose |
|---------|------|---------|
| PostgreSQL (write) | 5432 | Primary node only |
| PostgreSQL (read) | 5433 | All replicas (load-balanced) |
| Patroni REST API | 8008 | Health checks, metrics |
| HAProxy Stats | 7000 | Statistics dashboard |
| HAProxy Health | 8008 | Health check endpoint |
| etcd Client | 2379 | Client communication |
| etcd Peer | 2380 | Peer communication |

## Environment Variables

### Shared Variables
- `POSTGRES_PASSWORD` - PostgreSQL superuser password
- `REPLICATION_PASSWORD` - Replication user password
- `HAPROXY_STATS_PASSWORD` - HAProxy stats password

### etcd Variables
- `ETCD_NODE_NUM` - Node number (1, 2, or 3)
- `ETCD1_PRIVATE_DOMAIN` - etcd1 private domain
- `ETCD2_PRIVATE_DOMAIN` - etcd2 private domain
- `ETCD3_PRIVATE_DOMAIN` - etcd3 private domain

### Patroni Variables
- `PATRONI_SCOPE` - Cluster name
- `PATRONI_NAME` - Node name
- `PATRONI_PRIVATE_DOMAIN` - This node's private domain
- `ETCD1_PRIVATE_DOMAIN` - etcd1 private domain
- `ETCD2_PRIVATE_DOMAIN` - etcd2 private domain
- `ETCD3_PRIVATE_DOMAIN` - etcd3 private domain
- `POSTGRES_PASSWORD` - PostgreSQL password
- `REPLICATION_PASSWORD` - Replication password

### HAProxy Variables
- `PATRONI1_PRIVATE_DOMAIN` - patroni1 private domain
- `PATRONI2_PRIVATE_DOMAIN` - patroni2 private domain
- `PATRONI3_PRIVATE_DOMAIN` - patroni3 private domain
- `HAPROXY_STATS_USER` - Stats username (default: admin)
- `HAPROXY_STATS_PASSWORD` - Stats password

## Health Check Endpoints

### Patroni
```bash
# General health
curl http://patroni1.railway.internal:8008/health

# Primary check
curl http://patroni1.railway.internal:8008/primary

# Replica check
curl http://patroni1.railway.internal:8008/replica

# Metrics
curl http://patroni1.railway.internal:8008/metrics
```

### etcd
```bash
# Health check
curl http://etcd1.railway.internal:2379/health

# Metrics
curl http://etcd1.railway.internal:2379/metrics
```

### HAProxy
```bash
# Health check
curl http://haproxy.railway.internal:8008/health

# Stats (HTML)
curl http://admin:password@haproxy.railway.internal:7000/stats

# Stats (CSV)
curl http://admin:password@haproxy.railway.internal:7000/stats;csv
```

## Troubleshooting Quick Fixes

### etcd cluster not forming
```bash
# Check all etcd nodes are running
railway ps

# Check etcd logs
railway logs --service etcd1

# Verify private networking
railway run --service etcd1 env | grep ETCD
```

### Patroni not starting
```bash
# Check etcd is healthy first
railway run --service etcd1 etcdctl endpoint health

# Check Patroni logs
railway logs --service patroni1

# Verify environment variables
railway run --service patroni1 env | grep PATRONI
```

### Cannot connect via HAProxy
```bash
# Check HAProxy is running
railway ps

# Check Patroni nodes are healthy
railway run --service patroni1 curl http://localhost:8008/health

# Check HAProxy logs
railway logs --service haproxy

# Verify routing
curl http://haproxy.railway.internal:8008/health
```

### Replication lag
```bash
# Check lag
railway run --service patroni1 patronictl -c /tmp/patroni.yml list

# Check replication status
railway run --service patroni1 psql -U postgres -c "SELECT * FROM pg_stat_replication;"

# Check WAL sender status
railway run --service patroni1 psql -U postgres -c "SELECT * FROM pg_stat_wal_sender;"
```

## Backup Commands

### pg_dump
```bash
# Full backup
railway run --service patroni1 pg_dump -U postgres postgres > backup.sql

# Compressed backup
railway run --service patroni1 pg_dump -U postgres postgres | gzip > backup.sql.gz

# Custom format (recommended)
railway run --service patroni1 pg_dump -U postgres -Fc postgres > backup.dump
```

### Restore
```bash
# From SQL file
railway run --service patroni1 psql -U postgres postgres < backup.sql

# From custom format
railway run --service patroni1 pg_restore -U postgres -d postgres backup.dump
```

## Performance Monitoring

### Connection count
```bash
railway run --service patroni1 psql -U postgres -c "SELECT count(*) FROM pg_stat_activity;"
```

### Database size
```bash
railway run --service patroni1 psql -U postgres -c "SELECT pg_database_size('postgres');"
```

### Table sizes
```bash
railway run --service patroni1 psql -U postgres -c "SELECT schemaname, tablename, pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size FROM pg_tables ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC LIMIT 10;"
```

### Active queries
```bash
railway run --service patroni1 psql -U postgres -c "SELECT pid, usename, application_name, client_addr, state, query FROM pg_stat_activity WHERE state != 'idle';"
```

### Replication status
```bash
railway run --service patroni1 psql -U postgres -c "SELECT * FROM pg_stat_replication;"
```

## File Locations

### Configuration Files
- Patroni: `/etc/patroni/patroni.yml` (template), `/tmp/patroni.yml` (processed)
- HAProxy: `/usr/local/etc/haproxy/haproxy.cfg`
- PostgreSQL: `/var/lib/postgresql/data/postgresql.conf`

### Data Directories
- PostgreSQL: `/var/lib/postgresql/data`
- etcd: `/etcd-data`

### Log Files
- All services log to stdout (view via Railway logs or docker-compose logs)

## Useful SQL Queries

### Check replication lag (bytes)
```sql
SELECT client_addr, state, sent_lsn, write_lsn, flush_lsn, replay_lsn, 
       (sent_lsn - replay_lsn) AS lag_bytes
FROM pg_stat_replication;
```

### Check database connections
```sql
SELECT datname, count(*) 
FROM pg_stat_activity 
GROUP BY datname;
```

### Check long-running queries
```sql
SELECT pid, now() - query_start AS duration, query 
FROM pg_stat_activity 
WHERE state != 'idle' 
ORDER BY duration DESC;
```

### Kill a query
```sql
SELECT pg_terminate_backend(pid) 
FROM pg_stat_activity 
WHERE pid = <pid>;
```

## Scripts

### Quick Start (Local)
```bash
./scripts/quick-start.sh
```

### Test Failover (Local)
```bash
./scripts/test-failover.sh
```

### Monitor Cluster (Local)
```bash
./scripts/monitor.sh
```

## Support Resources

- **Documentation**: See README.md, DEPLOYMENT.md, FAQ.md
- **Issues**: GitHub Issues
- **Discussions**: GitHub Discussions
- **Railway**: Railway Discord community
- **Patroni**: https://patroni.readthedocs.io/

## Version Information

- PostgreSQL: 16
- Patroni: 3.2.1
- etcd: 3.5.11
- HAProxy: 2.9

---

**Tip**: Bookmark this page for quick reference during operations!
