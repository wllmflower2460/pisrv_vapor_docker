# Grafana & Prometheus Provisioning (PiSrv)

This bundle gives you:
- **Grafana dashboards provisioning** (auto-load dashboard JSONs on startup)
- **Grafana Prometheus datasource** (optional)
- **Prometheus alert rules** (error rate, latency p95, and no-traffic)

## Layout

```
/etc/grafana/provisioning/
  dashboards/
    pisrv/
      grafana_pisrv_prometheus_dashboard.json   # put the JSON here
    dashboards-pisrv.yaml                       # from this bundle
  datasources/
    datasource-prometheus.yaml                  # from this bundle (optional)

/etc/prometheus/
  rules/
    prometheus_rules_pisrv.yml                  # from this bundle
prometheus.yml                                   # add 'rule_files' entry
```

## Steps

### 1) Grafana
1. Copy `dashboards-pisrv.yaml` to `/etc/grafana/provisioning/dashboards/`.
2. Create folder `/etc/grafana/provisioning/dashboards/pisrv/` and place your dashboard JSON(s) in it (e.g., `grafana_pisrv_prometheus_dashboard.json`).
3. (Optional) Copy `datasource-prometheus.yaml` to `/etc/grafana/provisioning/datasources/` and edit the `url` if Prometheus is not at `http://prometheus:9090`.
4. Restart Grafana: `sudo systemctl restart grafana-server` (or docker restart).

### 2) Prometheus
1. Copy `prometheus_rules_pisrv.yml` to `/etc/prometheus/rules/`.
2. Edit `prometheus.yml` to include:
   ```yaml
   rule_files:
     - /etc/prometheus/rules/prometheus_rules_pisrv.yml
   ```
3. Restart Prometheus.

### Alert Details
- **PiSrvHighErrorRate**: 4xx/5xx > **5%** for **5m**.
- **PiSrvLatencyP95High**: p95 latency > **0.5s** for **10m**.
- **PiSrvNoTraffic**: zero total request rate for **10m** (fires after 15m).

### Notes
- If you want **route-specific** alerts, add `by (route)` to the PromQL aggregations and set labels in annotations.
- Ensure your Vapor app exposes `/metrics` and Prometheus scrapes it:
  ```yaml
  scrape_configs:
    - job_name: 'pisrv'
      static_configs:
        - targets: ['<pi-ip>:8080']
      metrics_path: /metrics
      scrape_interval: 15s
  ```
