# Patroni PostgreSQL High Availability Template for Railway

[![Deploy on Railway](https://railway.app/button.svg)](https://railway.app/template/patroni-ha)

## Overview

This template deploys a highly available PostgreSQL cluster on Railway using:

- **3 Patroni/PostgreSQL nodes** - Automatic failover and leader election
- **3-node etcd cluster** - Distributed configuration store for cluster state
- **HAProxy load balancer** - Routes writes to primary, load-balances reads across replicas
- **Volume-backed storage** - Persistent data across redeploys
- **Private networking** - Secure internal communication using Railway's private network

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                         HAProxy                              │
│                    (Load Balancer)                           │
│              Public Endpoint: ${{RAILWAY_PUBLIC_DOMAIN}}    │
└────────────┬────────────────────────────────┬───────────────┘
             │                                 │
    ┌────────▼────────┐              ┌────────▼────────┐
    │  Write Traffic  │              │  Read Traffic   │
    │   (Primary)     │              │   (Replicas)    │
    └────────┬────────┘              └────────┬────────┘
             │                                 │
    ┌────────▼─────────────────────────────────▼────────┐
    │                                                    │
    │  ┌──────────┐  ┌──────────┐  ┌──────────┐       │
    │  │ Patroni  │  │ Patroni  │  │ Patroni  │       │
    │  │   Node1  │  │   Node2  │  │   Node3  │       │
    │  │(Primary) │  │(Replica) │  │(Replica) │       │
    │  └────┬─────┘  └────┬─────┘  └────┬─────┘       │
    │       │             │             │               │
    │       └─────────────┼─────────────┘               │
    │                     │                             │
    │              ┌──────▼──────┐                      │
    │              │    etcd     │                      │
    │              │   Cluster   │                      │
    │              │  (3 nodes)  │                      │
    │              └─────────────┘                      │
    │                                                    │
    └────────────────────────────────────────────────────┘
```

## Features

✅ **Automatic Failover** - Patroni automatically promotes a replica if the primary fails  
✅ **Streaming Replication** - Real-time data replication across all nodes  
✅ **Load Balancing** - HAProxy distributes read queries across replicas  
✅ **Health Checks** - Continuous monitoring of all cluster components  
✅ **Persistent Storage** - Volume-backed data directories for PostgreSQL and etcd  
✅ **Private Networking** - Secure internal communication via Railway's private network  
✅ **Zero-Downtime Updates** - Rolling updates without service interruption  

## Quick Start

1. Click the "Deploy on Railway" button above
2. Wait for all services to deploy (this may take 5-10 minutes)
3. Connect to your HA PostgreSQL cluster using the HAProxy endpoint

## Connection Details

After deployment, connect to your PostgreSQL cluster via HAProxy:

```bash
# Connection string format
postgresql://postgres:${POSTGRES_PASSWORD}@${HAPROXY_DOMAIN}:5432/postgres

# Example using psql
psql "postgresql://postgres:yourpassword@haproxy.railway.app:5432/postgres"
```

## Environment Variables

The template automatically configures the following variables:

### Global Variables
- `POSTGRES_PASSWORD` - PostgreSQL superuser password (auto-generated)
- `REPLICATION_PASSWORD` - Password for replication user (auto-generated)
- `PATRONI_SCOPE` - Cluster name (default: `railway-patroni`)

### Service-Specific Variables
Each service has its own configuration managed through Railway's private networking.

## Services

### 1. etcd Cluster (3 nodes)
- **Purpose**: Distributed configuration store for Patroni
- **Storage**: Volume-backed at `/etcd-data`
- **Internal Communication**: Uses Railway private network

### 2. Patroni/PostgreSQL Nodes (3 nodes)
- **Purpose**: PostgreSQL instances managed by Patroni
- **Storage**: Volume-backed at `/var/lib/postgresql/data`
- **Replication**: Streaming replication with automatic failover

### 3. HAProxy Load Balancer
- **Purpose**: Routes traffic to appropriate PostgreSQL nodes
- **Write Port**: 5432 (routes to primary)
- **Read Port**: 5433 (load-balances across replicas)
- **Stats UI**: Port 7000 (accessible via Railway public domain)

## Monitoring

### HAProxy Stats Dashboard

Access the HAProxy statistics dashboard at:
```
http://${HAPROXY_DOMAIN}:7000/stats
```

Default credentials:
- Username: `admin`
- Password: `${HAPROXY_STATS_PASSWORD}` (auto-generated)

### Health Checks

Check cluster health:
```bash
# Via HAProxy
curl http://${HAPROXY_DOMAIN}:8008/health

# Check Patroni cluster status (from any Patroni node)
patronictl -c /etc/patroni.yml list
```

## Maintenance

### Manual Failover

To manually trigger a failover:
```bash
# Connect to any Patroni node and run:
patronictl -c /etc/patroni.yml failover
```

### Scaling

To add more replicas:
1. Duplicate one of the Patroni service configurations
2. Update the node name and ensure unique volume
3. Deploy the new service

### Backup

Backup strategies:
1. **Continuous Archiving**: Configure WAL archiving to external storage
2. **pg_dump**: Regular logical backups
3. **Volume Snapshots**: Use Railway's volume snapshot feature

## Troubleshooting

### etcd cluster not forming
- Ensure all 3 etcd nodes are running
- Check that private networking is enabled
- Verify etcd logs for connection errors

### Patroni not starting
- Verify etcd cluster is healthy first
- Check Patroni logs for configuration errors
- Ensure PostgreSQL data directory is properly initialized

### Connection issues
- Verify HAProxy is running and healthy
- Check that the correct port is being used (5432 for writes, 5433 for reads)
- Ensure firewall rules allow traffic

## Technical Details

### Patroni Configuration
- **Loop Wait**: 10 seconds
- **Retry Timeout**: 10 seconds
- **TTL**: 30 seconds
- **Maximum Lag on Failover**: 1048576 bytes

### PostgreSQL Configuration
- **Version**: PostgreSQL 16
- **Max Connections**: 100
- **Shared Buffers**: 256MB
- **WAL Level**: replica
- **Max WAL Senders**: 10

### etcd Configuration
- **Version**: 3.5
- **Heartbeat Interval**: 100ms
- **Election Timeout**: 1000ms

## Security Considerations

1. **Passwords**: All passwords are auto-generated and stored as Railway environment variables
2. **Private Network**: Internal services communicate via Railway's private network
3. **Public Access**: Only HAProxy is exposed publicly
4. **SSL/TLS**: Consider enabling SSL for production deployments

## Cost Estimation

Approximate Railway costs (as of 2026):
- 3 Patroni nodes with volumes: ~$15-20/month each
- 3 etcd nodes with volumes: ~$10-15/month each
- 1 HAProxy instance: ~$5/month
- **Total**: ~$75-100/month

## Contributing

Contributions are welcome! Please submit issues and pull requests to improve this template.

## License

MIT License - feel free to use and modify for your needs.

## Resources

- [Patroni Documentation](https://patroni.readthedocs.io/)
- [Railway Documentation](https://docs.railway.app/)
- [PostgreSQL Documentation](https://www.postgresql.org/docs/)
- [etcd Documentation](https://etcd.io/docs/)
- [HAProxy Documentation](http://www.haproxy.org/)
