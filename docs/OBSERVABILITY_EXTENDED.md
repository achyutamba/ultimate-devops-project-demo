# Observability — OpenTelemetry, Prometheus and Grafana

This doc describes the observability architecture and how to operate and extend the stack.

Components
- OpenTelemetry Collector — central in-cluster collector for traces and metrics
- Prometheus — metrics scraping and alerting (optionally deployed via Helm)
- Grafana — dashboards and explorability
- Azure Monitor / Log Analytics — long-term metrics and logs

Instrumentation
- Services should use OpenTelemetry SDKs for the language (Java, .NET, Go, Node.js)
- Export traces and metrics to the local OTel Collector endpoint
- Use standard semantic conventions to ensure consistent attributes

Collector configuration
- Use a collector config that:
  - Receives OTLP (gRPC and HTTP)
  - Batches and retries exports
  - Exports to Prometheus for scraping and to Azure Monitor for retention

Prometheus
- The Helm chart includes Prometheus scrape configs for the application endpoints and the OTel Collector
- Keep scrape interval conservative (15s-60s) depending on environment

Grafana
- Include baseline dashboards for service-level latency, throughput, error rates, and infra metrics
- Example dashboards included with chart: Service Overview, API Latency, Node/Pod CPU & Memory

Alerting
- Use Prometheus rules for SRE/operational alerts (high CPU, high error rate, pod restart loop)
- Push critical alerts into Azure Monitor or use Alertmanager for notifications (email, Slack, PagerDuty)

OpenTelemetry sampling
- Use adaptive or tail-based sampling for production to reduce cost and storage
- Lower sampling in dev for full-fidelity traces for debugging

Costs & retention
- Prometheus and Grafana are good for short-term operational visibility
- Use Azure Monitor (Log Analytics) for longer retention and cross-cluster correlation; be mindful of ingestion costs

Troubleshooting tips
- If no traces show up: check OTel Collector pods logs and ensure OTLP endpoint is reachable
- Prometheus missing metrics: validate `prometheus.io/scrape` annotations on pods/services
- Grafana dashboards blank: check data source configuration points to Prometheus or Log Analytics

Next steps
- Add example Grafana dashboards to `docs/dashboards/` and link them here
- Provide a sample OTel Collector `config.yaml` in `helm-charts/otel-demo/templates/observability/` for easy override
