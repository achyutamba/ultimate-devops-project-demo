# Quickstart — Get a dev environment running

This quickstart walks through the minimal steps to get the dev environment up in Azure. It assumes you have access to an Azure subscription and appropriate permissions.

Prerequisites
- Azure CLI (latest)
- Terraform (>= required version in `terraform/environments/dev/main.tf`)
- kubectl
- helm

Steps
1. Login and select subscription

```bash
az login --use-device-code
az account set --subscription $AZ_SUBSCRIPTION_ID
```

2. Bootstrap terraform for dev

```bash
cd terraform/environments/dev
terraform init
terraform apply -var="project_name=otel-demo" -var="location=eastus" -auto-approve
```

3. Build and push images (local dev or CI)
- Locally, build a demo image and push to ACR created by Terraform. Use the `acr.login_server` output.

```bash
# authenticate with ACR
az acr login --name <acr_name>
# build and push
docker build -t <acr_login_server>/frontend:dev -f src/frontend/Dockerfile .
docker push <acr_login_server>/frontend:dev
```

4. Deploy Helm chart to dev

```bash
# get AKS credentials
az aks get-credentials --resource-group <rg> --name <cluster> --file kubeconfig
export KUBECONFIG=$(pwd)/kubeconfig
helm upgrade --install otel-demo ./helm-charts/otel-demo -n dev --create-namespace -f helm-charts/otel-demo/values-dev.yaml --atomic
```

5. Validate
- `kubectl get pods -n dev`
- `kubectl port-forward svc/frontend 8080:80 -n dev` and open `http://localhost:8080`

Notes
- For CI-driven workflows, the CI pipeline handles image builds, scanning, and ACR pushes and the CD pipeline handles Helm releases.
- Use dev environment to iterate quickly; for staging/prod adjust `values-*.yaml` for higher resource limits and replica counts.
