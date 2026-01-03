# Frequently Asked Questions (FAQ)

## General Questions

### What is Patroni?

Patroni is a template for high availability PostgreSQL solutions using Python. It manages PostgreSQL configuration, handles automatic failover, and provides a REST API for monitoring and management.

### Why use Patroni on Railway?

Railway provides:
- Easy deployment with one-click templates
- Built-in private networking for secure inter-service communication
- Volume-backed storage for data persistence
- Automatic SSL certificates
- Simple environment variable management

### How much does this cost?

Approximate monthly costs on Railway:
- 3 Patroni nodes with volumes: $45-60
- 3 etcd nodes with volumes: $30-45
- 1 HAProxy instance: $5
- **Total**: ~$80-110/month

Costs vary based on resource usage and Railway's pricing.

### Is this production-ready?

Yes, with proper configuration:
- ✅ Enable SSL/TLS
- ✅ Set up automated backups
- ✅ Configure monitoring and alerting
- ✅ Test failover procedures
- ✅ Document your setup
- ✅ Have a disaster recovery plan

## Deployment Questions

### How long does deployment take?

- Initial deployment: 15-25 minutes
- etcd cluster formation: 5-10 minutes
- Patroni initialization: 10-15 minutes
- HAProxy startup: 2-3 minutes

### Can I deploy with fewer than 3 nodes?

Not recommended. A 3-node cluster provides:
- Quorum for etcd (requires majority)
- High availability (can lose 1 node)
- Load balancing for reads

A 2-node setup cannot achieve quorum if one node fails.

### What if deployment fails?

Common issues:
1. **etcd not forming**: Check that all 3 etcd services are running
2. **Patroni stuck**: Verify etcd is healthy first
3. **HAProxy not starting**: Ensure at least one Patroni node is up

Check service logs in Railway dashboard for specific errors.

### Can I use a different PostgreSQL version?

Yes! Update the Dockerfile:
```dockerfile
FROM postgres:15-alpine  # or postgres:14-alpine, etc.
```

Test thoroughly before deploying to production.

## Configuration Questions

### How do I change PostgreSQL settings?

Edit `patroni/patroni.yml`:
```yaml
bootstrap:
  dcs:
    postgresql:
      parameters:
        max_connections: 200  # Change this
        shared_buffers: 512MB  # And this
```

Redeploy the Patroni services.

### How do I add more replicas?

1. In Railway, duplicate a Patroni service
2. Update environment variables:
   - `PATRONI_NAME=patroni4`
   - Keep other variables the same
3. Add a new volume for data storage
4. Update HAProxy configuration to include the new node
5. Deploy

### How do I enable SSL/TLS?

This requires:
1. Generate SSL certificates
2. Mount certificates in Patroni containers
3. Update `patroni.yml` to enable SSL
4. Update HAProxy for SSL passthrough
5. Update connection strings to use `sslmode=require`

See [SSL/TLS Guide](docs/ssl-setup.md) for details.

### Can I use a different load balancer?

Yes! Alternatives:
- **PgBouncer**: Connection pooling with load balancing
- **PgPool-II**: Advanced load balancing and connection pooling
- **Nginx**: Simple TCP load balancing

Replace the HAProxy service with your preferred option.

## Operations Questions

### How do I connect to the database?

Via HAProxy (recommended):
```bash
# For writes (primary)
psql "postgresql://postgres:PASSWORD@haproxy.railway.app:5432/postgres"

# For reads (replicas)
psql "postgresql://postgres:PASSWORD@haproxy.railway.app:5433/postgres"
```

### How do I perform a manual failover?

```bash
# Connect to any Patroni node via Railway CLI
railway run bash

# Inside the container
patronictl -c /tmp/patroni.yml failover railway-patroni
```

Follow the prompts to select the new primary.

### How do I check cluster status?

```bash
# Via Railway CLI
railway run --service patroni1 patronictl -c /tmp/patroni.yml list
```

Or check the HAProxy stats dashboard at `https://haproxy.railway.app:7000/stats`

### How do I backup the database?

**Option 1: pg_dump**
```bash
railway run --service patroni1 pg_dump -U postgres postgres > backup.sql
```

**Option 2: WAL Archiving**
Configure in `patroni.yml`:
```yaml
postgresql:
  parameters:
    archive_mode: on
    archive_command: 'aws s3 cp %p s3://bucket/wal/%f'
```

**Option 3: Volume Snapshots**
Use Railway's volume snapshot feature (when available).

### How do I restore from backup?

```bash
# Stop all Patroni nodes
railway down --service patroni1
railway down --service patroni2
railway down --service patroni3

# Restore to primary node
railway run --service patroni1 psql -U postgres postgres < backup.sql

# Start all nodes
railway up --service patroni1
railway up --service patroni2
railway up --service patroni3
```

### How do I update PostgreSQL?

1. Test in a staging environment first
2. Update Dockerfile with new version
3. Perform rolling update:
   - Update replica 1, wait for sync
   - Update replica 2, wait for sync
   - Update primary (triggers failover)
4. Verify cluster health

## Troubleshooting Questions

### Why is replication lagging?

Common causes:
- High write load on primary
- Network issues between nodes
- Insufficient resources on replicas
- Disk I/O bottlenecks

