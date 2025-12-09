# GitOps with Argo CD

This document explains how Argo CD is (or will be) integrated for GitOps delivery of the Helm chart.

## Why Argo CD
- Declarative, pull-based deployment model
- Auditability via Git history
- Automated drift detection and self heal
- Safe progressive delivery with sync waves and phases

## Components Added
- `kubernetes/argocd/namespace.yaml` — Creates the `argocd` namespace
- `kubernetes/argocd/argocd-install.yaml` — Minimal server deployment (for demo). For production use full upstream install manifests.
- `kubernetes/argocd/apps/otel-demo-*.yaml` — Argo CD `Application` CRs for dev, staging, and prod pointing to Helm chart path and environment values files.
- `kubernetes/argocd/production/` — Production-grade manifests (server, repo-server, application-controller, dex, redis-ha, RBAC, ingress).
  - `argocd-pdb.yaml` — PodDisruptionBudgets for HA availability during node maintenance.
  - `argocd-networkpolicy.yaml` — NetworkPolicies restricting ingress/egress flows.
  - `argocd-servicemonitor.yaml` — Prometheus ServiceMonitors for metrics scraping.
  - `argocd-keyvault-csi.yaml` — Key Vault CSI SecretProviderClass example for OIDC secret injection.

## Installing Argo CD (Demo)
Apply namespace and install manifest:
```bash
kubectl apply -f kubernetes/argocd/namespace.yaml
kubectl apply -f kubernetes/argocd/argocd-install.yaml
```

Then apply Application CRs:
```bash
kubectl apply -f kubernetes/argocd/apps/otel-demo-dev.yaml
kubectl apply -f kubernetes/argocd/apps/otel-demo-staging.yaml
kubectl apply -f kubernetes/argocd/apps/otel-demo-prod.yaml
```

## Production Installation (Recommended)
Use official upstream install for CRDs and all components:
```bash
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/v2.10.0/manifests/install.yaml
```
Then layer production overrides:
```bash
kubectl apply -f kubernetes/argocd/production/argocd-rbac.yaml
kubectl apply -f kubernetes/argocd/production/argocd-ha-deployments.yaml
kubectl apply -f kubernetes/argocd/production/argocd-redis-ha.yaml
kubectl apply -f kubernetes/argocd/production/argocd-ingress.yaml
kubectl apply -f kubernetes/argocd/production/argocd-pdb.yaml
kubectl apply -f kubernetes/argocd/production/argocd-networkpolicy.yaml
kubectl apply -f kubernetes/argocd/production/argocd-servicemonitor.yaml
```

For Key Vault CSI integration (secure OIDC secret):
1. Ensure Key Vault CSI driver installed: https://azure.github.io/secrets-store-csi-driver-provider-azure/
2. Grant AKS managed identity read access to Key Vault.
3. Store OIDC client secret in Key Vault as `argocd-oidc-client-secret`.
4. Apply SecretProviderClass and patch argocd-server deployment to mount volume:
```bash
kubectl apply -f kubernetes/argocd/production/argocd-keyvault-csi.yaml
# Patch argocd-server deployment with volume/volumeMount (see inline comments in argocd-keyvault-csi.yaml)
```

## Architecture Overview
```
			 +-------------------+
			 |   Git Repository  |
			 +---------+---------+
					 |
			   (Watch / Poll)
					 |
			 +---------v---------+
			 |  Argo CD Server   |<-- Ingress (HTTPS)
			 +----+----+----+----+
				 |    |
				 |    +------------------+
				 |                       |
		    +------v------+        +-------v-------+
		    |  Dex (OIDC) |        |  Repo Server  |
		    +------+------+        +-------+-------+
				 |                       |
			  Auth / SSO            Fetch & Cache Manifests
				 |                       |
			 +----v-----------------------v----+
			 |     Application Controller      |
			 +---------------+-----------------+
						  |
					  Reconcile
						  |
					 +-----v------+
					 | Kubernetes |
					 +------------+

		Redis HA Cluster (Session/Cache) <----> All Argo CD components
```

Key Interactions:
- Server exposes API/UI; authenticated via Azure AD OIDC (Dex or native OIDC).
- Repo Server fetches Helm/Kustomize/manifest sources from Git.
- Application Controller compares desired vs live state and performs sync operations.
- Redis provides caching for application state and tokens.
- Ingress routes external HTTPS traffic to server replicas.

## High Availability Notes
- `argocd-server` replicas: 2+ for UI/API redundancy.
- `argocd-repo-server` replicas: 2+ (stateless; ensure shared volume only if custom plugins need persistent storage).
- `argocd-application-controller`: typically single; advanced sharding requires configuration beyond this baseline.
- Redis: 3-node StatefulSet (or dedicated managed Redis) for HA.
- Use PodDisruptionBudgets for each component to protect against voluntary evictions.

