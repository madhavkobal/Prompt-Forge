# PromptForge Monitoring Configuration

This directory contains all configuration files for the monitoring stack.

## Quick Start

```bash
# Start monitoring stack
./monitoring-setup.sh --start

# Access Grafana
http://localhost:3000 (admin/admin)

# Check status
./monitoring-setup.sh --status
```

## Directory Structure

```
monitoring/
├── prometheus/              # Prometheus configuration
│   ├── prometheus.yml      # Main config with scrape targets
│   ├── alerts.yml          # Alert rules
│   └── blackbox.yml        # Blackbox exporter config
├── grafana/                 # Grafana configuration
│   ├── dashboards/         # Dashboard JSON files
│   │   └── promptforge-overview.json
│   └── provisioning/       # Auto-provisioning configs
│       ├── datasources/    # Datasource configs (Prometheus, Loki)
│       └── dashboards/     # Dashboard provisioning
├── loki/                    # Loki log aggregation
│   ├── loki-config.yml     # Loki configuration
│   └── promtail-config.yml # Log shipper configuration
├── alertmanager/            # AlertManager configuration
│   └── alertmanager.yml    # Alert routing and notifications
└── README.md                # This file
```

## Components

### Prometheus (Port 9090)

**Metrics Collection**
- Scrapes metrics every 15 seconds
- 30-day retention
- Time-series database

**Scrape Targets:**
- node_exporter: System metrics
- cadvisor: Container metrics
- postgres_exporter: Database metrics
- redis_exporter: Cache metrics
- nginx_exporter: Web server metrics
- blackbox_exporter: Endpoint probes

**Configuration:** `prometheus/prometheus.yml`

### Grafana (Port 3000)

**Visualization Platform**
- Default credentials: admin/admin
- Auto-provisioned datasources
- Pre-configured dashboards

**Datasources:**
- Prometheus (default)
- Loki (logs)
- AlertManager

**Configuration:** `grafana/provisioning/`

### Loki (Port 3100)

**Log Aggregation**
- Label-based log storage
- 30-day retention
- Efficient log queries

**Log Sources:**
- Docker containers
- Application logs
- Nginx logs
- System logs

**Configuration:** `loki/loki-config.yml`

### Promtail

**Log Shipper**
- Collects logs from various sources
- Adds labels and metadata
- Ships to Loki

**Configuration:** `loki/promtail-config.yml`

### AlertManager (Port 9093)

**Alert Routing**
- Deduplicates alerts
- Groups related alerts
- Routes to notification channels

**Notification Channels:**
- Email
- Slack
- PagerDuty
- Webhooks

**Configuration:** `alertmanager/alertmanager.yml`

## Alert Rules

File: `prometheus/alerts.yml`

**Alert Categories:**

1. **System Alerts**
   - HighCPUUsage (>80% for 5m)
   - CriticalCPUUsage (>95% for 2m)
   - HighMemoryUsage (>85% for 5m)
   - CriticalMemoryUsage (>95% for 2m)
   - DiskSpaceLow (<15% for 5m)
   - DiskSpaceCritical (<10% for 2m)

2. **Container Alerts**
   - ContainerDown (1m)
   - ContainerHighMemory (>90% for 5m)
   - ContainerHighCPU (>80% for 5m)
   - ContainerRestarting (5m)

3. **Database Alerts**
   - PostgreSQLDown (1m)
   - PostgreSQLTooManyConnections (>80% max)
   - PostgreSQLReplicationLag (>10s)
   - PostgreSQLDeadlocks
   - PostgreSQLSlowQueries (>5min)

4. **Redis Alerts**
   - RedisDown (1m)
   - RedisHighMemoryUsage (>90%)
   - RedisRejectedConnections
   - RedisSlowCommands
   - RedisMissingMaster

5. **HTTP Endpoint Alerts**
   - HTTPEndpointDown (2m)
   - HTTPEndpointSlow (>5s)
   - HTTPEndpointStatusCode (>=400)
   - SSLCertificateExpiringSoon (<30 days)
   - SSLCertificateExpired

6. **Application Alerts**
   - BackendHighErrorRate (>5% for 5m)
   - BackendHighLatency (p95 >1s)

7. **Monitoring Stack Alerts**
   - PrometheusDown
   - AlertManagerDown
   - GrafanaDown

## Exporters

### Node Exporter (Port 9100)
- CPU, memory, disk metrics
- Network I/O
- File system usage

### cAdvisor (Port 8080)
- Container CPU, memory usage
- Container network I/O
- Container disk usage

### PostgreSQL Exporter (Port 9187)
- Connection count
- Query statistics
- Replication lag
- Cache hit ratio

### Redis Exporter (Port 9121)
- Memory usage
- Connected clients
- Command statistics
- Key statistics

### Nginx Exporter (Port 9113)
- Active connections
- Request rate
- Connection states

### Blackbox Exporter (Port 9115)
- HTTP/HTTPS probes
- TCP connection checks
- SSL certificate expiry
- Response times

## Configuration Files

