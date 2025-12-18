# Azure DevOps Setup Guide for Application Deployment

This guide walks you through setting up Azure DevOps for deploying the OpenTelemetry Demo application to AKS, while keeping GitHub Actions for infrastructure (Terraform) deployment.

## Architecture Overview

- **GitHub Actions** → Infrastructure deployment (Terraform)
- **Azure DevOps** → Application deployment (Docker + Helm + AKS)

---

## Prerequisites

- ✅ Azure DevOps organization (existing)
- ✅ GitHub repository: `achyutamba/ultimate-devops-project-demo`
- ✅ Azure subscription: `71f7a3ab-31db-4871-bd83-0e1c1d14bd07`
- ✅ Service Principal (already created): `8ed1f59c-93f6-47d4-8b15-74d6a5621f90`
- ✅ Deployed infrastructure:
  - AKS cluster: `otel-demo-dev-aks`
  - ACR: `oteldemodevacr`
  - Resource group: `otel-demo-dev-rg`

---

## Step 1: Create Azure DevOps Project

1. Go to https://dev.azure.com and sign in to **your existing organization**
2. Click **+ New Project** (top right corner)
3. Configure:
   - **Project name**: `otel-demo`
   - **Visibility**: Private
   - **Version control**: Git
   - **Work item process**: Agile
4. Click **Create**

---

## Step 2: Connect GitHub Repository

### Option A: Import Repository (Recommended)
1. Go to **Repos** → **Files**
2. Click **Import**
3. Enter clone URL: `https://github.com/achyutamba/ultimate-devops-project-demo.git`
4. Click **Import**

### Option B: Connect Existing GitHub Repo
1. Go to **Project Settings** → **Service connections**
2. Click **New service connection**
3. Select **GitHub**
4. Click **Authorize** and connect your GitHub account
5. Select repository: `achyutamba/ultimate-devops-project-demo`

---

## Step 3: Create Azure Service Connection

This connects Azure DevOps to your Azure subscription using the same Service Principal from GitHub Actions.

### Option A: Using Service Principal with Federated Credential (Recommended - No Secret Needed)

1. Go to **Project Settings** (bottom left)
2. Navigate to **Service connections** (under Pipelines)
3. Click **New service connection**
4. Select **Azure Resource Manager** → **Next**
5. Choose **Workload Identity federation (automatic)** or **Service principal (manual)**
6. Fill in the details:

   **For Workload Identity federation:**
   ```
   Environment: Azure Cloud
   Scope Level: Subscription
   
   Subscription Id: 71f7a3ab-31db-4871-bd83-0e1c1d14bd07
   Subscription Name: Azure subscription 1
   
   Authentication: Workload Identity federation (automatic)
   
   Service Principal Id: 8ed1f59c-93f6-47d4-8b15-74d6a5621f90
   (Also shown as "Application (client) ID")
   
   Tenant ID: b32e781d-4ae4-4aa8-b51c-be8e5a80dcbf
   ```

   **For Service principal (manual) with secret:**
   ```
   Environment: Azure Cloud
   Scope Level: Subscription
   
   Subscription Id: 71f7a3ab-31db-4871-bd83-0e1c1d14bd07
   Subscription Name: Azure subscription 1
   
   Service Principal Id: 8ed1f59c-93f6-47d4-8b15-74d6a5621f90
   
   Credential: Service principal key
   Service Principal Key: [Get from command below]
   
   Tenant ID: b32e781d-4ae4-4aa8-b51c-be8e5a80dcbf
   ```

7. Click **Verify** to test the connection
8. **Service connection name**: `azure-service-connection`
9. Check **Grant access permission to all pipelines**
10. Click **Verify and save**

### Option B: How to Get Service Principal Key (if using secret-based auth)

**If you need to create a new client secret:**

```bash
# Login to Azure
az login

# Create new client secret for the Service Principal
az ad sp credential reset \
  --id 8ed1f59c-93f6-47d4-8b15-74d6a5621f90 \
  --append

# Copy the "password" value - this is your Service Principal Key
```

