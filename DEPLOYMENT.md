# Deployment Guide for Patroni HA Template on Railway

## Prerequisites

- Railway account with access to private networking
- Basic understanding of PostgreSQL and high availability concepts
- Railway CLI (optional, for local testing)

## Deployment Steps

### Step 1: Deploy the Template

1. Click the "Deploy on Railway" button in the README
2. Railway will create a new project with all 7 services:
   - 3 etcd nodes
   - 3 Patroni/PostgreSQL nodes
   - 1 HAProxy load balancer

### Step 2: Configure Environment Variables

The template automatically generates the following shared variables:
- `POSTGRES_PASSWORD` - Superuser password for PostgreSQL
- `REPLICATION_PASSWORD` - Password for replication user
- `HAPROXY_STATS_PASSWORD` - Password for HAProxy stats dashboard

**Important**: Save these passwords securely! You'll need them to connect to your database.

### Step 3: Wait for Services to Initialize

The deployment follows this order:

1. **etcd cluster** (5-10 minutes)
   - All 3 etcd nodes must start and form a cluster
   - Check logs for "etcd cluster is ready"

2. **Patroni nodes** (10-15 minutes)
   - Wait for etcd cluster to be healthy
   - Initialize PostgreSQL on each node
   - Elect a primary and configure replication
   - Check logs for "cluster initialized successfully"

3. **HAProxy** (2-3 minutes)
   - Wait for at least one Patroni node
   - Configure routing rules
   - Expose public endpoint

**Total deployment time**: 15-25 minutes

### Step 4: Verify Deployment

#### Check etcd Cluster Health

From any etcd service, run:
```bash
etcdctl endpoint health --endpoints=http://etcd1.railway.internal:2379,http://etcd2.railway.internal:2379,http://etcd3.railway.internal:2379
```

Expected output:
```
http://etcd1.railway.internal:2379 is healthy
http://etcd2.railway.internal:2379 is healthy
http://etcd3.railway.internal:2379 is healthy
```

#### Check Patroni Cluster Status

From any Patroni service, run:
```bash
patronictl -c /tmp/patroni.yml list
```

Expected output:
```
+ Cluster: railway-patroni (7123456789012345678) -----+----+-----------+
| Member   | Host                          | Role    | State   | TL | Lag in MB |
+----------+-------------------------------+---------+---------+----+-----------+
| patroni1 | patroni1.railway.internal     | Leader  | running |  1 |           |
| patroni2 | patroni2.railway.internal     | Replica | running |  1 |         0 |
| patroni3 | patroni3.railway.internal     | Replica | running |  1 |         0 |
+----------+-------------------------------+---------+---------+----+-----------+
```

#### Check HAProxy Status

Access the HAProxy stats dashboard:
```
https://<haproxy-domain>.railway.app:7000/stats
```

Login with:
- Username: `admin`
- Password: Value of `HAPROXY_STATS_PASSWORD`

### Step 5: Connect to Your Database

#### Connection String

```bash
postgresql://postgres:<POSTGRES_PASSWORD>@<haproxy-domain>.railway.app:5432/postgres
```

#### Using psql

```bash
psql "postgresql://postgres:yourpassword@haproxy.railway.app:5432/postgres"
```

#### Using Connection Pooler (Recommended for Applications)

For write operations:
```bash
postgresql://postgres:<POSTGRES_PASSWORD>@<haproxy-domain>.railway.app:5432/postgres
```

For read operations (load-balanced across replicas):
```bash
postgresql://postgres:<POSTGRES_PASSWORD>@<haproxy-domain>.railway.app:5433/postgres
```

## Post-Deployment Configuration

### Enable SSL/TLS (Recommended for Production)

1. Generate SSL certificates
2. Update Patroni configuration to enable SSL
3. Update HAProxy to use SSL passthrough or termination
4. Update connection strings to use `sslmode=require`

### Configure Backups

#### Option 1: WAL Archiving to S3

Add to Patroni configuration:
```yaml
postgresql:
  parameters:
    archive_mode: on
    archive_command: 'aws s3 cp %p s3://your-bucket/wal/%f'
```

#### Option 2: pg_dump Scheduled Backups

