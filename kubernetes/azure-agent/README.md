# Azure Pipelines Self-Hosted Agent on AKS

This directory contains Kubernetes manifests to deploy Azure Pipelines agents on your AKS cluster.

## Prerequisites

1. **Create a Personal Access Token (PAT) in Azure DevOps:**
   - Go to Azure DevOps → User Settings (top right) → Personal Access Tokens
   - Click **New Token**
   - Name: `AKS-Agent-Token`
   - Scopes: Select **Agent Pools (Read & manage)**
   - Click **Create**
   - **Copy the token immediately** (you won't see it again)

2. **Create Agent Pool in Azure DevOps:**
   - Go to Project Settings → Agent pools
   - Click **Add pool**
   - Pool type: **Self-hosted**
   - Name: `AKS-Agent-Pool`
   - Grant access permission to all pipelines
   - Click **Create**

## Deployment Steps

### 1. Update the Secret

Edit `secret.yaml` and replace:
- `YOUR_ORG` - Your Azure DevOps organization name
- `YOUR_PAT_TOKEN` - The PAT token you created above

Example:
```yaml
stringData:
  AZP_URL: "https://dev.azure.com/myorg"
  AZP_TOKEN: "abcd1234efgh5678ijkl"
  AZP_POOL: "AKS-Agent-Pool"
```

### 2. Deploy to AKS

```bash
# Connect to your AKS cluster
az aks get-credentials \
  --resource-group otel-demo-dev-rg \
  --name otel-demo-dev-aks

# Deploy the agent
kubectl apply -f kubernetes/azure-agent/namespace.yaml
kubectl apply -f kubernetes/azure-agent/secret.yaml
kubectl apply -f kubernetes/azure-agent/deployment.yaml

# Check agent status
kubectl get pods -n azure-pipelines
```

### 3. Verify Agents in Azure DevOps

- Go to Project Settings → Agent pools → AKS-Agent-Pool
- You should see 2 agents online (from replicas: 2)

### 4. Update Your Pipeline

Update `ci-pipeline.yml` to use the new pool:

```yaml
pool:
  name: 'AKS-Agent-Pool'  # Instead of vmImage: 'ubuntu-latest'
```

## Scaling

To add more agents:
```bash
kubectl scale deployment azdevops-agent --replicas=4 -n azure-pipelines
```

## Troubleshooting

Check agent logs:
```bash
kubectl logs -n azure-pipelines deployment/azdevops-agent
```

Check events:
```bash
kubectl get events -n azure-pipelines --sort-by='.lastTimestamp'
```

## Cost Savings

Running agents on your existing AKS cluster avoids:
- Waiting for Microsoft's parallelism approval (2-3 days)
- Paying for hosted agents ($40/month per parallel job)
- Uses your existing AKS infrastructure
