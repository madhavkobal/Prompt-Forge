# High Availability Configuration

This directory contains all configuration files and resources for deploying PromptForge in a high availability setup.

## Quick Start

```bash
# Deploy HA with Docker Compose (single-host)
./ha-setup.sh --compose

# Or deploy with Docker Swarm (multi-host capable)
./ha/swarm/setup-swarm.sh --init
./ha/swarm/setup-swarm.sh --deploy

# Check health
./ha-setup.sh --check
```

## Directory Structure

```
ha/
├── nginx/                    # Nginx load balancer configuration
│   └── load-balancer.conf   # Multi-backend load balancing config
├── postgresql/               # PostgreSQL replication setup
│   ├── primary/              # Primary server config
│   │   ├── postgresql.conf  # Replication-enabled config
│   │   └── pg_hba.conf      # Access control with replication
│   ├── replica/              # Replica server config
│   │   └── setup-replica.sh # Automated replica setup
│   └── init/                 # Initialization scripts
│       └── 01-setup-replication.sh
├── redis/                    # Redis HA configuration
│   └── sentinel.conf        # Redis Sentinel config (quorum-based failover)
├── swarm/                    # Docker Swarm orchestration
│   ├── docker-stack.yml     # Swarm stack definition
│   └── setup-swarm.sh       # Swarm setup and management
└── README.md                 # This file
```

## Components

### 1. Load Balancing (Nginx)

**Features:**
- Distributes traffic across 3 backend instances
- Least-connection load balancing
- Automatic failover on backend failure
- Health checks with max_fails/fail_timeout
- Session keep-alive
- SSL/TLS termination

**Configuration:**
- File: `nginx/load-balancer.conf`
- Upstream: `backend_api` (3 backends)
- Method: `least_conn` (least connections)
- Failover: `proxy_next_upstream` (automatic)

### 2. Database Replication (PostgreSQL)

**Features:**
- Streaming replication (primary → replica)
- Hot standby (replica serves read queries)
- Continuous WAL streaming
- Replication slots
- Point-in-time recovery capable

**Configuration:**
- Primary: `postgresql/primary/`
  - WAL level: replica
  - Max WAL senders: 5
  - Replication slots: 5
- Replica: `postgresql/replica/`
  - Automated setup via pg_basebackup
  - Hot standby: enabled
  - Replay lag tracking

**Failover:**
- Manual: `docker exec promptforge-postgres-replica pg_ctl promote`
- Auto: Use Patroni or pg_auto_failover (optional)

### 3. Redis High Availability (Sentinel)

**Features:**
- Automatic failover
- Master-slave replication
- 3 Sentinel instances (quorum-based)
- Configurable failover timing
- Client-side master discovery

**Configuration:**
- Sentinel: `redis/sentinel.conf`
  - Quorum: 2 (out of 3 sentinels)
  - Down-after: 5 seconds
  - Failover timeout: 10 seconds
  - Master name: `mymaster`

**Failover Process:**
1. Sentinels detect master failure (5s)
2. Quorum reached (2 sentinels agree)
3. Leader elected
4. Replica promoted to master
5. Clients discover new master

### 4. Container Orchestration (Docker Swarm)

**Features:**
- Service scaling (horizontal)
- Rolling updates (zero downtime)
- Automatic load balancing (routing mesh)
- Health checks and auto-restart
- Multi-host support
- Built-in secrets management

**Configuration:**
- Stack: `swarm/docker-stack.yml`
- Services:
  - Backend: 3 replicas
  - Frontend: 2 replicas
  - Nginx: 2 replicas
  - PostgreSQL: 1 primary (manager node)
  - Redis: 1 master + 3 sentinels

## Deployment Options

### Option 1: Docker Compose HA (Recommended for Single Host)

**Pros:**
- Simpler setup
- Easier to debug
- Good for small-medium deployments
- All services on one host

**Cons:**
- Single point of failure (host)
- Manual scaling
- No built-in orchestration

**Deploy:**
```bash
./ha-setup.sh --compose
```

### Option 2: Docker Swarm (Recommended for Multi-Host)

**Pros:**
- True high availability across hosts
- Automatic service discovery
- Rolling updates
- Built-in load balancing
- Easy scaling

**Cons:**
- More complex setup
- Requires swarm cluster
- Learning curve

**Deploy:**
```bash
./ha/swarm/setup-swarm.sh --init
./ha/swarm/setup-swarm.sh --deploy
```

## Architecture

