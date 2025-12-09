# Helm & Kubernetes — Chart structure and operational guidance

This document dives into the Helm chart used by the project (`helm-charts/otel-demo`) and how Kubernetes manifests are generated and deployed.

Chart layout (key files)
- `Chart.yaml` — metadata and chart version
- `values.yaml` — default values for all microservices and global defaults
- `templates/` — Helm templates (Deployments, Services, ServiceAccounts, HPA, NetworkPolicies, ConfigMaps)
- `_helpers.tpl` — common helper template functions used across templates

Values design patterns
- Keep defaults minimal and environment-specific overrides in `values-dev.yaml`, `values-staging.yaml`, `values-production.yaml`.
- Per-service section example:

```yaml
frontend:
  image: repo/frontend:{{ .Chart.AppVersion }}
  replicaCount: 2
  resources:
    requests:
      cpu: 100m
      memory: 128Mi
    limits:
      cpu: 250m
      memory: 256Mi
  env:
    - name: DATABASE_URL
      valueFrom: ...
```

Secrets & Key Vault
- Prefer Key Vault CSI provider to mount secrets into pods.
- If using pipeline-injected Kubernetes Secrets, ensure they are created from Key Vault values on deploy and not stored in repo.

NetworkPolicies
- The Helm chart contains toggles to enable NetworkPolicy templates.
- Baseline: deny all ingress, then allow specific ingress to frontend and service-to-service rules.

Autoscaling
- HorizontalPodAutoscaler templates are included and enabled via `values` per-service. Example config includes min/max replicas and CPU utilization target.

Observability annotations
- Services and pods include annotations controlled by values, e.g. `prometheus.io/scrape: "true"` and OTel resource attributes.

Helm lifecycle
- Recommended CD practice: `helm lint` -> `helm template` (diff) -> `helm upgrade --install --atomic --timeout 10m`.
- Use `--atomic` so failed upgrades are rolled back automatically.

Working with stateful components
- For Kafka/Valkey evaluate StatefulSet and `volumeClaimTemplates` for persistent volumes.
- For dev you may use simple Deployments with ephemeral storage; for staging/prod use PVC-backed StatefulSets.

Helm CI tips
- Add `helm lint` and `helm template` in the CI pipeline. Use `helm diff` plugin in PR checks.
- Validate file sizes of rendered manifests and ensure there are no missing required variables.

This document should be read alongside `helm-charts/otel-demo/README.md` which contains chart-specific install commands and values examples.
