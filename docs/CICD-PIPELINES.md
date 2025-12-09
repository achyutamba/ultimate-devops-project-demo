# CI/CD Pipelines Documentation

## Table of Contents

- [Overview](#overview)
- [Pipeline Architecture](#pipeline-architecture)
- [CI Pipeline](#ci-pipeline)
- [CD Pipeline](#cd-pipeline)
- [Variable Groups](#variable-groups)
- [Deployment Strategies](#deployment-strategies)
- [Security Scanning](#security-scanning)
- [Environments](#environments)
- [Rollback Procedures](#rollback-procedures)
- [Monitoring and Alerts](#monitoring-and-alerts)
- [Troubleshooting](#troubleshooting)

---

## Overview

The project uses Azure DevOps pipelines for continuous integration and continuous deployment. The pipeline strategy follows industry best practices:

- **Separation of concerns**: Distinct CI and CD pipelines
- **Multi-environment deployment**: Dev → Staging → Production
- **Security first**: Automated vulnerability scanning
- **Gradual rollout**: Canary and blue-green deployments
- **Automated rollback**: On health check failures
- **Artifact management**: Versioned container images

### Pipeline Flow

```
┌──────────────────────────────────────────────────────────┐
│                     Developer Workflow                    │
└──────────────────────────────────────────────────────────┘
                            │
                            ▼
┌──────────────────────────────────────────────────────────┐
│  Git Push to main/develop                                │
│  - Triggers CI Pipeline automatically                    │
└──────────────────────────────────────────────────────────┘
                            │
                            ▼
┌──────────────────────────────────────────────────────────┐
│                    CI Pipeline (Build)                    │
│  1. Checkout code                                        │
│  2. Build Docker images (18 microservices)               │
│  3. Run unit tests                                       │
│  4. Security scan (Trivy)                                │
│  5. Push to Azure Container Registry (ACR)               │
│  6. Tag: BuildID, commit SHA, latest                     │
└──────────────────────────────────────────────────────────┘
                            │
                            ▼
┌──────────────────────────────────────────────────────────┐
│              CD Pipeline (Deploy to Dev)                 │
│  1. Triggered by CI completion                           │
│  2. Deploy observability stack                           │
│  3. Helm upgrade to Dev cluster                          │
│  4. Wait for pods ready                                  │
│  5. Run smoke tests                                      │
└──────────────────────────────────────────────────────────┘
                            │
                            ▼ (Manual approval)
┌──────────────────────────────────────────────────────────┐
│          CD Pipeline (Deploy to Staging)                 │
│  1. Manual approval required                             │
│  2. Helm diff (show changes)                             │
│  3. Canary deployment (25% → 100%)                      │
│  4. Monitor metrics for 5 minutes                        │
│  5. Automated integration tests                          │
│  6. Rollback on failure                                  │
└──────────────────────────────────────────────────────────┘
                            │
                            ▼ (Manual approval + change ticket)
┌──────────────────────────────────────────────────────────┐
│         CD Pipeline (Deploy to Production)               │
│  1. Manual approval + change ticket                      │
│  2. Blue-Green deployment                                │
│  3. Deploy to Green environment                          │
│  4. Comprehensive smoke tests                            │
│  5. Switch traffic (Blue → Green)                       │
│  6. Monitor golden signals                               │
│  7. Keep Blue for 24h (quick rollback)                   │
└──────────────────────────────────────────────────────────┘
```

---

## Pipeline Architecture

### File Structure

```
azure-pipelines/
├── ci-pipeline.yml          # Continuous Integration pipeline
├── cd-pipeline.yml          # Continuous Deployment pipeline
├── templates/               # Reusable pipeline templates (future)
│   ├── build-service.yml
│   ├── deploy-helm.yml
│   └── security-scan.yml
└── README.md
```

### Trigger Configuration

#### CI Pipeline

```yaml
trigger:
  branches:
    include:
      - main
      - develop
  paths:
    include:
      - src/*           # Only trigger on source code changes
```

#### CD Pipeline

```yaml
trigger: none  # Manual or CI pipeline completion

resources:
  pipelines:
    - pipeline: ci-pipeline
      source: 'otel-demo-ci'
      trigger:
        branches:
          include:
            - main
```

---

## CI Pipeline

### Purpose

Build, test, and publish Docker images for all microservices.

### Stages

#### 1. Build Stage

**Objective**: Build Docker images for all 18 microservices

**Implementation**:

```yaml
- stage: Build
  displayName: 'Build Docker Images'
  jobs:
    - job: BuildImages
      displayName: 'Build Microservices'
      pool:
        vmImage: 'ubuntu-latest'
      
      strategy:
        matrix:
          dev:
            ENVIRONMENT: 'dev'
            NAMESPACE: 'otel-demo-dev'
          staging:
            ENVIRONMENT: 'staging'
            NAMESPACE: 'otel-demo-staging'
          prod:
            ENVIRONMENT: 'prod'
            NAMESPACE: 'otel-demo-prod'
      
      steps:
        - checkout: self
          fetchDepth: 1
        
        - task: Docker@2
          displayName: 'Build service image'
          inputs:
            command: 'build'
            dockerfile: '$(DOCKERFILE_PATH)'
            tags: |
              $(IMAGE_TAG)
              latest
              $(Build.SourceBranchName)
            arguments: '--build-arg BUILDKIT_INLINE_CACHE=1'
        
        - task: Docker@2
          displayName: 'Save image as artifact'
          inputs:
            command: 'save'
            arguments: '-o $(Build.ArtifactStagingDirectory)/$(SERVICE_NAME)-$(IMAGE_TAG).tar $(SERVICE_NAME):$(IMAGE_TAG)'
        
        - task: PublishBuildArtifacts@1
          displayName: 'Publish artifacts'
          inputs:
            pathToPublish: '$(Build.ArtifactStagingDirectory)/$(SERVICE_NAME)-$(IMAGE_TAG).tar'
            artifactName: '$(SERVICE_NAME)-image-$(ENVIRONMENT)'
```

**Services Built**:
- Frontend
- Cart
- Checkout
- Payment
- Shipping
- Product Catalog
- Recommendation
- Ad
- Currency
- Email
- Quote
- Accounting
- Fraud Detection
- Image Provider
- FlagD
- FlagD UI
- Load Generator
- Frontend Proxy

#### 2. Security Scan Stage

**Objective**: Scan images for vulnerabilities using Trivy

**Implementation**:

```yaml
- stage: SecurityScan
  displayName: 'Security Scanning'
  dependsOn: Build
  jobs:
    - job: TrivyScan
      displayName: 'Trivy Security Scan'
      pool:
        vmImage: 'ubuntu-latest'
      
      strategy:
        matrix:
          accounting:
            SERVICE_NAME: 'accounting'
          frontend:
            SERVICE_NAME: 'frontend'
          # ... (all services)
      
      steps:
        - task: DownloadBuildArtifacts@1
          inputs:
            buildType: 'current'
            artifactName: '$(SERVICE_NAME)-image'
            downloadPath: '$(System.ArtifactsDirectory)'
        
        - task: Docker@2
          displayName: 'Load image'
          inputs:
            command: 'load'
            arguments: '-i $(System.ArtifactsDirectory)/$(SERVICE_NAME)-image/$(SERVICE_NAME)-$(IMAGE_TAG).tar'
        
        - script: |
            # Install Trivy
            wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | sudo apt-key add -
            echo "deb https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -sc) main" | sudo tee -a /etc/apt/sources.list.d/trivy.list
            sudo apt-get update
            sudo apt-get install trivy -y
            
            # Scan image
            trivy image --severity HIGH,CRITICAL --format sarif --output $(Build.ArtifactStagingDirectory)/trivy-$(SERVICE_NAME).sarif $(SERVICE_NAME):$(IMAGE_TAG)
            trivy image --severity HIGH,CRITICAL $(SERVICE_NAME):$(IMAGE_TAG)
          displayName: 'Run Trivy scan'
          continueOnError: true
        
        - task: PublishBuildArtifacts@1
          displayName: 'Publish scan results'
          inputs:
            pathToPublish: '$(Build.ArtifactStagingDirectory)/trivy-$(SERVICE_NAME).sarif'
            artifactName: 'trivy-reports'
```

**Severity Levels**:
- **CRITICAL**: CVE score 9.0-10.0 (fails build in production)
- **HIGH**: CVE score 7.0-8.9 (warning in dev/staging)
- **MEDIUM/LOW**: Informational

#### 3. Push to ACR Stage

**Objective**: Push signed images to Azure Container Registry

**Implementation**:

```yaml
- stage: PushToACR
  displayName: 'Push to Azure Container Registry'
  dependsOn: SecurityScan
  condition: succeeded()
  jobs:
    - job: PushImages
      displayName: 'Push to ACR'
      pool:
        vmImage: 'ubuntu-latest'
      
      steps:
        - task: AzureCLI@2
          displayName: 'Login to ACR'
          inputs:
            azureSubscription: '$(AZURE_SERVICE_CONNECTION)'
            scriptType: 'bash'
            scriptLocation: 'inlineScript'
            inlineScript: |
              az acr login --name $(ACR_NAME)
        
        - task: Docker@2
          displayName: 'Push image'
          inputs:
            command: 'push'
            repository: '$(ACR_LOGIN_SERVER)/$(SERVICE_NAME)'
            tags: |
              $(IMAGE_TAG)
              latest
```

**Image Naming Convention**:
```
<acr-name>.azurecr.io/<service-name>:<tag>

Examples:
oteldemoacr.azurecr.io/frontend:1234
oteldemoacr.azurecr.io/cart:1234
oteldemoacr.azurecr.io/checkout:main-20240115
```

---

## CD Pipeline

### Purpose

Deploy containerized applications to AKS clusters across multiple environments.

### Stages

#### Stage 0: Deploy Observability Stack

**Objective**: Deploy monitoring infrastructure (Prometheus, Grafana, OpenTelemetry Collector)

```yaml
- stage: DeployObservability
  displayName: 'Deploy Observability Stack'
  jobs:
    - deployment: DeployObservability
      displayName: 'Deploy to Observability Namespace'
      environment: 'otel-demo-observability'
      strategy:
        runOnce:
          deploy:
            steps:
              - task: AzureCLI@2
                displayName: 'Get AKS credentials'
                inputs:
                  azureSubscription: '$(AZURE_SERVICE_CONNECTION)'
                  scriptType: 'bash'
                  scriptLocation: 'inlineScript'
                  inlineScript: |
                    az aks get-credentials \
                      --resource-group $(DEV_RESOURCE_GROUP) \
                      --name $(DEV_AKS_CLUSTER) \
                      --overwrite-existing
              
              - script: |
                  helm upgrade --install otel-demo-observability ./helm-charts/otel-demo \
                    -f ./helm-charts/otel-demo/values.yaml \
                    --namespace observability \
                    --create-namespace
                displayName: 'Deploy Observability Stack'
```

**Components**:
- OpenTelemetry Collector (DaemonSet)
- Prometheus (Deployment)
- Grafana (Deployment)
- Service Monitors

#### Stage 1: Deploy to Development

**Objective**: Automatic deployment for rapid feedback

**Deployment Strategy**: Rolling Update

```yaml
- stage: DeployToDev
  displayName: 'Deploy to Development'
  jobs:
    - deployment: DeployDev
      environment: 'otel-demo-dev'
      strategy:
        runOnce:
          deploy:
            steps:
              - checkout: self
              
              - task: AzureCLI@2
                displayName: 'Get AKS credentials'
                inputs:
                  azureSubscription: '$(AZURE_SERVICE_CONNECTION)'
                  scriptType: 'bash'
                  scriptLocation: 'inlineScript'
                  inlineScript: |
                    az aks get-credentials \
                      --resource-group $(DEV_RESOURCE_GROUP) \
                      --name $(DEV_AKS_CLUSTER) \
                      --overwrite-existing
              
              - task: HelmDeploy@0
                displayName: 'Helm upgrade'
                inputs:
                  connectionType: 'Azure Resource Manager'
                  azureSubscription: '$(AZURE_SERVICE_CONNECTION)'
                  kubernetesCluster: '$(DEV_AKS_CLUSTER)'
                  namespace: '$(DEV_NAMESPACE)'
                  command: 'upgrade'
                  chartPath: './helm-charts/otel-demo'
                  releaseName: 'otel-demo'
                  valueFile: './helm-charts/otel-demo/values-dev.yaml'
                  overrideValues: |
                    image.tag=$(IMAGE_TAG)
                    acr.loginServer=$(ACR_LOGIN_SERVER)
                  install: true
                  waitForExecution: true
              
              - script: |
                  kubectl wait --for=condition=ready pod \
                    -l app.kubernetes.io/instance=otel-demo \
                    -n $(DEV_NAMESPACE) \
                    --timeout=300s
                displayName: 'Wait for pods'
              
              - script: |
                  FRONTEND_URL=$(kubectl get svc otel-demo-frontend -n $(DEV_NAMESPACE) -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
                  HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://$FRONTEND_URL/ || echo "000")
                  
                  if [ "$HTTP_CODE" -ge 200 ] && [ "$HTTP_CODE" -lt 400 ]; then
                    echo "✅ Smoke test passed"
                    exit 0
                  else
                    echo "❌ Smoke test failed"
                    exit 1
                  fi
                displayName: 'Smoke test'
```

**Approval**: None (automatic)

#### Stage 2: Deploy to Staging

**Objective**: Pre-production validation with production-like configuration

**Deployment Strategy**: Canary (25% → 100%)

```yaml
- stage: DeployToStaging
  displayName: 'Deploy to Staging'
  dependsOn: DeployToDev
  condition: succeeded()
  jobs:
    - deployment: DeployStaging
      environment: 'otel-demo-staging'
      strategy:
        runOnce:
          deploy:
            steps:
              # ... (similar AKS credentials setup)
              
              - task: HelmDeploy@0
                displayName: 'Helm upgrade (canary 25%)'
                inputs:
                  # ... (same as Dev)
                  overrideValues: |
                    image.tag=$(IMAGE_TAG)
                    rollout.strategy=canary
                    rollout.canaryWeight=25
              
              - script: |
                  echo "Monitoring canary for 5 minutes..."
                  sleep 300
                  
                  # Check error rate
                  ERROR_RATE=$(kubectl logs -l app=frontend -n $(STAGING_NAMESPACE) --tail=100 | grep -c "ERROR" || echo "0")
                  
                  if [ "$ERROR_RATE" -gt 10 ]; then
                    echo "❌ High error rate: $ERROR_RATE"
                    exit 1
                  fi
                  
                  echo "✅ Canary healthy"
                displayName: 'Monitor canary'
              
              - task: HelmDeploy@0
                displayName: 'Promote canary to 100%'
                inputs:
                  # ... (same cluster)
                  overrideValues: |
                    image.tag=$(IMAGE_TAG)
                    rollout.strategy=rolling
                    rollout.canaryWeight=100
```

**Approval**: Manual approval required

**Monitoring Period**: 5 minutes

**Rollback Trigger**: Error rate > 10 errors/5min

#### Stage 3: Deploy to Production

**Objective**: Zero-downtime deployment to production

**Deployment Strategy**: Blue-Green

```yaml
- stage: DeployToProduction
  displayName: 'Deploy to Production'
  dependsOn: DeployToStaging
  condition: succeeded()
  jobs:
    - deployment: DeployProduction
      environment: 'otel-demo-production'
      strategy:
        runOnce:
          deploy:
            steps:
              # ... (AKS credentials)
              
              # Deploy to Green environment
              - task: HelmDeploy@0
                displayName: 'Deploy to Green'
                inputs:
                  namespace: '$(PROD_NAMESPACE)-green'
                  releaseName: 'otel-demo-green'
                  overrideValues: |
                    image.tag=$(IMAGE_TAG)
                    service.selector=green
              
              # Smoke test Green
              - script: |
                  kubectl wait --for=condition=ready pod \
                    -l version=green \
                    -n $(PROD_NAMESPACE)-green \
                    --timeout=600s
                  
                  # Run comprehensive smoke tests
                  ./scripts/smoke-test.sh --env green
                displayName: 'Test Green environment'
              
              # Switch traffic
              - script: |
                  # Update service selector to point to Green
                  kubectl patch svc otel-demo-frontend -n $(PROD_NAMESPACE) \
                    -p '{"spec":{"selector":{"version":"green"}}}'
                  
                  echo "Traffic switched to Green"
                displayName: 'Switch traffic to Green'
              
              # Monitor for 10 minutes
              - script: |
                  echo "Monitoring production for 10 minutes..."
                  
                  for i in {1..10}; do
                    echo "Minute $i/10"
                    
                    # Check error rate
                    ERROR_RATE=$(kubectl logs -l version=green -n $(PROD_NAMESPACE) --since=1m | grep -c "ERROR" || echo "0")
                    
                    if [ "$ERROR_RATE" -gt 5 ]; then
                      echo "❌ High error rate detected"
                      # Rollback
                      kubectl patch svc otel-demo-frontend -n $(PROD_NAMESPACE) \
                        -p '{"spec":{"selector":{"version":"blue"}}}'
                      exit 1
                    fi
                    
                    sleep 60
                  done
                  
                  echo "✅ Production deployment stable"
                displayName: 'Monitor production'
              
              # Cleanup Blue (after 24 hours in separate job)
```

**Approval**: Manual approval + change ticket number

**Monitoring Period**: 10 minutes

**Rollback**: Automatic on errors, or manual within 24 hours

---

## Variable Groups

### Creating Variable Groups

```bash
# Azure DevOps CLI
az devops login
az pipelines variable-group create \
  --name "otel-demo-common" \
  --variables \
    ACR_NAME="oteldemoacr" \
    ACR_LOGIN_SERVER="oteldemoacr.azurecr.io" \
    PROJECT_NAME="otel-demo" \
  --project "YourProject"
```

### Variable Group: `otel-demo-common`

| Variable                   | Value                           | Secret |
|----------------------------|---------------------------------|--------|
| `ACR_NAME`                 | oteldemoacr                     | No     |
| `ACR_LOGIN_SERVER`         | oteldemoacr.azurecr.io          | No     |
| `AZURE_SERVICE_CONNECTION` | azure-service-connection        | No     |
| `PROJECT_NAME`             | otel-demo                       | No     |
| `DEV_AKS_CLUSTER`          | otel-demo-dev-aks               | No     |
| `DEV_RESOURCE_GROUP`       | otel-demo-dev-rg                | No     |
| `DEV_NAMESPACE`            | otel-demo-dev                   | No     |
| `STAGING_AKS_CLUSTER`      | otel-demo-staging-aks           | No     |
| `STAGING_RESOURCE_GROUP`   | otel-demo-staging-rg            | No     |
| `STAGING_NAMESPACE`        | otel-demo-staging               | No     |
| `PROD_AKS_CLUSTER`         | otel-demo-prod-aks              | No     |
| `PROD_RESOURCE_GROUP`      | otel-demo-prod-rg               | No     |
| `PROD_NAMESPACE`           | otel-demo-prod                  | No     |

### Using Variables in Pipelines

```yaml
variables:
  - group: otel-demo-common
  - name: IMAGE_TAG
    value: '$(Build.BuildId)'

steps:
  - script: |
      echo "Deploying to $(DEV_AKS_CLUSTER)"
      echo "Image tag: $(IMAGE_TAG)"
```

---

## Deployment Strategies

### 1. Rolling Update (Development)

**Use Case**: Fast deployments with minimal complexity

**Configuration**:
```yaml
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxSurge: 1         # 1 extra pod during update
    maxUnavailable: 0   # No downtime
```

**Process**:
1. Create new pod with new image
2. Wait for readiness probe
3. Terminate old pod
4. Repeat for all replicas

**Pros**: Simple, fast  
**Cons**: Brief period with mixed versions

### 2. Canary (Staging)

**Use Case**: Gradual rollout with monitoring

**Configuration**:
```yaml
rollout:
  strategy: canary
  canaryWeight: 25  # 25% of traffic to new version
```

**Process**:
1. Deploy 25% of pods with new version
2. Monitor for 5 minutes
3. If healthy, promote to 50%
4. Monitor again
5. Promote to 100%

**Pros**: Risk mitigation, early detection  
**Cons**: Complex, requires monitoring

### 3. Blue-Green (Production)

**Use Case**: Zero-downtime production deployments

**Configuration**:
```yaml
# Blue (current production)
namespace: otel-demo-prod
selector:
  version: blue

# Green (new version)
namespace: otel-demo-prod-green
selector:
  version: green
```

**Process**:
1. Deploy to Green environment
2. Run comprehensive tests on Green
3. Switch service selector to Green
4. Monitor for issues
5. Keep Blue for 24h for quick rollback
6. Cleanup Blue after validation

**Pros**: Instant rollback, no downtime  
**Cons**: Requires 2x resources temporarily

---

## Security Scanning

### Trivy Configuration

**Scan Levels**:
- **Development**: CRITICAL only (informational)
- **Staging**: HIGH and CRITICAL (warnings)
- **Production**: HIGH and CRITICAL (fail build)

**Custom Exceptions** (`.trivyignore`):
```
# Allow specific CVEs after risk assessment
CVE-2023-12345
CVE-2023-67890
```

### Scan Report

Example output:
```
frontend (alpine 3.18)
========================
Total: 15 (HIGH: 3, CRITICAL: 2)

┌─────────────────┬────────────────┬──────────┬──────────────┐
│    Library      │ Vulnerability  │ Severity │   Status     │
├─────────────────┼────────────────┼──────────┼──────────────┤
│ openssl         │ CVE-2023-1234  │ CRITICAL │ fixed in 1.2 │
│ libxml2         │ CVE-2023-5678  │ HIGH     │ will not fix │
└─────────────────┴────────────────┴──────────┴──────────────┘
```

---

## Environments

### Azure DevOps Environments

Create environments with approvals:

```bash
# Development (no approval)
az devops environment create \
  --name "otel-demo-dev" \
  --project "YourProject"

# Staging (manual approval)
az devops environment create \
  --name "otel-demo-staging" \
  --project "YourProject"

# Add approval
az devops environment approval add \
  --environment-name "otel-demo-staging" \
  --approvers "staging-approvers@example.com" \
  --project "YourProject"

# Production (manual approval + change ticket)
az devops environment create \
  --name "otel-demo-production" \
  --project "YourProject"

az devops environment approval add \
  --environment-name "otel-demo-production" \
  --approvers "prod-approvers@example.com" \
  --project "YourProject"
```

### Approval Gates

**Staging**:
- 1 approver required
- Optional: Change ticket number

**Production**:
- 2 approvers required
- Mandatory: Change ticket number
- Mandatory: Business hours only (9 AM - 5 PM)

---

## Rollback Procedures

### Automatic Rollback

Triggered by:
- Health check failures
- High error rates (> threshold)
- Pod crash loops

```yaml
- script: |
    ERROR_RATE=$(kubectl logs -l app=frontend --tail=100 | grep -c "ERROR")
    
    if [ "$ERROR_RATE" -gt 10 ]; then
      echo "Rolling back due to high error rate"
      helm rollback otel-demo -n $(NAMESPACE)
      exit 1
    fi
  displayName: 'Auto-rollback on errors'
```

### Manual Rollback

#### Helm Rollback

```bash
# List release history
helm history otel-demo -n otel-demo-prod

# Rollback to previous
helm rollback otel-demo -n otel-demo-prod

# Rollback to specific revision
helm rollback otel-demo 5 -n otel-demo-prod
```

#### Blue-Green Rollback

```bash
# Switch traffic back to Blue
kubectl patch svc otel-demo-frontend -n otel-demo-prod \
  -p '{"spec":{"selector":{"version":"blue"}}}'
```

#### Via Azure DevOps

1. Navigate to Pipelines → Releases
2. Find the last successful deployment
3. Click "Redeploy"
4. Approve

---

## Monitoring and Alerts

### Pipeline Metrics

Track in Azure DevOps:
- Build duration
- Deployment frequency
- Success rate
- Mean time to recovery (MTTR)

### Application Metrics

Monitor post-deployment:
- **Golden Signals**:
  - Latency (P95 < 500ms)
  - Traffic (requests/sec)
  - Errors (error rate < 1%)
  - Saturation (CPU < 70%)

- **Business Metrics**:
  - Orders per minute
  - Cart abandonment rate
  - Revenue per minute

### Alert Rules

```yaml
# Example: High error rate alert
- alert: HighErrorRate
  expr: rate(http_requests_total{status=~"5.."}[5m]) > 0.05
  for: 5m
  labels:
    severity: critical
  annotations:
    summary: "High error rate detected"
    description: "Error rate is {{ $value }} errors/sec"
```

---

## Troubleshooting

### Common Issues

#### 1. Pipeline Fails at Build

**Error**: `Docker build failed`

**Solutions**:
- Check Dockerfile syntax
- Verify base image exists
- Review build logs

```bash
# Local test
docker build -t test -f src/frontend/Dockerfile .
```

#### 2. Helm Deployment Fails

**Error**: `Release failed: timed out waiting for the condition`

**Solutions**:
- Check pod status: `kubectl get pods -n <namespace>`
- Review pod logs: `kubectl logs <pod-name> -n <namespace>`
- Describe pod: `kubectl describe pod <pod-name> -n <namespace>`

#### 3. Image Pull Error

**Error**: `ErrImagePull` or `ImagePullBackOff`

**Solutions**:
- Verify ACR credentials
- Check AKS managed identity has AcrPull role
- Verify image exists in ACR

```bash
# Test ACR access
az acr login --name oteldemoacr
docker pull oteldemoacr.azurecr.io/frontend:latest
```

#### 4. Service Not Accessible

**Error**: No external IP assigned

**Solutions**:
- Check service type: `kubectl get svc -n <namespace>`
- Verify load balancer: `kubectl describe svc <service-name> -n <namespace>`
- Check Azure Load Balancer in portal

#### 5. Approval Not Appearing

**Error**: Deployment stuck at approval

**Solutions**:
- Verify approvers configured in environment
- Check approver email notifications
- Review environment permissions

---

## Best Practices

### 1. Immutable Tags

Never reuse image tags:
```yaml
# Good
image: frontend:build-1234

# Bad
image: frontend:latest
```

### 2. Version Everything

Tag with multiple identifiers:
```yaml
tags:
  - $(Build.BuildId)        # 1234
  - $(Build.SourceVersion)  # abc123def
  - $(Build.SourceBranchName)-$(Build.BuildId)  # main-1234
```

### 3. Separate Concerns

- CI builds and tests
- CD deploys
- Don't mix in single pipeline

### 4. Test Before Deploy

- Unit tests in CI
- Integration tests in Staging
- Smoke tests in all environments

### 5. Monitor Deployments

- Add health checks
- Monitor golden signals
- Set up alerts for anomalies

---

## Next Steps

1. **Set up Azure DevOps**: Create project and pipelines
2. **Configure Variable Groups**: Add all required variables
3. **Create Environments**: Dev, Staging, Production
4. **Run CI Pipeline**: Build and scan images
5. **Deploy to Dev**: Test automatic deployment
6. **Configure Approvals**: Set up staging/production approvals
7. **Production Deployment**: Deploy with blue-green strategy

---

## References

- [Azure Pipelines Documentation](https://docs.microsoft.com/azure/devops/pipelines/)
- [Helm Deployment Best Practices](https://helm.sh/docs/topics/chart_best_practices/)
- [Kubernetes Deployment Strategies](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/)
- [Trivy Security Scanner](https://aquasecurity.github.io/trivy/)
