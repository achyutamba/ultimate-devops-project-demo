# CI/CD — Azure DevOps pipelines (Extended)

This document describes the CI and CD pipelines used to build, scan, and deploy the microservices to AKS.

Pipeline components

- CI pipeline (azure-pipelines/ci-pipeline.yml)
  - Steps: Checkout -> Build -> Unit tests -> Container image build -> Trivy scan -> Push to ACR -> Publish image tag to artifacts
  - Use a hosted agent or self-hosted agent with Docker and `az` installed

- CD pipeline (azure-pipelines/cd-pipeline.yml)
  - Multi-stage: DeployToDev -> DeployToStaging -> DeployToProd
  - Each stage runs: fetch image tags -> render helm with `values-<env>.yaml` -> helm lint/diff -> helm upgrade --install
  - Observability stage: separate stage or parallel job to deploy OTel/Prometheus/Grafana if enabled

Service connections and permissions
- Service Principal used by the pipeline requires:
  - Contributor on environment resource group(s) for resource creation
  - `AcrPush` role or permission to push images to ACR (CI)
  - Storage Blob Data Contributor on the Terraform state storage account (for state operations)
  - Access to Key Vault secrets (Key Vault Reader or appropriate policy)

Kubeconfig and AKS access
- Use `az aks get-credentials --resource-group <rg> --name <cluster>` in pipeline with a service principal that has access to the AKS cluster
- Alternatively, use `kubelogin` and OIDC for short-lived tokens

Canary and rollback
- Canary: Use Helm to create partial rollouts (e.g. subset of replicas) or use manual traffic-shifting in ingress with labels/weights
- Automatic rollback: use `--atomic` with `helm upgrade` so failed deploys revert

Secrets in pipelines
- Do not store secrets in pipeline variables unless `secret` and in Key Vault-backed pipeline variables
- Best practice: pipelines read secrets from Key Vault at runtime and inject as environment variables or create Kubernetes secrets on-the-fly for deployment

Observability & verification steps
- After deploy, run smoke tests (simple `curl` endpoints) and metrics checks (Prometheus query via API) as part of post-deploy validation

Example quick deploy commands for a pipeline job

```bash
az login --service-principal -u $AZ_SP_ID -p $AZ_SP_SECRET --tenant $AZ_TENANT
az account set --subscription $AZ_SUBS_ID
az aks get-credentials --resource-group $AKS_RG --name $AKS_NAME --file kubeconfig
export KUBECONFIG=$(pwd)/kubeconfig
helm repo add mycharts https://example
helm lint ./helm-charts/otel-demo
helm upgrade --install otel-demo ./helm-charts/otel-demo -f ./helm-charts/otel-demo/values-dev.yaml --namespace dev --create-namespace --atomic
```

This doc should be read alongside `README-AZURE-CICD.md` in the repo root for environment-specific pipeline configuration and service connection setup.