Create a separate Railway service with a cron job:
```bash
0 2 * * * pg_dump "postgresql://postgres:$POSTGRES_PASSWORD@haproxy.railway.internal:5432/postgres" | gzip > backup-$(date +\%Y\%m\%d).sql.gz
```

### Monitoring Setup

#### Prometheus Metrics

Patroni exposes metrics at `http://<patroni-node>:8008/metrics`

Add a Prometheus service to scrape these endpoints.

#### Logging

All services log to stdout. Use Railway's built-in log aggregation or forward to external services like:
- Datadog
- New Relic
- Grafana Cloud

## Troubleshooting

### etcd Cluster Not Forming

**Symptoms**: etcd nodes continuously restarting

**Solutions**:
1. Check that all 3 etcd services are running
2. Verify private networking is enabled
3. Check etcd logs for connection errors
4. Ensure volumes are properly mounted

### Patroni Not Starting

**Symptoms**: Patroni nodes stuck in initialization

**Solutions**:
1. Verify etcd cluster is healthy first
2. Check Patroni logs for configuration errors
3. Ensure PostgreSQL data directory has correct permissions
4. Verify environment variables are set correctly

### Cannot Connect via HAProxy

**Symptoms**: Connection refused or timeout

**Solutions**:
1. Check that HAProxy service is running
2. Verify at least one Patroni node is healthy
3. Check HAProxy logs for routing errors
4. Ensure the correct port is being used (5432 for writes, 5433 for reads)

### Replication Lag

**Symptoms**: Replicas falling behind primary

**Solutions**:
1. Check network connectivity between nodes
2. Increase `max_wal_senders` in PostgreSQL configuration
3. Monitor disk I/O on replica nodes
4. Consider upgrading Railway service resources

### Split-Brain Scenario

**Symptoms**: Multiple primaries in the cluster

**Solutions**:
1. This should be prevented by etcd, but if it occurs:
2. Stop all Patroni nodes
3. Identify the correct primary (most recent data)
4. Reinitialize other nodes as replicas
5. Restart services in order: etcd → primary → replicas → HAProxy

## Scaling

### Adding More Replicas

1. Duplicate a Patroni service configuration
2. Update `PATRONI_NAME` to a unique value (e.g., `patroni4`)
3. Create a new volume for the data directory
4. Deploy the new service
5. Update HAProxy configuration to include the new node

### Removing Replicas

1. Remove the node from HAProxy configuration
2. Stop the Patroni service
3. Remove the node from the cluster:
   ```bash
   patronictl -c /tmp/patroni.yml remove patroni3
   ```
4. Delete the Railway service

## Maintenance

### Performing a Manual Failover

```bash
# From any Patroni node
patronictl -c /tmp/patroni.yml failover railway-patroni
```

Follow the prompts to select the new primary.

### Updating PostgreSQL Version

1. Update the Dockerfile to use a new PostgreSQL version
2. Test in a staging environment first
3. Perform a rolling update:
   - Update one replica at a time
   - Wait for it to catch up
   - Finally update the primary (triggers automatic failover)

### Restarting Services

**Order matters!**

1. Restart etcd nodes one at a time (wait for cluster to stabilize)
2. Restart Patroni replicas one at a time
3. Restart Patroni primary (triggers failover)
4. Restart HAProxy

## Best Practices

1. **Always use HAProxy** for application connections (never connect directly to Patroni nodes)
2. **Monitor replication lag** and set up alerts
3. **Test failover regularly** to ensure it works as expected
4. **Keep backups** in external storage (S3, GCS, etc.)
5. **Use read replicas** for read-heavy workloads
6. **Enable SSL/TLS** for production deployments
7. **Set up monitoring** and alerting
8. **Document your configuration** and any customizations

## Security Checklist

- [ ] Change default passwords
- [ ] Enable SSL/TLS
- [ ] Restrict HAProxy stats dashboard access
- [ ] Use Railway's private networking for internal communication
- [ ] Regularly update PostgreSQL and dependencies
- [ ] Enable audit logging
- [ ] Implement backup encryption
- [ ] Set up firewall rules (if using Railway's public networking)

## Support

For issues specific to this template:
- Open an issue on the GitHub repository
- Join the Railway Discord community

For Patroni-specific questions:
- [Patroni Documentation](https://patroni.readthedocs.io/)
- [Patroni GitHub Issues](https://github.com/zalando/patroni/issues)
