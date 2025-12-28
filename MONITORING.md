# Monitoring and Observability Guide

Comprehensive guide for monitoring PromptForge in production.

## Table of Contents

1. [Overview](#overview)
2. [Logging](#logging)
3. [Error Tracking (Sentry)](#error-tracking-sentry)
4. [Metrics (Prometheus)](#metrics-prometheus)
5. [Grafana Dashboards](#grafana-dashboards)
6. [Health Checks](#health-checks)
7. [Log Aggregation](#log-aggregation)
8. [Alerting](#alerting)
9. [Performance Monitoring](#performance-monitoring)

---

## Overview

PromptForge includes comprehensive monitoring and observability features:

- **Structured Logging**: JSON-formatted logs for easy parsing and aggregation
- **Error Tracking**: Sentry integration for real-time error monitoring
- **Metrics**: Prometheus metrics for system and application monitoring
- **Health Checks**: Multiple health endpoints for uptime monitoring and orchestration
- **Performance Monitoring**: Request timing, slow query detection, and performance metrics

---

## Logging

### Structured Logging

PromptForge uses structured logging with JSON format for production environments:

```python
# Logs are automatically structured with:
# - timestamp
# - level (INFO, WARNING, ERROR)
# - service (PromptForge)
# - version
# - environment
# - custom fields (method, path, status_code, etc.)
```

### Configuration

Set logging configuration in `.env`:

```bash
# Log level (DEBUG, INFO, WARNING, ERROR, CRITICAL)
LOG_LEVEL=INFO

# Log format (json for production, text for development)
LOG_FORMAT=json
```

### Log Levels

- **DEBUG**: Detailed information for debugging
- **INFO**: General informational messages
- **WARNING**: Warning messages (slow requests, etc.)
- **ERROR**: Error messages with stack traces
- **CRITICAL**: Critical errors that require immediate attention

### Example Log Output

JSON format (production):
```json
{
  "timestamp": "2025-01-15 10:30:45",
  "level": "INFO",
  "service": "PromptForge",
  "version": "1.0.0",
  "environment": "production",
  "message": "HTTP request processed",
  "method": "POST",
  "path": "/api/v1/prompts",
  "status_code": 200,
  "process_time_seconds": 0.145,
  "client_ip": "192.168.1.100"
}
```

---

## Error Tracking (Sentry)

### Setup

1. **Create Sentry Account**:
   - Sign up at [sentry.io](https://sentry.io)
   - Create a new project for PromptForge
   - Copy the DSN (Data Source Name)

2. **Configure Environment**:
   ```bash
   # .env.production
   SENTRY_DSN=https://your-sentry-dsn@sentry.io/project-id
   SENTRY_ENVIRONMENT=production
   SENTRY_TRACES_SAMPLE_RATE=0.1  # Sample 10% of transactions
   ```

3. **Verification**:
   ```bash
   # Test Sentry integration
   curl -X POST http://localhost:8000/api/v1/test-error
   # Check Sentry dashboard for the error
   ```

### Features

- **Automatic Error Capture**: All unhandled exceptions are sent to Sentry
- **Performance Monitoring**: Transaction tracing for slow requests
- **Release Tracking**: Track errors by application version
- **User Context**: Identify which users encounter errors
- **Stack Traces**: Full stack traces with source code context

### Sentry Dashboard

Access your Sentry dashboard at: `https://sentry.io/organizations/your-org/projects/promptforge/`

---

## Metrics (Prometheus)

### Metrics Endpoint

Prometheus metrics are exposed at: `GET /metrics`

Example:
```bash
curl http://localhost:8000/metrics
```

### Available Metrics

#### HTTP Request Metrics
- `http_requests_total` - Total HTTP requests (labels: method, endpoint, status_code)
- `http_request_duration_seconds` - Request latency histogram
- `http_requests_in_progress` - Current requests in progress
- `slow_requests_total` - Slow requests exceeding threshold

#### Gemini API Metrics
- `gemini_api_requests_total` - Total Gemini API requests
- `gemini_api_duration_seconds` - Gemini API latency
- `gemini_api_errors_total` - Gemini API errors

#### Database Metrics
- `database_queries_total` - Total database queries
- `database_query_duration_seconds` - Query latency
- `database_connections_active` - Active database connections

#### User Activity Metrics
- `user_registrations_total` - Total user registrations
- `user_logins_total` - Total login attempts
- `active_users` - Active users in last 24 hours

#### Prompt Analysis Metrics
- `prompts_analyzed_total` - Total prompts analyzed
- `prompts_enhanced_total` - Total prompts enhanced
- `prompt_quality_score` - Quality score distribution
- `templates_created_total` - Templates created
- `templates_used_total` - Template usage

#### System Metrics
- `exceptions_total` - Unhandled exceptions

### Prometheus Configuration

Create `prometheus.yml`:

```yaml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

scrape_configs:
  - job_name: 'promptforge'
    static_configs:
      - targets: ['backend:8000']
    metrics_path: '/metrics'
```

### Running Prometheus

With Docker:
```bash
docker run -d \
  --name prometheus \
  -p 9090:9090 \
  -v ./prometheus.yml:/etc/prometheus/prometheus.yml \
  prom/prometheus
```

With docker-compose (add to `docker-compose.prod.yml`):
```yaml
services:
  prometheus:
    image: prom/prometheus:latest
    container_name: promptforge_prometheus
    restart: unless-stopped
    ports:
      - "9090:9090"
    volumes:
      - ./monitoring/prometheus.yml:/etc/prometheus/prometheus.yml
      - prometheus_data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
    networks:
      - promptforge_network

volumes:
  prometheus_data:
```

Access Prometheus at: `http://localhost:9090`

---

## Grafana Dashboards

### Setup Grafana

1. **Add to docker-compose**:
   ```yaml
   grafana:
     image: grafana/grafana:latest
     container_name: promptforge_grafana
     restart: unless-stopped
     ports:
       - "3000:3000"
     environment:
       GF_SECURITY_ADMIN_PASSWORD: ${GRAFANA_PASSWORD}
     volumes:
       - grafana_data:/var/lib/grafana
       - ./monitoring/grafana/dashboards:/etc/grafana/provisioning/dashboards
       - ./monitoring/grafana/datasources:/etc/grafana/provisioning/datasources
     networks:
       - promptforge_network
   ```

2. **Configure Prometheus as Data Source**:
   Create `monitoring/grafana/datasources/prometheus.yml`:
   ```yaml
   apiVersion: 1
   datasources:
     - name: Prometheus
       type: prometheus
       access: proxy
       url: http://prometheus:9090
       isDefault: true
   ```

3. **Access Grafana**:
   - URL: `http://localhost:3000`
   - Default credentials: `admin` / `<GRAFANA_PASSWORD>`

### Importing Dashboard

The PromptForge Grafana dashboard is available in `monitoring/grafana/dashboards/promptforge.json`.

To import:
1. Go to Grafana UI
2. Click "+" → "Import"
3. Upload `promptforge.json`
4. Select Prometheus data source
5. Click "Import"

---

## Health Checks

### Available Endpoints

#### 1. Basic Health Check
```bash
GET /health
```

Returns simple health status:
```json
{
  "status": "healthy",
  "version": "1.0.0",
  "environment": "production"
}
```

#### 2. Detailed Health Check
```bash
GET /health/detailed
```

Returns comprehensive health status:
```json
{
  "status": "healthy",
  "version": "1.0.0",
  "environment": "production",
  "timestamp": 1705318245.123,
  "uptime_seconds": 3600.5,
  "checks": {
    "database": {
      "status": "healthy",
      "response_time_ms": 12.34
    },
    "gemini_api": {
      "status": "healthy",
      "response_time_ms": 234.56
    }
  }
}
```

#### 3. Readiness Probe (Kubernetes)
```bash
GET /health/ready
```

Returns readiness status for orchestration:
```json
{
  "ready": true,
  "checks": {
    "database": {"status": "healthy"}
  },
  "timestamp": 1705318245.123
}
```

#### 4. Liveness Probe (Kubernetes)
```bash
GET /health/live
```

Returns liveness status:
```json
{
  "alive": true,
  "timestamp": 1705318245.123,
  "uptime_seconds": 3600.5
}
```

### Kubernetes Configuration

```yaml
apiVersion: v1
kind: Pod
spec:
  containers:
  - name: promptforge
    image: promptforge:latest
    livenessProbe:
      httpGet:
        path: /health/live
        port: 8000
      initialDelaySeconds: 30
      periodSeconds: 10
    readinessProbe:
      httpGet:
        path: /health/ready
        port: 8000
      initialDelaySeconds: 10
      periodSeconds: 5
```

---

## Log Aggregation

### Option 1: Logtail (Recommended for Simplicity)

1. **Sign up**: Create account at [logtail.com](https://logtail.com)

2. **Configure**:
   ```bash
   # Install vector for log shipping
   docker run -d \
     --name vector \
     -v ./vector.toml:/etc/vector/vector.toml:ro \
     -v /var/run/docker.sock:/var/run/docker.sock:ro \
     timberio/vector:latest
   ```

3. **Create `vector.toml`**:
   ```toml
   [sources.docker]
   type = "docker_logs"
   include_containers = ["promptforge_backend"]

   [sinks.logtail]
   type = "http"
   inputs = ["docker"]
   uri = "https://in.logtail.com"
   encoding.codec = "json"

   [sinks.logtail.headers]
   Authorization = "Bearer YOUR_LOGTAIL_TOKEN"
   ```

### Option 2: ELK Stack (Elasticsearch, Logstash, Kibana)

1. **Add to docker-compose**:
   ```yaml
   elasticsearch:
     image: elasticsearch:8.11.0
     environment:
       - discovery.type=single-node
       - "ES_JAVA_OPTS=-Xms512m -Xmx512m"
     ports:
       - "9200:9200"
     volumes:
       - elasticsearch_data:/usr/share/elasticsearch/data

   kibana:
     image: kibana:8.11.0
     ports:
       - "5601:5601"
     environment:
       ELASTICSEARCH_URL: http://elasticsearch:9200
     depends_on:
       - elasticsearch
   ```

2. **Configure Filebeat** to ship logs to Elasticsearch

3. **Access Kibana**: `http://localhost:5601`

### Option 3: CloudWatch (AWS)

Use AWS CloudWatch Logs with the awslogs driver:

```yaml
services:
  backend:
    logging:
      driver: awslogs
      options:
        awslogs-region: us-east-1
        awslogs-group: promptforge
        awslogs-stream: backend
```

---

## Alerting

### Prometheus Alerting Rules

Create `prometheus-alerts.yml`:

```yaml
groups:
  - name: promptforge_alerts
    rules:
      # High error rate
      - alert: HighErrorRate
        expr: rate(http_requests_total{status_code=~"5.."}[5m]) > 0.05
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "High error rate detected"
          description: "Error rate is {{ $value }} errors/sec"

      # Slow requests
      - alert: SlowRequests
        expr: rate(slow_requests_total[5m]) > 10
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High number of slow requests"

      # Database issues
      - alert: DatabaseDown
        expr: up{job="promptforge"} == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "Database is down"

      # High memory usage
      - alert: HighMemoryUsage
        expr: process_resident_memory_bytes > 1000000000
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "High memory usage (>1GB)"
```

### Alertmanager Configuration

```yaml
global:
  smtp_smarthost: 'smtp.gmail.com:587'
  smtp_from: 'alerts@yourdomain.com'
  smtp_auth_username: 'alerts@yourdomain.com'
  smtp_auth_password: 'your-password'

route:
  group_by: ['alertname']
  group_wait: 10s
  group_interval: 10s
  repeat_interval: 1h
  receiver: 'email'

receivers:
  - name: 'email'
    email_configs:
      - to: 'oncall@yourdomain.com'
```

---

## Performance Monitoring

### Request Timing

Automatic request timing is enabled. Slow requests (>1s by default) are logged:

```bash
# Configure threshold
SLOW_REQUEST_THRESHOLD=1.0  # seconds
```

### Database Query Monitoring

Track database queries with metrics:

```python
from app.core.metrics import track_database_query

# In your database code
track_database_query("select", duration)
```

### Gemini API Monitoring

Track Gemini API calls:

```python
from app.core.metrics import track_gemini_request

track_gemini_request("analyze", duration, status="success")
```

---

## Best Practices

1. **Always use structured logging** for production environments
2. **Set up Sentry** for real-time error notifications
3. **Monitor key metrics** in Grafana dashboards
4. **Configure alerts** for critical issues
5. **Review logs regularly** for anomalies
6. **Test health checks** during deployments
7. **Keep retention policies** for logs and metrics (30 days recommended)
8. **Use log sampling** for high-traffic endpoints to reduce costs

---

## Troubleshooting

### Metrics not appearing in Prometheus

1. Check metrics endpoint: `curl http://localhost:8000/metrics`
2. Verify Prometheus can reach the backend
3. Check Prometheus targets: `http://localhost:9090/targets`

### Sentry not receiving errors

1. Verify `SENTRY_DSN` is set correctly
2. Check Sentry project settings
3. Test with a manual error
4. Review Sentry quota limits

### Logs not structured

1. Verify `LOG_FORMAT=json` in environment
2. Check logging configuration in code
3. Restart application after changes

### Health checks failing

1. Check database connectivity
2. Verify Gemini API key
3. Review detailed health endpoint: `/health/detailed`
4. Check service logs for errors

---

## Additional Resources

- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)
- [Sentry Documentation](https://docs.sentry.io/)
- [Structured Logging Best Practices](https://cloud.google.com/logging/docs/structured-logging)
