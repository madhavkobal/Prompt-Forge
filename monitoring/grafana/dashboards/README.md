# Grafana Dashboards for PromptForge

This directory contains Grafana dashboard configurations for monitoring PromptForge.

## Quick Start

1. **Auto-provisioning**: Dashboards in this directory are automatically loaded by Grafana
2. **Manual Import**: You can also import dashboards via Grafana UI (Dashboards → Import)

## Creating a Dashboard

### Option 1: Via Grafana UI

1. Open Grafana (`http://localhost:3000`)
2. Click "+" → "Dashboard"
3. Add panels with Prometheus queries
4. Save the dashboard
5. Export it: Dashboard Settings → JSON Model → Copy to clipboard
6. Save to a file in this directory (e.g., `promptforge-overview.json`)

### Option 2: Using Terraform

Use the Grafana Terraform provider to manage dashboards as code.

## Recommended Dashboards

### 1. PromptForge Overview
**File**: `promptforge-overview.json`

Key metrics:
- Request rate (requests/sec)
- Error rate (5xx responses)
- Request latency (p50, p95, p99)
- Active users
- Prompts analyzed (rate)

### 2. Performance Dashboard
**File**: `promptforge-performance.json`

Metrics:
- Response time distribution
- Slow requests
- Database query performance
- Gemini API latency
- Memory and CPU usage

### 3. User Activity Dashboard
**File**: `promptforge-users.json`

Metrics:
- User registrations
- Login attempts (success/failure)
- Active users
- Most active users
- Prompt creation rate by user

### 4. Gemini API Dashboard
**File**: `promptforge-gemini.json`

Metrics:
- API request rate
- API latency
- Error rate by endpoint
- Token usage (if tracked)
- Cost estimation

### 5. Database Dashboard
**File**: `promptforge-database.json`

Metrics:
- Query rate by type
- Query latency
- Active connections
- Slow queries
- Database size/growth

## Sample Prometheus Queries

### Request Rate
```promql
rate(http_requests_total[5m])
```

### Error Rate
```promql
rate(http_requests_total{status_code=~"5.."}[5m])
```

### Request Latency (95th percentile)
```promql
histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m]))
```

### Active Users
```promql
active_users
```

### Prompts Analyzed (per minute)
```promql
rate(prompts_analyzed_total[1m]) * 60
```

### Database Query Performance
```promql
histogram_quantile(0.95, rate(database_query_duration_seconds_bucket[5m]))
```

### Gemini API Error Rate
```promql
rate(gemini_api_errors_total[5m])
```

## Exporting Dashboards

To export a dashboard:

1. Open the dashboard in Grafana
2. Click the settings icon (gear) → JSON Model
3. Copy the entire JSON
4. Save to a file in this directory
5. Commit to version control

## Importing Dashboards

### Via UI
1. Grafana UI → "+" → "Import"
2. Upload JSON file or paste JSON content
3. Select Prometheus data source
4. Click "Import"

### Via Provisioning (Automatic)
1. Place JSON file in this directory
2. Restart Grafana (or wait for auto-reload)
3. Dashboard will appear automatically

## Variables

Use dashboard variables for filtering:

- `$environment` - Environment (production, staging, development)
- `$endpoint` - API endpoint filter
- `$status_code` - HTTP status code filter

Example query with variable:
```promql
rate(http_requests_total{endpoint="$endpoint"}[5m])
```

## Best Practices

1. **Use consistent naming** - Prefix all dashboards with "PromptForge -"
2. **Add descriptions** - Include panel descriptions explaining metrics
3. **Set appropriate refresh rates** - 5s for production, 30s for overview
4. **Use template variables** - Make dashboards reusable across environments
5. **Export regularly** - Keep dashboard JSON in version control
6. **Document custom queries** - Add comments explaining complex PromQL queries

## Troubleshooting

### Dashboard not loading
- Check Prometheus data source is configured correctly
- Verify Prometheus is scraping metrics: `http://localhost:9090/targets`
- Check metrics endpoint is accessible: `http://localhost:8000/metrics`

### No data in panels
- Verify metric names match Prometheus metrics
- Check time range is appropriate
- Confirm data exists: Query in Prometheus UI first

### Dashboard changes not persisting
- If using provisioning, edit the JSON file directly
- If created via UI, ensure you have save permissions
- Check Grafana logs for errors

## Additional Resources

- [Grafana Dashboard Documentation](https://grafana.com/docs/grafana/latest/dashboards/)
- [PromQL Cheat Sheet](https://promlabs.com/promql-cheat-sheet/)
- [Grafana Community Dashboards](https://grafana.com/grafana/dashboards/)
