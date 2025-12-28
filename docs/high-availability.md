# PromptForge High Availability Guide

Complete guide for deploying PromptForge in a high availability configuration for production on-premises environments.

## Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Load Balancing](#load-balancing)
4. [Database Replication](#database-replication)
5. [Redis High Availability](#redis-high-availability)
6. [Container Orchestration](#container-orchestration)
7. [Deployment](#deployment)
8. [Monitoring and Health Checks](#monitoring-and-health-checks)
9. [Failover Testing](#failover-testing)
10. [Scaling](#scaling)
11. [Troubleshooting](#troubleshooting)

---

## Overview

PromptForge High Availability (HA) provides:

- **Zero downtime deployments** with rolling updates
- **Automatic failover** for Redis and backend services
- **Load distribution** across multiple backend instances
- **Database replication** for read scaling and backup
- **Health monitoring** with automatic recovery
- **Horizontal scaling** for increased capacity

### HA Components

```
┌─────────────────────────────────────────────────────────────┐
│                     Nginx Load Balancer                      │
│                    (Round-robin / Least-conn)                │
└────────────┬────────────────────────┬────────────────────────┘
             │                        │
    ┌────────▼────────┐      ┌────────▼────────┐
    │   Frontend 1    │      │   Frontend 2    │
    │   (React/Nginx) │      │   (React/Nginx) │
    └─────────────────┘      └─────────────────┘
             │                        │
    ┌────────▼────────┬───────────────▼──────┬──────────────┐
    │   Backend 1     │    Backend 2         │  Backend 3   │
    │ (FastAPI+Gunic) │  (FastAPI+Gunic)     │(FastAPI+Gun) │
    └────────┬────────┴──────────┬───────────┴──────┬───────┘
             │                   │                   │
     ┌───────▼───────────────────▼───────────────────▼──────┐
     │         PostgreSQL Primary (Read/Write)              │
     │              +                                        │
     │         PostgreSQL Replica (Read-only)               │
     └──────────────────────────────────────────────────────┘
     ┌──────────────────────────────────────────────────────┐
     │  Redis Master + Replica + 3 Sentinels                │
     │  (Automatic failover with quorum)                    │
     └──────────────────────────────────────────────────────┘
```

### Deployment Options

1. **Docker Compose HA** (Recommended for single-host)
   - Simpler setup
   - Good for small to medium deployments
   - Manual scaling

2. **Docker Swarm** (Recommended for multi-host)
   - Container orchestration
   - Automatic service discovery
   - Rolling updates
   - Multi-host support

---

## Architecture

### High Availability Characteristics

| Component | HA Feature | Failover Time | Notes |
|-----------|-----------|---------------|-------|
| **Nginx** | 2 instances | Instant (DNS/LB) | External load balancer needed for full HA |
| **Backend** | 3+ instances | <1s (proxy_next_upstream) | Stateless, automatic failover |
| **Frontend** | 2 instances | <1s | Static files, automatic failover |
| **PostgreSQL** | Primary + Replica | Manual/Semi-auto | Streaming replication |
| **Redis** | Master + Replica + Sentinel | 5-10s | Automatic with quorum |

### Resource Requirements

**Minimum for HA (Single Host):**
- CPU: 8 cores
- RAM: 16 GB
- Disk: 100 GB SSD
- Network: 1 Gbps

**Recommended for Production:**
- CPU: 16 cores
- RAM: 32 GB
- Disk: 500 GB SSD (with RAID)
- Network: 10 Gbps

**Per Service:**
| Service | CPU | RAM | Replicas |
|---------|-----|-----|----------|
| Backend | 1.5 cores | 1.5 GB | 3 |
| Frontend | 0.5 cores | 512 MB | 2 |
| PostgreSQL | 2 cores | 2 GB | 2 (primary + replica) |
| Redis | 1 core | 512 MB | 2 (master + replica) |
| Redis Sentinel | 0.5 cores | 256 MB | 3 |
| Nginx | 1 core | 512 MB | 2 |

---

## Load Balancing

### Nginx Configuration

The load balancer distributes traffic across multiple backend instances.

**Load Balancing Methods:**

1. **Least Connections** (Default)
   ```nginx
   upstream backend_api {
       least_conn;  # Route to server with least connections
       server backend1:8000;
       server backend2:8000;
       server backend3:8000;
   }
   ```

2. **Round Robin**
   ```nginx
   upstream backend_api {
       # Default - no directive needed
       server backend1:8000;
       server backend2:8000;
       server backend3:8000;
   }
   ```

3. **IP Hash** (Session persistence)
   ```nginx
   upstream backend_api {
       ip_hash;  # Same client always goes to same server
       server backend1:8000;
       server backend2:8000;
       server backend3:8000;
   }
   ```

### Health Checks

**Passive Health Checks** (Open-source Nginx):
```nginx
server backend1:8000 max_fails=3 fail_timeout=30s;
```

- Marks server as down after 3 failed requests
- Keeps it down for 30 seconds
- Then tries again

**Active Health Checks** (Nginx Plus):
```nginx
location /api {
    proxy_pass http://backend_api;
    health_check interval=10s fails=3 passes=2;
}
```

### Automatic Failover

```nginx
location /api {
    proxy_pass http://backend_api;

    # Try next server on failure
    proxy_next_upstream error timeout http_502 http_503 http_504;
    proxy_next_upstream_tries 3;
    proxy_next_upstream_timeout 15s;
}
```

**Failover Behavior:**
1. Request sent to backend1
2. If backend1 fails (502/503/504), retry on backend2
3. If backend2 fails, retry on backend3
4. If all fail, return error to client

### Monitoring

Check load balancer status:
```bash
# Nginx stub status (port 8080, internal only)
curl http://localhost:8080/nginx_status

# Output:
Active connections: 15
server accepts handled requests
 1000 1000 5000
Reading: 0 Writing: 3 Waiting: 12
```

View upstream servers:
```bash
# Check backend logs
docker logs promptforge-nginx-lb

# Look for upstream selection
grep "upstream" logs/nginx/lb-access.log
```

---

## Database Replication

### PostgreSQL Streaming Replication

PromptForge uses PostgreSQL streaming replication for:
- **Read scaling**: Distribute SELECT queries across replicas
- **Backup**: Take backups from replica without impacting primary
- **Failover preparation**: Replica ready to become primary

### Architecture

```
┌────────────────────────────────────┐
│     PostgreSQL Primary             │
│  - All writes (INSERT/UPDATE/DEL)  │
│  - Synchronous writes to WAL       │
└───────────┬────────────────────────┘
            │
            │ WAL streaming
            │ (continuous replication)
            ▼
┌────────────────────────────────────┐
│     PostgreSQL Replica             │
│  - Read-only queries (SELECT)      │
│  - Hot standby mode                │
│  - Real-time replication           │
└────────────────────────────────────┘
```

### Setup Replication

**1. Primary Configuration**

File: `ha/postgresql/primary/postgresql.conf`
```ini
wal_level = replica
max_wal_senders = 5
max_replication_slots = 5
hot_standby = on
```

File: `ha/postgresql/primary/pg_hba.conf`
```
host replication replicator 172.26.0.0/16 scram-sha-256
```

**2. Create Replication User**

The init script creates:
```sql
CREATE USER replicator WITH REPLICATION PASSWORD 'secure_password';
SELECT pg_create_physical_replication_slot('replica_slot');
```

**3. Setup Replica**

The replica automatically:
1. Connects to primary
2. Creates base backup
3. Starts streaming replication
4. Stays in hot standby mode

**4. Verify Replication**

```bash
# On primary - check replication status
docker exec promptforge-postgres-primary psql -U promptforge -d promptforge_prod -c "
SELECT
    client_addr,
    state,
    sync_state,
    replay_lag
FROM pg_stat_replication;"

# On replica - check if in recovery mode
docker exec promptforge-postgres-replica psql -U promptforge -d promptforge_prod -c "
SELECT pg_is_in_recovery();"  # Should return 't' (true)

# Check replication lag
docker exec promptforge-postgres-primary psql -U promptforge -d promptforge_prod -c "
SELECT
    client_addr,
    pg_wal_lsn_diff(pg_current_wal_lsn(), replay_lsn) AS lag_bytes,
    write_lag,
    flush_lag,
    replay_lag
FROM pg_stat_replication;"
```

### Read Scaling

Configure application to use replica for read-only queries:

```python
# In application code
DATABASE_PRIMARY = "postgresql://user:pass@postgres-primary:5432/db"
DATABASE_REPLICA = "postgresql://user:pass@postgres-replica:5432/db"

# Use replica for read operations
def get_users():
    engine = create_engine(DATABASE_REPLICA)
    # SELECT queries

# Use primary for writes
def create_user(data):
    engine = create_engine(DATABASE_PRIMARY)
    # INSERT/UPDATE/DELETE queries
```

### Manual Failover

If primary fails, promote replica to primary:

```bash
# 1. Promote replica to primary
docker exec promptforge-postgres-replica pg_ctl promote

# 2. Verify promotion
docker exec promptforge-postgres-replica psql -U promptforge -d promptforge_prod -c "
SELECT pg_is_in_recovery();"  # Should return 'f' (false)

# 3. Update application DATABASE_URL to point to new primary
# Edit .env.production
DATABASE_URL=postgresql://user:pass@postgres-replica:5432/db

# 4. Restart backend services
docker-compose -f docker-compose.ha.yml restart backend1 backend2 backend3
```

### Automatic Failover (Optional)

For automatic failover, use one of these tools:

**Option 1: pg_auto_failover**
```bash
# Install pg_auto_failover
# https://pg-auto-failover.readthedocs.io/
```

**Option 2: Patroni**
```bash
# Patroni with etcd/Consul
# https://patroni.readthedocs.io/
```

**Option 3: Replication Manager**
```bash
# repmgr for PostgreSQL replication management
# https://repmgr.org/
```

### Backup from Replica

Take backups from replica to avoid impacting primary:

```bash
# Backup from replica instead of primary
DATABASE_URL=postgresql://user:pass@postgres-replica:5432/db \
./database/scripts/backup-database.sh --verify
```

---

## Redis High Availability

### Redis Sentinel Architecture

Redis Sentinel provides automatic failover for Redis:

```
┌──────────────────────────┐
│    Redis Master          │
│  (reads + writes)        │
└───────┬──────────────────┘
        │ Replication
        ▼
┌──────────────────────────┐
│    Redis Replica         │
│  (reads only)            │
└──────────────────────────┘

┌────────────┐  ┌────────────┐  ┌────────────┐
│ Sentinel 1 │  │ Sentinel 2 │  │ Sentinel 3 │
│ (monitor)  │  │ (monitor)  │  │ (monitor)  │
└────────────┘  └────────────┘  └────────────┘
      Quorum: 2 sentinels must agree for failover
```

### Sentinel Configuration

File: `ha/redis/sentinel.conf`
```conf
sentinel monitor mymaster redis-master 6379 2
sentinel down-after-milliseconds mymaster 5000
sentinel parallel-syncs mymaster 1
sentinel failover-timeout mymaster 10000
```

**Parameters:**
- **Quorum (2)**: 2 sentinels must agree master is down
- **down-after-milliseconds (5000)**: Consider master down after 5s
- **parallel-syncs (1)**: Only 1 replica syncs at a time during failover
- **failover-timeout (10000)**: Failover must complete within 10s

### Failover Process

1. **Detection**: Sentinels detect master is down (quorum agrees)
2. **Election**: Sentinels elect a leader
3. **Promotion**: Leader promotes replica to master
4. **Reconfiguration**: Other replicas point to new master
5. **Notification**: Clients discover new master

### Testing Failover

```bash
# 1. Check current master
docker exec promptforge-redis-sentinel-1 redis-cli -p 26379 \
    SENTINEL get-master-addr-by-name mymaster

# Output: 172.26.0.20 (redis-master)

# 2. Stop current master
docker stop promptforge-redis-master

# 3. Watch sentinel logs
docker logs -f promptforge-redis-sentinel-1

# You'll see:
# +sdown master mymaster 172.26.0.20 6379
# +odown master mymaster 172.26.0.20 6379
# +failover-triggered master mymaster 172.26.0.20 6379
# +promoted-slave slave 172.26.0.21:6379 (replica)
# +failover-end master mymaster 172.26.0.20 6379

# 4. Verify new master
docker exec promptforge-redis-sentinel-1 redis-cli -p 26379 \
    SENTINEL get-master-addr-by-name mymaster

# Output: 172.26.0.21 (redis-replica is now master)

# 5. Restart old master (becomes replica)
docker start promptforge-redis-master
```

### Client Configuration

Configure application to use Sentinel for master discovery:

```python
from redis.sentinel import Sentinel

# Sentinel addresses
sentinels = [
    ('redis-sentinel-1', 26379),
    ('redis-sentinel-2', 26379),
    ('redis-sentinel-3', 26379)
]

# Create Sentinel instance
sentinel = Sentinel(sentinels, socket_timeout=0.1)

# Get current master (automatic failover handling)
master = sentinel.master_for('mymaster', socket_timeout=0.1, password='password')

# Get replica for read operations
replica = sentinel.slave_for('mymaster', socket_timeout=0.1, password='password')

# Use master for writes
master.set('key', 'value')

# Use replica for reads
value = replica.get('key')
```

### Monitoring Sentinel

```bash
# Sentinel info
docker exec promptforge-redis-sentinel-1 redis-cli -p 26379 INFO sentinel

# Master info
docker exec promptforge-redis-sentinel-1 redis-cli -p 26379 \
    SENTINEL master mymaster

# Replica info
docker exec promptforge-redis-sentinel-1 redis-cli -p 26379 \
    SENTINEL replicas mymaster

# Sentinel status
docker exec promptforge-redis-sentinel-1 redis-cli -p 26379 \
    SENTINEL sentinels mymaster
```

---

## Container Orchestration

### Docker Swarm

Docker Swarm provides:
- **Service scaling**: Easy horizontal scaling
- **Rolling updates**: Zero-downtime deployments
- **Load balancing**: Built-in routing mesh
- **Health checks**: Automatic container restart
- **Multi-host**: Deploy across multiple servers

### Swarm Architecture

```
┌─────────────────────────────────────────────────────┐
│                  Swarm Manager Node                  │
│  - Orchestration                                     │
│  - Scheduling                                        │
│  - Service management                                │
└────────────────────┬────────────────────────────────┘
                     │
        ┌────────────┴────────────┐
        │                         │
┌───────▼──────────┐    ┌─────────▼────────┐
│  Worker Node 1    │    │  Worker Node 2    │
│  - Run tasks      │    │  - Run tasks      │
│  - Report status  │    │  - Report status  │
└───────────────────┘    └───────────────────┘
```

### Setup Swarm

```bash
# Initialize swarm
./ha/swarm/setup-swarm.sh --init

# Deploy stack
./ha/swarm/setup-swarm.sh --deploy

# Check status
./ha/swarm/setup-swarm.sh --status
```

### Scaling Services

```bash
# Scale backend to 5 instances
docker service scale promptforge_backend=5

# Scale frontend to 3 instances
docker service scale promptforge_frontend=3

# View current scale
docker service ls
```

### Rolling Updates

```bash
# Update backend image
docker service update \
    --image localhost:5000/promptforge-backend:v2 \
    promptforge_backend

# Swarm will:
# 1. Update 1 task at a time (parallelism=1)
# 2. Wait 10s between updates
# 3. Monitor for failures
# 4. Rollback if update fails
```

### Rollback

```bash
# Rollback to previous version
docker service rollback promptforge_backend

# Check rollback status
docker service ps promptforge_backend
```

### Multi-Host Deployment

**On Manager Node:**
```bash
# Initialize swarm
docker swarm init --advertise-addr <MANAGER-IP>

# Get join token
docker swarm join-token worker
```

**On Worker Nodes:**
```bash
# Join swarm
docker swarm join --token <TOKEN> <MANAGER-IP>:2377
```

**Deploy Stack:**
```bash
# On manager node
docker stack deploy -c ha/swarm/docker-stack.yml promptforge
```

---

## Deployment

### Quick Start

**Option 1: Docker Compose HA (Single Host)**

```bash
# 1. Configure environment
cp .env.production.example .env.production
nano .env.production

# 2. Setup SSL
./ssl-setup.sh self-signed  # Or use Let's Encrypt

# 3. Deploy HA stack
./ha-setup.sh --compose

# 4. Verify health
./ha-setup.sh --check
```

**Option 2: Docker Swarm (Multi-Host)**

```bash
# 1. Configure environment
cp .env.production.example .env.production
nano .env.production

# 2. Setup SSL
./ssl-setup.sh self-signed

# 3. Initialize swarm
./ha/swarm/setup-swarm.sh --init

# 4. Deploy stack
./ha/swarm/setup-swarm.sh --deploy

# 5. Check status
./ha/swarm/setup-swarm.sh --status
```

### Environment Variables

Required in `.env.production`:

```bash
# Database
POSTGRES_USER=promptforge
POSTGRES_PASSWORD=<strong-password>
POSTGRES_DB=promptforge_prod
POSTGRES_REPLICATION_USER=replicator
POSTGRES_REPLICATION_PASSWORD=<replication-password>

# Redis
REDIS_PASSWORD=<redis-password>

# Application
SECRET_KEY=<secret-key>
GEMINI_API_KEY=<your-api-key>
VITE_API_URL=https://yourdomain.com

# Backend
BACKEND_WORKERS=2  # Per instance

# Docker Registry (for Swarm)
DOCKER_REGISTRY=localhost:5000
```

### Initial Deployment

```bash
# 1. Check prerequisites
./ha-setup.sh

# 2. Initialize database
cd database/scripts
./setup-database.sh
cd ../..

# 3. Run migrations
cd backend
./migrate.sh upgrade
cd ..

# 4. Deploy HA stack
./ha-setup.sh --compose  # or --swarm

# 5. Verify deployment
./ha-setup.sh --check

# 6. Monitor logs
docker-compose -f docker-compose.ha.yml logs -f
```

---

## Monitoring and Health Checks

### Service Health Endpoints

| Service | Endpoint | Expected Response |
|---------|----------|-------------------|
| Nginx | http://localhost:8080/health | "healthy" |
| Backend | http://localhost/api/health | {"status": "healthy"} |
| PostgreSQL | pg_isready | "accepting connections" |
| Redis | redis-cli ping | "PONG" |

### Health Check Script

```bash
# Run comprehensive health checks
./ha-setup.sh --check

# Output:
# ✓ Nginx load balancer is healthy
# ✓ Backend API is healthy
# ✓ PostgreSQL primary is healthy
# ✓ Redis master is healthy
# ✓ Redis Sentinel is healthy
```

### Monitoring Commands

```bash
# Docker Compose
docker-compose -f docker-compose.ha.yml ps
docker-compose -f docker-compose.ha.yml logs -f <service>

# Docker Swarm
docker service ls
docker service ps promptforge_backend
docker service logs -f promptforge_backend

# Nginx status
curl http://localhost:8080/nginx_status

# PostgreSQL replication
docker exec promptforge-postgres-primary psql -U promptforge -c "
SELECT * FROM pg_stat_replication;"

# Redis Sentinel
docker exec promptforge-redis-sentinel-1 redis-cli -p 26379 \
    SENTINEL master mymaster
```

### Prometheus + Grafana (Optional)

For advanced monitoring:

```yaml
# Add to docker-compose.ha.yml
prometheus:
  image: prom/prometheus
  volumes:
    - ./monitoring/prometheus.yml:/etc/prometheus/prometheus.yml
  ports:
    - "9090:9090"

grafana:
  image: grafana/grafana
  ports:
    - "3000:3000"
  environment:
    - GF_SECURITY_ADMIN_PASSWORD=admin
```

---

## Failover Testing

### Backend Failover

```bash
# 1. Check current backend instances
docker-compose -f docker-compose.ha.yml ps backend1 backend2 backend3

# 2. Stop one backend
docker stop promptforge-backend-1

# 3. Test API (should still work)
curl http://localhost/api/health

# 4. Check nginx logs (should route to backend2/backend3)
docker logs promptforge-nginx-lb | tail -20

# 5. Restart backend
docker start promptforge-backend-1
```

### Redis Failover

```bash
# 1. Check current Redis master
docker exec promptforge-redis-sentinel-1 redis-cli -p 26379 \
    SENTINEL get-master-addr-by-name mymaster

# 2. Stop Redis master
docker stop promptforge-redis-master

# 3. Wait for Sentinel failover (5-10 seconds)
sleep 10

# 4. Check new master
docker exec promptforge-redis-sentinel-1 redis-cli -p 26379 \
    SENTINEL get-master-addr-by-name mymaster

# 5. Verify application still works
curl http://localhost/api/health

# 6. Restart old master (becomes replica)
docker start promptforge-redis-master
```

### PostgreSQL Failover

```bash
# Simulate primary failure and manual promotion

# 1. Stop primary
docker stop promptforge-postgres-primary

# 2. Promote replica to primary
docker exec promptforge-postgres-replica pg_ctl promote

# 3. Verify promotion
docker exec promptforge-postgres-replica psql -U promptforge -c \
    "SELECT pg_is_in_recovery();"  # Should be false

# 4. Update application to use new primary
# Edit .env.production
# DATABASE_URL=postgresql://...@postgres-replica:5432/...

# 5. Restart backends
docker-compose -f docker-compose.ha.yml restart backend1 backend2 backend3
```

### Automated Failover Test

```bash
# Run automated failover test
./ha-setup.sh --test-failover

# This will:
# 1. Test backend failover
# 2. Test Redis Sentinel failover
# 3. Verify recovery
# 4. Restore original state
```

---

## Scaling

### Horizontal Scaling

**Add More Backend Instances:**

```bash
# Docker Compose: Edit docker-compose.ha.yml
# Add backend4, backend5, etc.

# Docker Swarm: Scale service
docker service scale promptforge_backend=5
```

**Update Nginx Configuration:**

```nginx
# Edit ha/nginx/load-balancer.conf
upstream backend_api {
    least_conn;
    server backend1:8000;
    server backend2:8000;
    server backend3:8000;
    server backend4:8000;  # New
    server backend5:8000;  # New
}
```

**Reload Nginx:**

```bash
docker-compose -f docker-compose.ha.yml restart nginx
# or
docker service update --force promptforge_nginx
```

### Vertical Scaling

Increase resources per container:

```yaml
# Edit docker-compose.ha.yml
backend1:
  deploy:
    resources:
      limits:
        cpus: '2.5'      # Increase from 1.5
        memory: 3G       # Increase from 1.5G
```

### Database Scaling

**Add More Read Replicas:**

```yaml
# Add postgres-replica-2 to docker-compose.ha.yml
postgres-replica-2:
  # Same config as postgres-replica
```

**Load Balance Reads:**

```nginx
upstream postgres_read {
    server postgres-replica:5432;
    server postgres-replica-2:5432;
}
```

---

## Troubleshooting

### Common Issues

#### 1. Backend Not Load Balancing

**Symptoms:**
- All requests go to one backend
- Some backends show 0 connections

**Check:**
```bash
# Check Nginx upstream status
docker logs promptforge-nginx-lb | grep upstream

# Check backend health
docker-compose -f docker-compose.ha.yml ps
```

**Fix:**
```bash
# Restart nginx
docker-compose -f docker-compose.ha.yml restart nginx

# Check nginx config
docker exec promptforge-nginx-lb nginx -t
```

#### 2. PostgreSQL Replication Lag

**Symptoms:**
- Replica data is outdated
- High replication lag

**Check:**
```bash
# Check replication lag
docker exec promptforge-postgres-primary psql -U promptforge -c "
SELECT
    client_addr,
    state,
    pg_wal_lsn_diff(pg_current_wal_lsn(), replay_lsn) AS lag_bytes,
    replay_lag
FROM pg_stat_replication;"
```

**Fix:**
```bash
# Check network connectivity
docker exec promptforge-postgres-replica ping postgres-primary

# Check primary load (may need to scale)
docker stats promptforge-postgres-primary

# Check WAL disk space
docker exec promptforge-postgres-primary df -h
```

#### 3. Redis Sentinel Not Failing Over

**Symptoms:**
- Master is down but no failover
- Sentinels not detecting failure

**Check:**
```bash
# Check sentinel status
docker exec promptforge-redis-sentinel-1 redis-cli -p 26379 \
    SENTINEL master mymaster

# Check quorum
docker logs promptforge-redis-sentinel-1 | grep quorum
```

**Fix:**
```bash
# Ensure at least 2 sentinels are running
docker-compose -f docker-compose.ha.yml ps | grep sentinel

# Check sentinel can reach master
docker exec promptforge-redis-sentinel-1 ping redis-master

# Manual failover if needed
docker exec promptforge-redis-sentinel-1 redis-cli -p 26379 \
    SENTINEL failover mymaster
```

#### 4. Docker Swarm Service Not Starting

**Symptoms:**
- Service shows 0/3 replicas running
- Tasks failing repeatedly

**Check:**
```bash
# Check service status
docker service ps promptforge_backend --no-trunc

# Check service logs
docker service logs promptforge_backend

# Check node resources
docker node ls
docker node inspect <node-id>
```

**Fix:**
```bash
# Update service constraints
docker service update --constraint-rm node.role==worker promptforge_backend

# Scale down then up
docker service scale promptforge_backend=0
docker service scale promptforge_backend=3

# Rollback if needed
docker service rollback promptforge_backend
```

---

## Best Practices

### 1. Resource Planning

- **CPU**: Reserve 20% overhead for spikes
- **Memory**: Set limits slightly higher than reservations
- **Disk**: Monitor usage, plan for 3x data growth
- **Network**: Ensure low latency between nodes (<1ms for DB)

### 2. Monitoring

- Set up alerts for:
  - Container health failures
  - High resource usage (>80%)
  - Replication lag (>5s)
  - Failed health checks

### 3. Backup Strategy

- **Daily automated backups** from replica
- **Test restores monthly**
- **Off-site backup copies**
- **WAL archiving** for point-in-time recovery

### 4. Security

- **Network isolation**: Use overlay networks
- **Secrets management**: Use Docker secrets or vault
- **SSL/TLS**: Encrypt all external traffic
- **Access control**: Restrict management ports

### 5. Updates

- **Test in staging** before production
- **Rolling updates** for zero downtime
- **Have rollback plan** ready
- **Monitor during updates**

---

## Quick Reference

### Deployment Commands

```bash
# Deploy with Docker Compose
./ha-setup.sh --compose

# Deploy with Docker Swarm
./ha/swarm/setup-swarm.sh --init
./ha/swarm/setup-swarm.sh --deploy

# Check health
./ha-setup.sh --check

# View status
./ha-setup.sh --status
```

### Scaling Commands

```bash
# Docker Compose: Edit docker-compose.ha.yml, then:
docker-compose -f docker-compose.ha.yml up -d --scale backend=5

# Docker Swarm:
docker service scale promptforge_backend=5
```

### Monitoring Commands

```bash
# Service status
docker-compose -f docker-compose.ha.yml ps
docker service ls

# Logs
docker-compose -f docker-compose.ha.yml logs -f <service>
docker service logs -f promptforge_backend

# Resource usage
docker stats
```

### Failover Commands

```bash
# PostgreSQL failover
docker exec promptforge-postgres-replica pg_ctl promote

# Redis Sentinel failover
docker exec promptforge-redis-sentinel-1 redis-cli -p 26379 \
    SENTINEL failover mymaster

# Check Redis master
docker exec promptforge-redis-sentinel-1 redis-cli -p 26379 \
    SENTINEL get-master-addr-by-name mymaster
```

---

## Support

For additional help:

- **Docker Documentation**: https://docs.docker.com/
- **PostgreSQL Replication**: https://www.postgresql.org/docs/current/high-availability.html
- **Redis Sentinel**: https://redis.io/topics/sentinel
- **Nginx Load Balancing**: https://nginx.org/en/docs/http/load_balancing.html
- **PromptForge Issues**: https://github.com/madhavkobal/Prompt-Forge/issues

---

*Last Updated: 2025-01-15*