**Important**: Save this key immediately - you won't be able to see it again!

### Field Mapping Reference

| Azure DevOps Field | Your Value |
|-------------------|------------|
| Application (client) ID | `8ed1f59c-93f6-47d4-8b15-74d6a5621f90` |
| Service Principal Id | `8ed1f59c-93f6-47d4-8b15-74d6a5621f90` |
| Tenant ID | `b32e781d-4ae4-4aa8-b51c-be8e5a80dcbf` |
| Subscription ID | `71f7a3ab-31db-4871-bd83-0e1c1d14bd07` |
| Subscription Name | `Azure subscription 1` |

---

## Step 4: Create Variable Groups

Variable groups store configuration that pipelines use.

### Create Variable Group: `otel-demo-common`

1. Go to **Pipelines** → **Library**
2. Click **+ Variable group**
3. **Variable group name**: `otel-demo-common`
4. Click **+ Add** for each variable:

   | Variable Name | Value |
   |--------------|-------|
   | `ACR_NAME` | `oteldemodevacr` |
   | `ACR_LOGIN_SERVER` | `oteldemodevacr.azurecr.io` |
   | `AZURE_SERVICE_CONNECTION` | `azure-service-connection` |
   | `IMAGE_TAG` | `latest` |

5. Click **Save**

### Create Variable Group: `otel-demo-dev`

1. Click **+ Variable group** again
2. **Variable group name**: `otel-demo-dev`
3. Click **+ Add** for each variable:

   | Variable Name | Value |
   |--------------|-------|
   | `DEV_RESOURCE_GROUP` | `otel-demo-dev-rg` |
   | `DEV_AKS_CLUSTER` | `otel-demo-dev-aks` |
   | `DEV_NAMESPACE` | `otel-demo` |
   | `DEV_ENVIRONMENT` | `dev` |
   | `ACR_REGISTRY_NAME` | `oteldemodevacr` |

4. Click **Save**

---

## Step 5: Create Pipeline Environments

Environments provide deployment history and approvals.

1. Go to **Pipelines** → **Environments**
2. Click **Create environment**

### Environment 1: `otel-demo-dev`
- **Name**: `otel-demo-dev`
- **Description**: Development environment for OpenTelemetry Demo
- **Resource**: Kubernetes
  - **Provider**: Azure Kubernetes Service
  - **Azure subscription**: Select your service connection
  - **Cluster**: `otel-demo-dev-aks`
  - **Namespace**: `otel-demo`
- Click **Create**

### Environment 2: `otel-demo-observability`
- **Name**: `otel-demo-observability`
- **Description**: Observability stack (Prometheus, Grafana, Jaeger)
- **Resource**: Kubernetes
  - **Azure subscription**: Select your service connection
  - **Cluster**: `otel-demo-dev-aks`
  - **Namespace**: `observability`
- Click **Create**

---

## Step 6: Grant AKS Permissions to Service Principal

The Service Principal needs permissions to deploy to AKS.

```bash
# Login to Azure
az login

# Get Service Principal Object ID
SP_OBJECT_ID=$(az ad sp show --id 8ed1f59c-93f6-47d4-8b15-74d6a5621f90 --query id -o tsv)

# Get AKS Resource ID
AKS_ID=$(az aks show \
  --resource-group otel-demo-dev-rg \
  --name otel-demo-dev-aks \
  --query id -o tsv)

# Grant "Azure Kubernetes Service Cluster User Role"
az role assignment create \
  --assignee $SP_OBJECT_ID \
  --role "Azure Kubernetes Service Cluster User Role" \
  --scope $AKS_ID

# Grant "Azure Kubernetes Service RBAC Writer"
az role assignment create \
  --assignee $SP_OBJECT_ID \
  --role "Azure Kubernetes Service RBAC Writer" \
  --scope $AKS_ID
```

---

## Step 7: Grant ACR Permissions

Service Principal needs to push images to ACR.