Check:
```bash
patronictl -c /tmp/patroni.yml list
```

Look at the "Lag in MB" column.

### What happens if the primary fails?

1. Patroni detects failure (within 30 seconds)
2. etcd coordinates leader election
3. A replica is promoted to primary
4. Other replicas start replicating from new primary
5. HAProxy automatically routes to new primary

Total failover time: typically 30-60 seconds.

### What happens if etcd fails?

- **1 etcd node fails**: Cluster continues normally (quorum maintained)
- **2 etcd nodes fail**: Cluster enters read-only mode (no failover possible)
- **3 etcd nodes fail**: Cluster stops accepting writes

Always maintain at least 2 healthy etcd nodes.

### Why can't I connect via HAProxy?

Check:
1. HAProxy service is running
2. At least one Patroni node is healthy
3. Correct port (5432 for writes, 5433 for reads)
4. Correct password
5. Firewall rules allow traffic

### How do I recover from split-brain?

This should be prevented by etcd, but if it occurs:

1. Stop all Patroni nodes
2. Identify the correct primary (most recent data)
3. Reinitialize other nodes:
   ```bash
   patronictl -c /tmp/patroni.yml reinit railway-patroni patroni2
   ```
4. Restart services

## Performance Questions

### How do I optimize for read-heavy workloads?

1. Add more read replicas
2. Use connection pooling (PgBouncer)
3. Configure HAProxy to load-balance reads
4. Optimize PostgreSQL settings:
   ```yaml
   effective_cache_size: 4GB
   random_page_cost: 1.1
   ```

### How do I optimize for write-heavy workloads?

1. Increase resources on primary node
2. Optimize PostgreSQL settings:
   ```yaml
   shared_buffers: 512MB
   wal_buffers: 16MB
   checkpoint_completion_target: 0.9
   ```
3. Use faster storage (SSD)
4. Consider connection pooling

### What are the resource requirements?

Minimum per Patroni node:
- CPU: 1 vCPU
- RAM: 1GB
- Storage: 10GB

Recommended for production:
- CPU: 2-4 vCPU
- RAM: 4-8GB
- Storage: 50-100GB SSD

## Security Questions

### How do I secure the cluster?

1. **Use strong passwords**: Auto-generated by Railway
2. **Enable SSL/TLS**: Encrypt connections
3. **Restrict access**: Use Railway's private networking
4. **Regular updates**: Keep PostgreSQL and dependencies updated
5. **Audit logging**: Enable PostgreSQL audit logs
6. **Backup encryption**: Encrypt backups at rest

### Should I expose Patroni nodes publicly?

No! Only HAProxy should be publicly accessible. Patroni nodes should only communicate via Railway's private network.

### How do I rotate passwords?

1. Update `POSTGRES_PASSWORD` in Railway
2. Restart all Patroni nodes
3. Update application connection strings
4. Update HAProxy configuration if needed

## Monitoring Questions

### What should I monitor?

Key metrics:
- Cluster status (primary/replica roles)
- Replication lag
- Connection count
- Query performance
- Disk usage
- CPU and memory usage
- Failover events

### How do I set up monitoring?

Options:
1. **HAProxy Stats**: Built-in dashboard at `:7000/stats`
2. **Patroni REST API**: Metrics at `:8008/metrics`
3. **PostgreSQL Stats**: `pg_stat_*` views
4. **External Monitoring**: Datadog, New Relic, Grafana Cloud

### How do I set up alerts?

Use Railway's monitoring or external services:
- Alert on replication lag > 100MB
- Alert on failover events
- Alert on service downtime
- Alert on disk usage > 80%
- Alert on connection count > 80% of max

## Migration Questions

### How do I migrate from standalone PostgreSQL?

1. Deploy this template
2. Take a backup of your existing database
3. Restore to the new cluster
4. Test thoroughly
5. Update application connection strings
6. Monitor for issues
7. Decommission old database

### Can I migrate with zero downtime?

Yes, using logical replication:
1. Set up this cluster
2. Configure logical replication from old to new
3. Wait for sync
4. Switch application to new cluster
5. Verify and decommission old cluster

See [Migration Guide](docs/migration.md) for details.

## Support Questions

### Where can I get help?

1. Check this FAQ
2. Read the [README](README.md) and [DEPLOYMENT](DEPLOYMENT.md)
3. Search GitHub issues
4. Ask in GitHub Discussions
5. Join Railway Discord community
6. Open a GitHub issue

### How do I report a bug?

1. Search existing issues
2. Create a new issue with:
   - Clear description
   - Steps to reproduce
   - Expected vs actual behavior
   - Environment details
   - Relevant logs

### How do I request a feature?

Open a GitHub issue with:
- Feature description
- Use case
- Expected behavior
- Alternatives considered

## Contributing Questions

### How can I contribute?

See [CONTRIBUTING.md](CONTRIBUTING.md) for:
- Code contributions
- Documentation improvements
- Bug reports
- Feature requests
- Testing and feedback

### What are good first contributions?

- Documentation improvements
- Adding examples
- Fixing typos
- Improving error messages
- Adding tests

---

**Didn't find your answer?** Open a [GitHub Discussion](https://github.com/your-repo/discussions) or [issue](https://github.com/your-repo/issues).