### Prometheus Configuration

**prometheus.yml:**
```yaml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'node'
    static_configs:
      - targets: ['node_exporter:9100']

  # ... more targets
```

**alerts.yml:**
```yaml
groups:
  - name: system
    rules:
      - alert: HighCPUUsage
        expr: cpu_usage > 80
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High CPU usage"
```

### Loki Configuration

**loki-config.yml:**
```yaml
auth_enabled: false

server:
  http_listen_port: 3100

limits_config:
  retention_period: 720h  # 30 days
```

**promtail-config.yml:**
```yaml
server:
  http_listen_port: 9080

clients:
  - url: http://loki:3100/loki/api/v1/push

scrape_configs:
  - job_name: docker
    static_configs:
      - targets:
          - localhost
        labels:
          __path__: /var/lib/docker/containers/*/*.log
```

### AlertManager Configuration

**alertmanager.yml:**
```yaml
global:
  smtp_smarthost: 'smtp.gmail.com:587'
  smtp_from: 'alerts@promptforge.io'

route:
  receiver: 'default'
  group_by: ['alertname', 'severity']

receivers:
  - name: 'default'
    email_configs:
      - to: 'admin@promptforge.io'
```

## Usage

### Start Monitoring

```bash
# Start all monitoring services
./monitoring-setup.sh --start
```

### View Metrics

```bash
# Open Grafana
http://localhost:3000

# Default credentials
Username: admin
Password: admin
```

### Query Logs

```bash
# Open Grafana > Explore > Select Loki

# Example queries:
{job="docker"}                           # All Docker logs
{job="docker"} |= "ERROR"                # Error logs
{job="nginx", type="access"}             # Nginx access logs
rate({job="docker"}[5m]) by (name)       # Log rate per container
```

### View Alerts

```bash
# Prometheus alerts
http://localhost:9090/alerts

# AlertManager
http://localhost:9093
```

### Test Alerts

```bash
# Send test alert
./monitoring-setup.sh --test-alert
```

## Troubleshooting

### Services Not Starting

```bash
# Check status
./monitoring-setup.sh --status

# View logs
./monitoring-setup.sh --logs [service]

# Restart service
docker-compose -f docker-compose.monitoring.yml restart [service]
```

### No Metrics in Grafana

```bash
# Check Prometheus targets
http://localhost:9090/targets

# Verify exporters are running
docker ps | grep exporter

# Check Prometheus logs
docker logs promptforge-prometheus
```

### No Logs in Loki

```bash
# Check Promtail logs
docker logs promptforge-promtail

# Verify log files exist
ls -la logs/

# Test Loki
curl http://localhost:3100/ready
```

## Customization

### Add Custom Metrics

Edit `prometheus/prometheus.yml`:
```yaml
scrape_configs:
  - job_name: 'my-app'
    static_configs:
      - targets: ['my-app:9999']
```

### Add Custom Alerts

Edit `prometheus/alerts.yml`:
```yaml
groups:
  - name: custom
    rules:
      - alert: MyCustomAlert
        expr: my_metric > 100
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Custom alert fired"
```

### Add Custom Dashboard

1. Create dashboard in Grafana UI
2. Export JSON
3. Save to `grafana/dashboards/my-dashboard.json`
4. Restart Grafana

## Environment Variables

File: `.env.monitoring`

```bash
# Grafana
GRAFANA_ADMIN_USER=admin
GRAFANA_ADMIN_PASSWORD=admin

# AlertManager Email
SMTP_HOST=smtp.gmail.com:587
SMTP_USERNAME=your-email@gmail.com
SMTP_PASSWORD=your-app-password
ALERT_EMAIL_FROM=alerts@promptforge.io

# Slack (optional)
SLACK_WEBHOOK_URL=https://hooks.slack.com/services/...

# PagerDuty (optional)
PAGERDUTY_SERVICE_KEY=your-key
```

## Resource Usage

**Per Component:**
- Prometheus: ~2GB RAM, 2 CPU
- Grafana: ~512MB RAM, 1 CPU
- Loki: ~1GB RAM, 1 CPU
- Promtail: ~256MB RAM, 0.5 CPU
- AlertManager: ~256MB RAM, 0.5 CPU
- Exporters: ~1.5GB RAM, 2.5 CPU total

**Total:** ~5.5GB RAM, ~8 CPU cores

## Backup

**Backup Prometheus Data:**
```bash
docker cp promptforge-prometheus:/prometheus ./prometheus-backup
```

**Backup Grafana Dashboards:**
```bash
docker cp promptforge-grafana:/var/lib/grafana/dashboards ./grafana-backup
```

**Backup Loki Data:**
```bash
docker cp promptforge-loki:/loki ./loki-backup
```

## Support

- **Documentation**: docs/monitoring.md
- **Grafana Docs**: https://grafana.com/docs/
- **Prometheus Docs**: https://prometheus.io/docs/
- **Loki Docs**: https://grafana.com/docs/loki/

---

For complete documentation, see: [docs/monitoring.md](../docs/monitoring.md)
