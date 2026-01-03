# Architecture Diagrams

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                         Railway Platform                             │
│                                                                       │
│  ┌────────────────────────────────────────────────────────────────┐ │
│  │                    Public Internet                              │ │
│  │                           │                                      │ │
│  │                           ▼                                      │ │
│  │                  ┌─────────────────┐                            │ │
│  │                  │    HAProxy      │                            │ │
│  │                  │ Load Balancer   │                            │ │
│  │                  │  (Public Port)  │                            │ │
│  │                  └────────┬────────┘                            │ │
│  │                           │                                      │ │
│  └───────────────────────────┼──────────────────────────────────────┘ │
│                              │                                        │
│  ┌───────────────────────────┼──────────────────────────────────────┐ │
│  │         Railway Private Network (.railway.internal)             │ │
│  │                           │                                      │ │
│  │        ┌──────────────────┴──────────────────┐                  │ │
│  │        │                                      │                  │ │
│  │        ▼                                      ▼                  │ │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐                      │ │
│  │  │ Patroni1 │  │ Patroni2 │  │ Patroni3 │                      │ │
│  │  │ Primary  │  │ Replica  │  │ Replica  │                      │ │
│  │  │ + PG 16  │  │ + PG 16  │  │ + PG 16  │                      │ │
│  │  └────┬─────┘  └────┬─────┘  └────┬─────┘                      │ │
│  │       │             │             │                              │ │
│  │       │   ┌─────────┴─────────┐   │                            │ │
│  │       │   │                   │   │                            │ │
│  │       ▼   ▼                   ▼   ▼                            │ │
│  │  ┌────────────────────────────────────┐                        │ │
│  │  │         etcd Cluster               │                        │ │
│  │  │  ┌──────┐  ┌──────┐  ┌──────┐    │                        │ │
│  │  │  │etcd1 │  │etcd2 │  │etcd3 │    │                        │ │
│  │  │  └──────┘  └──────┘  └──────┘    │                        │ │
│  │  │   (Distributed Config Store)      │                        │ │
│  │  └────────────────────────────────────┘                        │ │
│  │                                                                  │ │
│  └──────────────────────────────────────────────────────────────────┘ │
│                                                                       │
│  ┌──────────────────────────────────────────────────────────────────┐ │
│  │                    Persistent Volumes                            │ │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐                      │ │
│  │  │ PG Data1 │  │ PG Data2 │  │ PG Data3 │                      │ │
│  │  └──────────┘  └──────────┘  └──────────┘                      │ │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐                      │ │
│  │  │etcd Data1│  │etcd Data2│  │etcd Data3│                      │ │
│  │  └──────────┘  └──────────┘  └──────────┘                      │ │
│  └──────────────────────────────────────────────────────────────────┘ │
└───────────────────────────────────────────────────────────────────────┘
```

## Data Flow Diagram

### Write Operations
```
Application
    │
    │ (1) Write Query
    ▼
HAProxy:5432
    │
    │ (2) Route to Primary
    ▼
Patroni1 (Primary)
    │
    │ (3) Write to WAL
    ▼
PostgreSQL Data
    │
    │ (4) Stream WAL
    ├─────────────┬─────────────┐
    ▼             ▼             ▼
Patroni2      Patroni3      etcd
(Replica)     (Replica)   (Cluster State)
```

### Read Operations
```
Application
    │
    │ (1) Read Query
    ▼
HAProxy:5433
    │
    │ (2) Load Balance
    ├─────────────┬─────────────┐
    ▼             ▼             ▼
Patroni1      Patroni2      Patroni3
(Primary)     (Replica)     (Replica)
    │             │             │
    │ (3) Read from local data  │
    ▼             ▼             ▼
 PG Data1      PG Data2      PG Data3
```

## Failover Sequence

```
Step 1: Primary Failure Detected
┌──────────┐
│ Patroni1 │ ✗ (Primary fails)
└──────────┘
     │
     │ (1) Heartbeat timeout
     ▼
┌──────────┐
│   etcd   │ (Detects failure)
└──────────┘

Step 2: Leader Election
┌──────────┐
│   etcd   │
└────┬─────┘
     │ (2) Coordinate election
     ├─────────────┬─────────────┐
     ▼             ▼             ▼
┌──────────┐  ┌──────────┐  ┌──────────┐
│ Patroni1 │  │ Patroni2 │  │ Patroni3 │
│   ✗      │  │ Candidate│  │ Candidate│
└──────────┘  └──────────┘  └──────────┘

Step 3: New Primary Elected
┌──────────┐
│   etcd   │
└────┬─────┘
     │ (3) Elect Patroni2
     ▼
┌──────────┐  ┌──────────┐  ┌──────────┐
│ Patroni1 │  │ Patroni2 │  │ Patroni3 │
│   ✗      │  │ PRIMARY  │  │ Replica  │
└──────────┘  └────┬─────┘  └────┬─────┘
                   │              │
                   │ (4) Replication
                   └──────────────┘

Step 4: HAProxy Updates Routing
┌──────────┐
│ HAProxy  │
└────┬─────┘
     │ (5) Health checks detect new primary
     │
     ├─────────────┬─────────────┐
     ▼             ▼             ▼
┌──────────┐  ┌──────────┐  ┌──────────┐
│ Patroni1 │  │ Patroni2 │  │ Patroni3 │
│   ✗      │  │ PRIMARY  │  │ Replica  │
│          │  │  (Write) │  │  (Read)  │
└──────────┘  └──────────┘  └──────────┘