```
                    ┌─────────────────────┐
                    │   Nginx LB (x2)     │
                    │  Load Balancer      │
                    └──────────┬──────────┘
                               │
        ┌──────────────────────┼──────────────────────┐
        │                      │                      │
   ┌────▼────┐           ┌─────▼────┐          ┌─────▼────┐
   │Backend 1│           │Backend 2 │          │Backend 3 │
   │FastAPI  │           │FastAPI   │          │FastAPI   │
   └────┬────┘           └─────┬────┘          └─────┬────┘
        │                      │                      │
        └──────────────────────┼──────────────────────┘
                               │
        ┌──────────────────────┼──────────────────────┐
        │                      │                      │
   ┌────▼─────────┐      ┌─────▼────────┐      ┌─────▼─────┐
   │PostgreSQL    │      │Redis Master  │      │Frontend 1 │
   │Primary       │◄─────┤              │      │React      │
   └────┬─────────┘      └──────┬───────┘      └───────────┘
        │                       │
        │ Replication          │ Replication
        ▼                       ▼
   ┌─────────────┐      ┌──────────────┐      ┌───────────┐
   │PostgreSQL   │      │Redis Replica │      │Frontend 2 │
   │Replica      │      │              │      │React      │
   └─────────────┘      └──────┬───────┘      └───────────┘
                               │
                         ┌─────┴─────┐
                    ┌────▼────┐ ┌────▼────┐ ┌────▼────┐
                    │Sentinel1│ │Sentinel2│ │Sentinel3│
                    │(Quorum) │ │(Quorum) │ │(Quorum) │
                    └─────────┘ └─────────┘ └─────────┘
```

## Resource Requirements

### Minimum (Single Host HA)
- CPU: 8 cores
- RAM: 16 GB
- Disk: 100 GB SSD
- Network: 1 Gbps

### Recommended (Production)
- CPU: 16 cores
- RAM: 32 GB
- Disk: 500 GB SSD (RAID)
- Network: 10 Gbps

### Per-Service Allocation

| Service | CPU | RAM | Count |
|---------|-----|-----|-------|
| Backend | 1.5c | 1.5GB | 3 |
| Frontend | 0.5c | 512MB | 2 |
| PostgreSQL Primary | 2c | 2GB | 1 |
| PostgreSQL Replica | 2c | 2GB | 1 |
| Redis Master | 1c | 512MB | 1 |
| Redis Replica | 1c | 512MB | 1 |
| Sentinel | 0.5c | 256MB | 3 |
| Nginx | 1c | 512MB | 2 |

## Monitoring

### Health Checks

```bash
# All services
./ha-setup.sh --check

# Individual components
docker-compose -f docker-compose.ha.yml ps
docker service ls  # For Swarm

# Nginx status
curl http://localhost:8080/nginx_status

# PostgreSQL replication
docker exec promptforge-postgres-primary psql -U promptforge -c \
  "SELECT * FROM pg_stat_replication;"

# Redis Sentinel
docker exec promptforge-redis-sentinel-1 redis-cli -p 26379 \
  SENTINEL master mymaster
```

### Logs

```bash
# All services
docker-compose -f docker-compose.ha.yml logs -f

# Specific service
docker-compose -f docker-compose.ha.yml logs -f backend1

# Swarm service
docker service logs -f promptforge_backend
```

## Failover Testing

```bash
# Test backend failover
docker stop promptforge-backend-1
curl http://localhost/api/health  # Should still work

# Test Redis failover
docker stop promptforge-redis-master
# Wait 5-10 seconds for Sentinel failover
docker exec promptforge-redis-sentinel-1 redis-cli -p 26379 \
  SENTINEL get-master-addr-by-name mymaster  # Should show new master

# Test PostgreSQL failover (manual)
docker stop promptforge-postgres-primary
docker exec promptforge-postgres-replica pg_ctl promote
```

## Scaling

### Docker Compose

```bash
# Edit docker-compose.ha.yml to add more instances
# Then restart services
docker-compose -f docker-compose.ha.yml up -d
```

### Docker Swarm

```bash
# Scale backend to 5 instances
docker service scale promptforge_backend=5

# Scale frontend to 3 instances
docker service scale promptforge_frontend=3

# View current scale
docker service ls
```

## Troubleshooting

### Backend not load balancing

```bash
# Check Nginx config
docker exec promptforge-nginx-lb nginx -t

# Check upstream status
docker logs promptforge-nginx-lb | grep upstream

# Restart nginx
docker-compose -f docker-compose.ha.yml restart nginx
```

### PostgreSQL replication lag

```bash
# Check lag
docker exec promptforge-postgres-primary psql -U promptforge -c "
SELECT
  client_addr,
  state,
  pg_wal_lsn_diff(pg_current_wal_lsn(), replay_lsn) AS lag_bytes
FROM pg_stat_replication;"

# If lag is high, check:
# 1. Network between primary and replica
# 2. Replica resources (CPU/disk)
# 3. Primary write load
```

### Redis Sentinel not failing over

```bash
# Check sentinel status
docker exec promptforge-redis-sentinel-1 redis-cli -p 26379 \
  SENTINEL master mymaster

# Check all sentinels are running
docker-compose -f docker-compose.ha.yml ps | grep sentinel

# Manual failover
docker exec promptforge-redis-sentinel-1 redis-cli -p 26379 \
  SENTINEL failover mymaster
```

## Documentation

For complete documentation, see:
- **[High Availability Guide](../docs/high-availability.md)** - Complete HA documentation
- **[Database Management](../docs/database-management.md)** - Database replication details
- **[Deployment Guide](../docs/deployment-onprem.md)** - Production deployment

## Support

For issues or questions:
- GitHub Issues: https://github.com/madhavkobal/Prompt-Forge/issues
- Documentation: docs/high-availability.md

---

**Important Notes:**
- Always test failover in staging before production
- Monitor replication lag regularly
- Keep backups of all data
- Document any custom configurations
- Test disaster recovery procedures quarterly
