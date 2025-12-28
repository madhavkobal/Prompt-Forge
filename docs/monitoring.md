# PromptForge Monitoring Guide

Complete guide for monitoring PromptForge in production on-premises deployments.

## Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Quick Start](#quick-start)
4. [Logging Stack](#logging-stack)
5. [Metrics & Monitoring](#metrics--monitoring)
6. [Dashboards](#dashboards)
7. [Alerting](#alerting)
8. [Troubleshooting](#troubleshooting)

---

## Overview

PromptForge monitoring stack provides comprehensive observability for production deployments with:

- **Centralized Logging**: Loki + Promtail for log aggregation
- **Metrics Collection**: Prometheus with multiple exporters
- **Visualization**: Grafana dashboards
- **Alerting**: AlertManager with multiple notification channels
- **Health Monitoring**: Service health checks and uptime monitoring

### Monitoring Components

```
┌────────────────────────────────────────────────────────────┐
│                       Grafana                              │
│              (Visualization & Dashboards)                  │
└─────────────┬──────────────────────┬───────────────────────┘
              │                      │
      ┌───────▼────────┐    ┌────────▼─────────┐
      │  Prometheus    │    │      Loki        │
      │   (Metrics)    │    │     (Logs)       │
      └───────┬────────┘    └────────┬─────────┘
              │                      │
    ┌─────────┴──────────┐          │
    │                    │          │
┌───▼──────┐      ┌──────▼────┐  ┌─▼────────┐
│Exporters │      │AlertManager│  │ Promtail │
│(various) │      │(Alerting)  │  │(Shipper) │
└──────────┘      └───────────┘  └──────────┘
```

### Resource Requirements

| Component | CPU | RAM | Disk |
|-----------|-----|-----|------|
| Grafana | 1 core | 512MB | 10GB |
| Prometheus | 2 cores | 2GB | 50GB |
| Loki | 1 core | 1GB | 50GB |
| Promtail | 0.5 cores | 256MB | 1GB |
| AlertManager | 0.5 cores | 256MB | 5GB |
| Exporters (total) | 2.5 cores | 1.5GB | 1GB |
| **Total** | **~8 cores** | **~5.5GB** | **~117GB** |

---

## Architecture

### Data Flow

```
Application Containers
         │
         ├──> Docker Logs ──> Promtail ──> Loki ──> Grafana
         │
         └──> Metrics ──> Prometheus ──> Grafana
                             │
                             └──> AlertManager ──> Email/Slack
```

### Components Detail

**1. Logging (Loki + Promtail)**
- **Loki**: Log aggregation database
- **Promtail**: Log collection agent
- **Storage**: 30-day retention
- **Features**: Label-based querying, regex filters

**2. Metrics (Prometheus)**
- **Scrape Interval**: 15 seconds
- **Retention**: 30 days
- **Storage**: Time-series database

**3. Exporters**
- **Node Exporter**: System metrics (CPU, RAM, Disk)
- **cAdvisor**: Container metrics
- **PostgreSQL Exporter**: Database metrics
- **Redis Exporter**: Cache metrics
- **Nginx Exporter**: Web server metrics
- **Blackbox Exporter**: Endpoint probing

**4. Visualization (Grafana)**
- **Port**: 3000
- **Default Auth**: admin/admin
- **Dashboards**: Auto-provisioned

**5. Alerting (AlertManager)**
- **Port**: 9093
- **Channels**: Email, Slack, PagerDuty, Webhooks
- **Grouping**: By alert name, severity, component

---

## Quick Start

### 1. Setup Monitoring Stack

```bash
# Configure environment
cp .env.monitoring.example .env.monitoring
nano .env.monitoring  # Configure email settings

# Start monitoring stack
./monitoring-setup.sh --start

# Check status
./monitoring-setup.sh --status
```

### 2. Access Dashboards

```bash
# Grafana (default: admin/admin)
http://localhost:3000

# Prometheus
http://localhost:9090

# AlertManager
http://localhost:9093

# cAdvisor
http://localhost:8080
```

### 3. Configure Alerts

Edit alerting configuration:
```bash
# Edit alert rules
nano monitoring/prometheus/alerts.yml

# Edit AlertManager config
nano monitoring/alertmanager/alertmanager.yml

# Reload Prometheus
curl -X POST http://localhost:9090/-/reload

# Reload AlertManager
curl -X POST http://localhost:9093/-/reload
```

---

## Logging Stack

### Loki Configuration

File: `monitoring/loki/loki-config.yml`

**Key Settings:**
```yaml
# Log retention
limits_config:
  retention_period: 720h  # 30 days

# Storage
storage_config:
  filesystem:
    directory: /loki/chunks

# Ingestion limits
limits_config:
  ingestion_rate_mb: 10
  ingestion_burst_size_mb: 20
```

### Promtail Configuration

File: `monitoring/loki/promtail-config.yml`

**Scrape Configs:**
1. **Docker Containers**: `/var/lib/docker/containers/*/*.log`
2. **Application Logs**: `/logs/**/*.log`
3. **Nginx Access**: `/logs/nginx/*-access.log`
4. **Nginx Error**: `/logs/nginx/*-error.log`
5. **System Logs**: `/var/log/syslog`

### Viewing Logs in Grafana

1. Open Grafana: http://localhost:3000
2. Navigate to **Explore**
3. Select **Loki** datasource
4. Query examples:

```logql
# All logs from backend containers
{job="docker", name=~"backend.*"}

# Error logs from all services
{job="docker"} |= "ERROR"

# Nginx access logs with 5xx errors
{job="nginx", type="access"} | json | status >= 500

# Last 1 hour of application logs
{job="application"} [1h]

# Count errors per minute
sum(rate({job="docker"} |= "ERROR" [1m])) by (name)
```

### Log Labels

Promtail automatically adds labels:
- `job`: Source job (docker, application, nginx, etc.)
- `instance`: Instance identifier
- `name`: Container name
- `level`: Log level (ERROR, INFO, WARNING)
- `stream`: stdout/stderr

### Log Retention Policy

**Current Settings:**
- Retention: 30 days
- Max size: 100GB (configurable)
- Compression: Enabled

**Adjust Retention:**
```yaml
# monitoring/loki/loki-config.yml
limits_config:
  retention_period: 2160h  # 90 days
```

---

## Metrics & Monitoring

### Prometheus Configuration

File: `monitoring/prometheus/prometheus.yml`

**Scrape Targets:**

| Job | Port | Metrics |
|-----|------|---------|
| prometheus | 9090 | Prometheus itself |
| node | 9100 | System (CPU, RAM, Disk) |
| cadvisor | 8080 | Container metrics |
| postgres | 9187 | PostgreSQL metrics |
| redis | 9121 | Redis metrics |
| nginx | 9113 | Nginx metrics |
| blackbox-http | 9115 | HTTP endpoint checks |
| blackbox-tcp | 9115 | TCP connection checks |

### Key Metrics

**System Metrics (Node Exporter)**
```promql
# CPU usage
100 - (avg by(instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)

# Memory usage
(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100

# Disk usage
(1 - (node_filesystem_avail_bytes / node_filesystem_size_bytes)) * 100

# Disk I/O
rate(node_disk_io_time_seconds_total[5m])

# Network traffic
rate(node_network_receive_bytes_total[5m])
rate(node_network_transmit_bytes_total[5m])
```

**Container Metrics (cAdvisor)**
```promql
# Container CPU
rate(container_cpu_usage_seconds_total{name!=""}[5m]) * 100

# Container memory
container_memory_usage_bytes / container_spec_memory_limit_bytes * 100

# Container network
rate(container_network_receive_bytes_total[5m])
```

**Database Metrics (PostgreSQL)**
```promql
# Connections
pg_stat_activity_count

# Replication lag
pg_replication_lag

# Transaction rate
rate(pg_stat_database_xact_commit[5m])

# Cache hit ratio
pg_stat_database_blks_hit / (pg_stat_database_blks_hit + pg_stat_database_blks_read)
```

**Redis Metrics**
```promql
# Memory usage
redis_memory_used_bytes / redis_memory_max_bytes * 100

# Connected clients
redis_connected_clients

# Commands per second
rate(redis_commands_processed_total[5m])

# Cache hit ratio
rate(redis_keyspace_hits_total[5m]) /
(rate(redis_keyspace_hits_total[5m]) + rate(redis_keyspace_misses_total[5m]))
```

**HTTP Endpoint Metrics (Blackbox)**
```promql
# Endpoint up/down
probe_success

# Response time
probe_http_duration_seconds

# HTTP status code
probe_http_status_code

# SSL certificate expiry
probe_ssl_earliest_cert_expiry
```

### Querying Prometheus

**Prometheus UI**: http://localhost:9090

**Query Examples:**
```promql
# Average CPU over last 5 minutes
avg(rate(node_cpu_seconds_total{mode!="idle"}[5m]))

# Total memory used
sum(node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes)

# HTTP request rate
sum(rate(http_requests_total[5m])) by (status)

# 95th percentile latency
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))
```

---

## Dashboards

### Pre-configured Dashboards

**PromptForge Overview** (`promptforge-overview`)
- System resources (CPU, RAM, Disk)
- Service status
- Container health
- Quick metrics at-a-glance

### Creating Custom Dashboards

1. Open Grafana: http://localhost:3000
2. Navigate to **Dashboards** → **New Dashboard**
3. Add panels with queries
4. Save dashboard

**Example Panel - CPU Usage:**
```json
{
  "datasource": "Prometheus",
  "targets": [
    {
      "expr": "100 - (avg(irate(node_cpu_seconds_total{mode=\"idle\"}[5m])) * 100)",
      "legendFormat": "CPU Usage"
    }
  ],
  "title": "CPU Usage"
}
```

### Importing Community Dashboards

1. Go to **Dashboards** → **Import**
2. Enter dashboard ID from https://grafana.com/dashboards

**Recommended Dashboards:**
- **Node Exporter Full**: 1860
- **Docker Monitoring**: 893
- **PostgreSQL**: 9628
- **Redis**: 11835
- **Nginx**: 12708

### Dashboard Variables

Create dynamic dashboards with variables:

```
# Instance selector
Name: instance
Type: Query
Query: label_values(up, instance)

# Time range
Name: interval
Type: Interval
Values: 1m,5m,10m,30m,1h
```

Use in queries:
```promql
up{instance="$instance"}
rate(http_requests_total[$interval])
```

---

## Alerting

### Alert Rules

File: `monitoring/prometheus/alerts.yml`

**Alert Categories:**
1. **System Alerts**: CPU, memory, disk
2. **Container Alerts**: Container health
3. **Database Alerts**: PostgreSQL health
4. **Redis Alerts**: Cache health
5. **HTTP Alerts**: Endpoint availability
6. **Application Alerts**: Error rates, latency
7. **Monitoring Alerts**: Stack health

**Example Alert:**
```yaml
- alert: HighCPUUsage
  expr: 100 - (avg(irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 80
  for: 5m
  labels:
    severity: warning
    component: system
  annotations:
    summary: "High CPU usage"
    description: "CPU usage is {{ $value }}%"
```

### Alert Severity Levels

| Severity | Description | Response Time |
|----------|-------------|---------------|
| **critical** | Service down, data loss | Immediate |
| **warning** | Degraded performance | 1-2 hours |
| **info** | Informational | Next business day |

### AlertManager Configuration

File: `monitoring/alertmanager/alertmanager.yml`

**Notification Channels:**

**1. Email**
```yaml
email_configs:
  - to: 'admin@promptforge.io'
    headers:
      Subject: '[CRITICAL] {{ .GroupLabels.alertname }}'
```

**2. Slack**
```yaml
slack_configs:
  - channel: '#promptforge-alerts'
    title: 'CRITICAL: {{ .GroupLabels.alertname }}'
    text: '{{ .CommonAnnotations.description }}'
```

**3. PagerDuty**
```yaml
pagerduty_configs:
  - service_key: '${PAGERDUTY_SERVICE_KEY}'
    description: '{{ .CommonAnnotations.summary }}'
```

**4. Webhook**
```yaml
webhook_configs:
  - url: 'http://localhost:5001/webhook'
    send_resolved: true
```

### Alert Routing

**Route Configuration:**
```yaml
route:
  receiver: 'default'
  group_by: ['alertname', 'severity']
  group_wait: 10s
  group_interval: 10s
  repeat_interval: 12h

  routes:
    - match:
        severity: critical
      receiver: 'critical'
      repeat_interval: 5m
```

### Silencing Alerts

**Via UI**: http://localhost:9093

**Via CLI:**
```bash
# Create silence
curl -X POST http://localhost:9093/api/v1/silences \
  -H "Content-Type: application/json" \
  -d '{
    "matchers": [
      {"name": "alertname", "value": "HighCPUUsage"}
    ],
    "startsAt": "2024-01-01T00:00:00Z",
    "endsAt": "2024-01-01T01:00:00Z",
    "comment": "Planned maintenance"
  }'
```

### Testing Alerts

**Send Test Alert:**
```bash
./monitoring-setup.sh --test-alert
```

**Manual Test:**
```bash
curl -H "Content-Type: application/json" -d '[
  {
    "labels": {
      "alertname": "TestAlert",
      "severity": "warning"
    },
    "annotations": {
      "summary": "Test alert"
    }
  }
]' http://localhost:9093/api/v1/alerts
```

### Alert Best Practices

1. **Set Appropriate Thresholds**
   - Avoid alert fatigue
   - Base on historical data
   - Use percentiles for latency

2. **Use For Clauses**
   - Wait before alerting
   - Avoid flapping alerts
   - Typically 2-5 minutes

3. **Group Related Alerts**
   - By service/component
   - By severity
   - Reduce notification spam

4. **Provide Context**
   - Clear summary
   - Actionable description
   - Include current value

5. **Test Regularly**
   - Verify alert rules
   - Test notification channels
   - Practice runbooks

---

## Troubleshooting

### Common Issues

#### 1. Grafana Not Accessible

**Symptoms:**
- Cannot connect to http://localhost:3000
- Login page not loading

**Check:**
```bash
# Check if container is running
docker ps | grep grafana

# Check logs
docker logs promptforge-grafana

# Check service status
./monitoring-setup.sh --status
```

**Fix:**
```bash
# Restart Grafana
docker-compose -f docker-compose.monitoring.yml restart grafana

# Check for port conflicts
sudo lsof -i :3000
```

#### 2. Prometheus Not Scraping Targets

**Symptoms:**
- Targets show as "down" in Prometheus UI
- Missing metrics in Grafana

**Check:**
```bash
# View Prometheus targets
http://localhost:9090/targets

# Check network connectivity
docker exec promptforge-prometheus ping node_exporter
```

**Fix:**
```bash
# Verify exporter is running
docker ps | grep exporter

# Check Prometheus config
docker exec promptforge-prometheus cat /etc/prometheus/prometheus.yml

# Reload Prometheus
curl -X POST http://localhost:9090/-/reload
```

#### 3. Loki Not Receiving Logs

**Symptoms:**
- No logs in Grafana Explore
- Empty log queries

**Check:**
```bash
# Check Loki status
curl http://localhost:3100/ready

# Check Promtail logs
docker logs promptforge-promtail

# Verify log files exist
ls -la logs/
```

**Fix:**
```bash
# Restart Promtail
docker-compose -f docker-compose.monitoring.yml restart promtail

# Check Promtail config
docker exec promptforge-promtail cat /etc/promtail/config.yml

# Verify log file permissions
sudo chmod -R 755 logs/
```

#### 4. Alerts Not Firing

**Symptoms:**
- No alerts in AlertManager
- Expected alerts not triggering

**Check:**
```bash
# View active alerts in Prometheus
http://localhost:9090/alerts

# Check AlertManager
http://localhost:9093

# View alert rules
http://localhost:9090/rules
```

**Fix:**
```bash
# Validate alert rules
docker exec promptforge-prometheus promtool check rules /etc/prometheus/alerts.yml

# Check alert evaluation
# Look for "error" in Prometheus alerts page

# Restart AlertManager
docker-compose -f docker-compose.monitoring.yml restart alertmanager
```

#### 5. High Resource Usage

**Symptoms:**
- Slow dashboard loading
- High CPU/memory usage

**Check:**
```bash
# Check resource usage
docker stats

# Check disk space
df -h
```

**Fix:**
```bash
# Reduce retention period
# Edit monitoring/prometheus/prometheus.yml
# Change --storage.tsdb.retention.time=30d to 15d

# Reduce scrape frequency
# Edit monitoring/prometheus/prometheus.yml
# Change scrape_interval: 15s to 30s

# Clean old data
docker exec promptforge-prometheus rm -rf /prometheus/wal/*
```

### Debugging Commands

```bash
# View all monitoring containers
docker-compose -f docker-compose.monitoring.yml ps

# View logs for specific service
docker-compose -f docker-compose.monitoring.yml logs -f grafana

# Enter container shell
docker exec -it promptforge-prometheus sh

# Check Prometheus config
curl http://localhost:9090/api/v1/status/config

# Check AlertManager config
curl http://localhost:9093/api/v1/status

# Test metric query
curl 'http://localhost:9090/api/v1/query?query=up'
```

### Performance Tuning

**Prometheus:**
```yaml
# Reduce cardinality
global:
  scrape_interval: 30s  # Increase from 15s

# Lower retention
--storage.tsdb.retention.time=15d  # Reduce from 30d
```

**Loki:**
```yaml
# Reduce ingestion rate
limits_config:
  ingestion_rate_mb: 5
  ingestion_burst_size_mb: 10
```

**Grafana:**
```yaml
# Reduce query timeout
jsonData:
  queryTimeout: "30s"
```

---

## Quick Reference

### Start/Stop Commands

```bash
# Start monitoring stack
./monitoring-setup.sh --start

# Stop monitoring stack
./monitoring-setup.sh --stop

# Restart monitoring
./monitoring-setup.sh --restart

# Check status
./monitoring-setup.sh --status

# View logs
./monitoring-setup.sh --logs
./monitoring-setup.sh --logs grafana
```

### Access URLs

```
Grafana:      http://localhost:3000 (admin/admin)
Prometheus:   http://localhost:9090
AlertManager: http://localhost:9093
Loki:         http://localhost:3100
cAdvisor:     http://localhost:8080
Node Exporter: http://localhost:9100
```

### Important Files

```
docker-compose.monitoring.yml          # Main compose file
monitoring/prometheus/prometheus.yml   # Prometheus config
monitoring/prometheus/alerts.yml       # Alert rules
monitoring/alertmanager/alertmanager.yml # AlertManager config
monitoring/loki/loki-config.yml       # Loki config
monitoring/loki/promtail-config.yml   # Promtail config
monitoring/grafana/provisioning/      # Grafana auto-config
.env.monitoring                        # Environment variables
```

### Useful PromQL Queries

```promql
# CPU usage
100 - (avg(irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)

# Memory usage
(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100

# Disk usage
(1 - (node_filesystem_avail_bytes / node_filesystem_size_bytes)) * 100

# Request rate
sum(rate(http_requests_total[5m]))

# Error rate
sum(rate(http_requests_total{status=~"5.."}[5m]))

# P95 latency
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))
```

---

## Support

For additional help:

- **Grafana Docs**: https://grafana.com/docs/
- **Prometheus Docs**: https://prometheus.io/docs/
- **Loki Docs**: https://grafana.com/docs/loki/
- **PromptForge Issues**: https://github.com/madhavkobal/Prompt-Forge/issues

---

*Last Updated: 2025-01-15*