```bash
# Get ACR Resource ID
ACR_ID=$(az acr show \
  --name oteldemodevacr \
  --resource-group otel-demo-dev-rg \
  --query id -o tsv)

# Grant "AcrPush" role (allows push and pull)
az role assignment create \
  --assignee 8ed1f59c-93f6-47d4-8b15-74d6a5621f90 \
  --role "AcrPush" \
  --scope $ACR_ID
```

---

## Step 8: Create Your First Pipeline

### Option A: Full CD Pipeline (All Services)

1. Go to **Pipelines** → **Pipelines**
2. Click **New pipeline**
3. Select **GitHub** (or **Azure Repos Git** if you imported)
4. Select your repository
5. Choose **Existing Azure Pipelines YAML file**
6. Select branch: `main`
7. Path: `/azure-pipelines/cd-pipeline.yml`
8. Click **Continue**
9. Review the YAML
10. Click **Run**

### Option B: Frontend-Only Pipeline (Cost-Optimized)

1. Go to **Pipelines** → **Pipelines**
2. Click **New pipeline**
3. Select repository source
4. Choose **Existing Azure Pipelines YAML file**
5. Path: `/azure-pipelines/frontend-dev-only.yml`
6. Click **Continue** → **Run**

---

## Step 9: Configure Build Pipeline (CI)

For building Docker images and pushing to ACR:

1. Go to **Pipelines** → **Pipelines**
2. Click **New pipeline**
3. Select repository
4. Choose **Existing Azure Pipelines YAML file**
5. Path: `/azure-pipelines/ci-pipeline.yml`
6. Click **Continue**
7. Click **Save** (don't run yet - this needs parameters)

---

## Step 10: Set Up Pipeline Trigger

Configure the CD pipeline to run automatically after CI:

1. Go to **Pipelines** → **Pipelines**
2. Select your CD pipeline
3. Click **Edit**
4. In the YAML, update the `resources` section:

   ```yaml
   resources:
     pipelines:
       - pipeline: ci-pipeline
         source: '[Your CI Pipeline Name]'  # Update this
         trigger:
           branches:
             include:
               - main
   ```

5. Click **Save**

---

## Deployment Workflows

### Workflow 1: Infrastructure Changes
```
Developer pushes to terraform/* → GitHub Actions → Terraform apply → Infrastructure updated
```

### Workflow 2: Application Changes
```
Developer pushes to src/* → Azure DevOps CI Pipeline → Build images → Push to ACR
→ Trigger CD Pipeline → Deploy to AKS (Dev) → (Optional) Deploy to Staging/Prod
```

---

## Verification Steps

### Test Service Connection
```bash
# From Azure DevOps Pipeline terminal or local machine
az login --service-principal \
  -u 8ed1f59c-93f6-47d4-8b15-74d6a5621f90 \
  -p [SERVICE_PRINCIPAL_KEY] \
  --tenant [TENANT_ID]

# Test ACR access
az acr login --name oteldemodevacr

# Test AKS access
az aks get-credentials \
  --resource-group otel-demo-dev-rg \
  --name otel-demo-dev-aks
  
kubectl get nodes
```

### Manual Deployment Test
```bash
# Clone the repository
git clone https://github.com/achyutamba/ultimate-devops-project-demo.git
cd ultimate-devops-project-demo

# Login to ACR
az acr login --name oteldemodevacr

# Deploy using Helm
helm upgrade --install otel-demo ./helm-charts/otel-demo \
  -f ./helm-charts/otel-demo/values-dev.yaml \
  --namespace otel-demo \
  --create-namespace \
  --set image.repository=oteldemodevacr.azurecr.io \
  --set image.tag=latest

# Check deployment
kubectl get pods -n otel-demo
```

---

## Troubleshooting

### Issue: "Service connection not found"
**Solution**: Make sure the service connection name in variable group matches exactly: `azure-service-connection`

### Issue: "Failed to get credentials for AKS"
**Solution**: Grant Service Principal the "Azure Kubernetes Service Cluster User Role":
```bash
az role assignment create \
  --assignee 8ed1f59c-93f6-47d4-8b15-74d6a5621f90 \
  --role "Azure Kubernetes Service Cluster User Role" \
  --scope $(az aks show -n otel-demo-dev-aks -g otel-demo-dev-rg --query id -o tsv)
```

### Issue: "Unauthorized to access ACR"
**Solution**: Grant Service Principal "AcrPush" role:
```bash
az role assignment create \
  --assignee 8ed1f59c-93f6-47d4-8b15-74d6a5621f90 \
  --role "AcrPush" \
  --scope $(az acr show -n oteldemodevacr -g otel-demo-dev-rg --query id -o tsv)
```

### Issue: "Helm not found"
**Solution**: The pipeline includes HelmInstaller@1 task. Ensure it runs before helm commands.

### Issue: "Namespace not found"
**Solution**: Add `--create-namespace` to helm upgrade command or create it manually:
```bash
kubectl create namespace otel-demo
```

---

## Pipeline Architecture

### CI Pipeline Flow
```
Trigger: Push to src/* or main
├── Stage 1: Build
│   ├── Build all microservice Docker images
│   └── Save as artifacts
├── Stage 2: Security Scan
│   ├── Trivy scan for vulnerabilities
│   └── Publish reports
├── Stage 3: Push to ACR
│   ├── Login to ACR
│   ├── Tag images
│   └── Push to registry
└── Stage 4: Notify
    └── Send Slack/Teams notification
```

### CD Pipeline Flow
```
Trigger: Manual or CI completion
├── Stage 1: Deploy Observability
│   ├── Deploy Prometheus, Grafana, Jaeger
│   └── Namespace: observability
├── Stage 2: Deploy to Dev
│   ├── Helm lint & template
│   ├── Deploy to otel-demo namespace
│   ├── Wait for pods ready
│   └── Smoke test
├── Stage 3: Deploy to Staging (Optional)
│   ├── Canary deployment (25%)
│   ├── Monitor for 5 minutes
│   └── Promote to 100%
└── Stage 4: Deploy to Prod (Manual approval)
    ├── Blue-Green deployment
    └── Switch traffic
```

---

## Next Steps

1. ✅ Complete all setup steps above
2. ✅ Run permissions scripts (Steps 6 & 7)
3. ✅ Create service connection and variable groups
4. ✅ Create pipeline environments
5. 🚀 Run your first pipeline deployment
6. 📊 Monitor deployment in Azure DevOps
7. 🔍 Check pods: `kubectl get pods -n otel-demo`
8. 🌐 Access frontend via LoadBalancer IP

---

## Cost Optimization Tips

- Use `frontend-dev-only.yml` pipeline to deploy only frontend initially
- Scale down replicas in `values-dev.yaml` when not testing
- Use spot instances for non-production AKS node pools
- Enable AKS cluster autoscaler with min=0 for dev
- Delete dev environment when not in use (keep staging/prod)

---

## Additional Resources

- [Azure DevOps Documentation](https://docs.microsoft.com/azure/devops/)
- [Helm Documentation](https://helm.sh/docs/)
- [AKS Best Practices](https://docs.microsoft.com/azure/aks/best-practices)
- [Azure Service Connections](https://docs.microsoft.com/azure/devops/pipelines/library/service-endpoints)

---

## Quick Reference

**Your Infrastructure Details:**
- Subscription: `71f7a3ab-31db-4871-bd83-0e1c1d14bd07`
- Resource Group: `otel-demo-dev-rg`
- AKS Cluster: `otel-demo-dev-aks`
- ACR: `oteldemodevacr.azurecr.io`
- Service Principal: `8ed1f59c-93f6-47d4-8b15-74d6a5621f90`
- Region: `westus2`

**Key Namespaces:**
- Application: `otel-demo`
- Observability: `observability`

**Pipeline Files:**
- CI: `azure-pipelines/ci-pipeline.yml`
- CD (Full): `azure-pipelines/cd-pipeline.yml`
- CD (Frontend Only): `azure-pipelines/frontend-dev-only.yml`