Step 5: Old Primary Rejoins (Optional)
┌──────────┐
│ Patroni1 │ (Restarts)
└────┬─────┘
     │ (6) Rejoins as replica
     ▼
┌──────────┐  ┌──────────┐  ┌──────────┐
│ Patroni1 │  │ Patroni2 │  │ Patroni3 │
│ Replica  │  │ PRIMARY  │  │ Replica  │
└──────────┘  └──────────┘  └──────────┘
```

## Network Communication

```
┌─────────────────────────────────────────────────────────────┐
│                    Communication Matrix                      │
├─────────────┬──────────┬──────────┬──────────┬──────────────┤
│   Service   │   etcd   │ Patroni  │ HAProxy  │   Public     │
├─────────────┼──────────┼──────────┼──────────┼──────────────┤
│    etcd     │ 2379/80  │    ✓     │    ✗     │      ✗       │
│             │ (cluster)│ (client) │          │              │
├─────────────┼──────────┼──────────┼──────────┼──────────────┤
│   Patroni   │   2379   │   5432   │   8008   │      ✗       │
│             │ (client) │  (repl)  │ (health) │              │
├─────────────┼──────────┼──────────┼──────────┼──────────────┤
│   HAProxy   │    ✗     │   5432   │    ✗     │ 5432/5433    │
│             │          │   8008   │          │ 7000/8008    │
├─────────────┼──────────┼──────────┼──────────┼──────────────┤
│   Public    │    ✗     │    ✗     │ 5432/33  │      ✓       │
│             │          │          │ 7000/08  │              │
└─────────────┴──────────┴──────────┴──────────┴──────────────┘

Legend:
✓ = Communication allowed
✗ = Communication blocked
Numbers = Port numbers
```

## Component Responsibilities

```
┌─────────────────────────────────────────────────────────────┐
│                         etcd Cluster                         │
│  ┌────────────────────────────────────────────────────────┐ │
│  │ • Stores cluster configuration                         │ │
│  │ • Coordinates leader election                          │ │
│  │ • Maintains distributed lock                           │ │
│  │ • Provides consistent key-value store                  │ │
│  │ • Ensures quorum for decisions                         │ │
│  └────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│                      Patroni Nodes                           │
│  ┌────────────────────────────────────────────────────────┐ │
│  │ • Manages PostgreSQL lifecycle                         │ │
│  │ • Performs automatic failover                          │ │
│  │ • Handles replication setup                            │ │
│  │ • Provides REST API for monitoring                     │ │
│  │ • Executes health checks                               │ │
│  │ • Manages configuration changes                        │ │
│  └────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│                      PostgreSQL                              │
│  ┌────────────────────────────────────────────────────────┐ │
│  │ • Stores and retrieves data                            │ │
│  │ • Executes SQL queries                                 │ │
│  │ • Handles transactions                                 │ │
│  │ • Streams WAL to replicas                              │ │
│  │ • Maintains data consistency                           │ │
│  └────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│                        HAProxy                               │
│  ┌────────────────────────────────────────────────────────┐ │
│  │ • Routes client connections                            │ │
│  │ • Load balances read queries                           │ │
│  │ • Performs health checks                               │ │
│  │ • Provides statistics dashboard                        │ │
│  │ • Handles connection pooling                           │ │
│  └────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

## Deployment Timeline

```
Time    Event
─────────────────────────────────────────────────────────────
0:00    │ Deploy template to Railway
        │
0:30    │ ┌─────────────────────┐
        │ │ etcd nodes starting │
        │ └─────────────────────┘
        │
2:00    │ ┌─────────────────────────────┐
        │ │ etcd cluster formed         │
        │ └─────────────────────────────┘
        │
3:00    │ ┌──────────────────────────────┐
        │ │ Patroni nodes starting       │
        │ └──────────────────────────────┘
        │
5:00    │ ┌──────────────────────────────┐
        │ │ PostgreSQL initializing      │
        │ └──────────────────────────────┘
        │
10:00   │ ┌──────────────────────────────┐
        │ │ Primary elected              │
        │ └──────────────────────────────┘
        │
12:00   │ ┌──────────────────────────────┐
        │ │ Replicas syncing             │
        │ └──────────────────────────────┘
        │
15:00   │ ┌──────────────────────────────┐
        │ │ HAProxy starting             │
        │ └──────────────────────────────┘
        │
17:00   │ ┌──────────────────────────────┐
        │ │ Health checks passing        │
        │ └──────────────────────────────┘
        │
20:00   │ ✓ Cluster ready for connections
```

## Resource Allocation

```
┌─────────────────────────────────────────────────────────────┐
│                    Resource Distribution                     │
│                                                               │
│  Patroni Nodes (3x)          etcd Nodes (3x)    HAProxy      │
│  ┌─────────────────┐         ┌──────────────┐  ┌─────────┐  │
│  │ CPU:  2 vCPU    │         │ CPU: 1 vCPU  │  │ CPU: 1  │  │
│  │ RAM:  4 GB      │         │ RAM: 1 GB    │  │ RAM:512M│  │
│  │ Disk: 50 GB SSD │         │ Disk: 10 GB  │  │ Disk: - │  │
│  └─────────────────┘         └──────────────┘  └─────────┘  │
│                                                               │
│  Total Resources:                                             │
│  • CPU:  10 vCPU                                             │
│  • RAM:  15.5 GB                                             │
│  • Disk: 180 GB                                              │
└─────────────────────────────────────────────────────────────┘
```

---

These diagrams provide a visual understanding of the Patroni HA cluster architecture, data flow, failover process, and resource allocation.