## Resource Management
Example requests/limits applied in `argocd-ha-deployments.yaml`—tune based on sync frequency and number of Applications:
- Server: 250m–500m CPU, 256Mi–512Mi RAM
- Repo Server: 250m–750m CPU, 256Mi–768Mi RAM
- Controller: 500m–1000m CPU, 512Mi–1Gi RAM
- Dex: 100m–300m CPU, 128Mi–256Mi RAM
- Redis: 50m–200m CPU, 64Mi–256Mi RAM

PodDisruptionBudgets ensure `minAvailable: 1` (or 2 for Redis) during voluntary disruptions.

## RBAC & SSO
`argocd-rbac.yaml` defines Azure AD group to role mapping (`role:admin`, `role:readonly`). Replace placeholders:
- `<TENANT_ID>` Azure AD tenant
- `<AAD_ADMIN_GROUP_ID>` / `<AAD_READONLY_GROUP_ID>` group object IDs
- Client secret injected via `argocd-secret` (do NOT commit real secret; use external secret management / Key Vault CSI)

## Security Hardening Checklist
- Enforce TLS via ingress; redirect HTTP to HTTPS.
- Restrict ingress to corporate CIDRs or WAF front end.
- NetworkPolicies limiting namespace egress except Git and required endpoints (see `argocd-networkpolicy.yaml`).
- Scan Argo CD images (supply digest pins instead of tags for prod).
- Rotate OIDC client secret periodically.
- Use Key Vault CSI driver to inject secrets into pods (see `argocd-keyvault-csi.yaml` for example).
- Pin images by digest (replace `:v2.10.0` with `@sha256:...`).

## Operations
- Health: `kubectl argo rollouts` (if plugin) or `argocd app health` CLI.
- Sync waves: annotate resources with `argocd.argoproj.io/sync-wave`.
- Rollback: revert Git commit; controller reconciles automatically.
- Scaling: adjust replicas and apply; monitor latency of repo operations.

## Monitoring
- Scrape `/metrics` from server, repo-server, controller deployments (add Prometheus annotations).
- Track sync duration, app health metrics, reconciliation errors for alerting.
- ServiceMonitors are provided for Prometheus Operator; ensure Prometheus is configured to scrape the `argocd` namespace.
- Key metrics: `argocd_app_sync_total`, `argocd_app_reconcile_duration_seconds`, `argocd_git_request_duration_seconds`.


## Application CR Structure
Each `Application` references:
- `repoURL`: Git repository containing chart
- `path`: Chart directory (`helm-charts/otel-demo`)
- `helm.valueFiles`: environment-specific values (e.g. `values-dev.yaml`)
- `destination.namespace`: target namespace
- `syncPolicy.automated`: enable auto-prune and self-heal

## Secrets & Config
- Argo CD should not store plaintext secrets; rely on external secret operators (Key Vault CSI driver) or sealed secrets.
- Pipeline can continue to build images; Argo picks them up via tag updates in values or image automation (Git commit changes).

## Migration Strategy from Classic CD
1. Keep CI pipeline unchanged (build/scan/push images)
2. Add Argo CD Applications for dev environment; monitor sync health
3. Disable dev stage in existing CD pipeline (or set to manual approval only)
4. Expand to staging and prod once confidence gained
5. Remove Helm deploy steps from Azure DevOps pipeline after full cutover

## Security Hardening (Production)
- Use official Argo CD install (RBAC, repo server, redis, controller components)
- Restrict access: enable SSO (Azure AD), network policies, and ingress with TLS
- Add resource requests/limits to all Argo pods (demo manifest is minimal)
- Enable `refreshTokens` and repository credential management policies

## Observability Integration
- Argo CD server metrics can be scraped by Prometheus; add an annotation or ServiceMonitor
- Audit logs can be shipped to Azure Monitor via fluent-bit or sidecar log shipping

## Sync Waves & Hooks (Optional)
- Use `sync-wave` annotations for ordering (e.g., CRDs, namespaces, core infra before apps)
- PreSync/PostSync hooks for database migration jobs or canary analysis

## Rollback
- Roll back by reverting Git commit to previous chart values or image version; Argo CD auto-sync will reconcile
- Manual rollback: disable auto-sync (`argocd app set <app> --sync-policy none`), apply manual helm rollback if needed, then re-enable

## Next Enhancements
- Add Image Updater integration for automatic image tag updates
- Add App-of-Apps pattern to manage all Applications via a single root
- Introduce cluster secrets operator for Key Vault integration

Refer back to this doc after productionizing the install with the full upstream YAML and adding RBAC/SSO.
