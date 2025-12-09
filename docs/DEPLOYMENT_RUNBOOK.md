# Deployment Runbook

This runbook provides step-by-step actions for deploying and rolling back releases across environments.

Prerequisites
- Azure CLI installed and authenticated with service principal or user with appropriate permissions
- `helm` installed and version compatible with charts (v3+)
- `kubectl` installed
- Access to Key Vault or pipeline variables for secrets

Deploy to dev (manual)
1. Ensure correct subscription and context:

```bash
az login --use-device-code
az account set --subscription $AZ_SUBSCRIPTION_ID
```

2. Get AKS credentials:

```bash
az aks get-credentials --resource-group $AKS_RG --name $AKS_NAME --file kubeconfig
export KUBECONFIG=$(pwd)/kubeconfig
```

3. Validate the Helm chart:

```bash
helm lint helm-charts/otel-demo
helm template otel-demo ./helm-charts/otel-demo -f helm-charts/otel-demo/values-dev.yaml | kubectl apply --dry-run=client -f -
```

4. Deploy:

```bash
helm upgrade --install otel-demo ./helm-charts/otel-demo -n dev --create-namespace -f helm-charts/otel-demo/values-dev.yaml --atomic --timeout 10m
```

5. Post-deploy checks
- `kubectl get pods -n dev` — ensure pods are running
- `kubectl logs -n dev <pod>` for evidence of start-up
- Run smoke tests against the frontend endpoints

Rollback
- To rollback to previous release:

```bash
helm rollback otel-demo <revision> -n dev
```

- If Helm fails to rollback automatically, use `kubectl rollout undo deployment/<deployment-name> -n dev` for the impacted deployment as a fallback.

Deploy to staging/prod
- Follow same steps with `values-staging.yaml` or `values-production.yaml` and appropriate cluster and namespace.
- For prod, use a maintenance window and increase timeouts for `helm upgrade`.

Secrets rotation
- Rotate secrets in Key Vault.
- Update the pipeline to pick up new secrets or trigger a rolling restart of impacted deployments:

```bash
kubectl rollout restart deployment/<name> -n <env>
```

Emergency recovery
- If cluster becomes unhealthy and can't be recovered within window, re-deploy workloads to a new AKS cluster and restore DB from backup if necessary.
- Keep a documented contact list for subscription admins and resource owners.
