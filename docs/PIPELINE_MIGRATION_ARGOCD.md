# Pipeline Migration to Argo CD GitOps

This document provides step-by-step guidance for migrating from the existing push-based Helm deployment pipeline to a GitOps model using Argo CD.

---

## Table of Contents

1. [Overview](#overview)
2. [Architecture Changes](#architecture-changes)
3. [Pipeline Comparison](#pipeline-comparison)
4. [Migration Strategy](#migration-strategy)
5. [Implementation Steps](#implementation-steps)
6. [Rollback Plan](#rollback-plan)
7. [Validation & Testing](#validation--testing)
8. [Post-Migration Operations](#post-migration-operations)

---

## Overview

### Current State (Push-Based)
```
Code Commit → CI Pipeline → Build Images → CD Pipeline → Helm Upgrade → AKS Cluster
```

- **CI Pipeline**: Builds Docker images, pushes to ACR
- **CD Pipeline**: Directly deploys to AKS using `helm upgrade` commands
- **Manual Intervention**: Requires manual approvals between environments
- **Direct Access**: Pipeline requires cluster credentials and Helm CLI

### Target State (Pull-Based GitOps)
```
Code Commit → CI Pipeline → Build Images → Update Git Values → Argo CD Sync → AKS Cluster
```

- **CI Pipeline**: Builds images, updates Git values files with new tags
- **Argo CD**: Monitors Git repository, automatically syncs changes to cluster
- **Declarative**: All desired state stored in Git (single source of truth)
- **No Direct Access**: Pipeline doesn't need cluster credentials

---

## Architecture Changes

### Before: Traditional CI/CD
```
┌─────────────┐     ┌──────────────┐     ┌────────────┐
│   Azure     │────▶│  ACR Image   │────▶│   Azure    │
│  Pipelines  │     │   Registry   │     │  Pipelines │
│    (CI)     │     └──────────────┘     │    (CD)    │
└─────────────┘                          └──────┬─────┘
                                                 │
                                          helm upgrade
                                                 │
                                                 ▼
                                          ┌────────────┐
                                          │ AKS Cluster│
                                          └────────────┘
```

### After: GitOps with Argo CD
```
┌─────────────┐     ┌──────────────┐     ┌────────────┐
│   Azure     │────▶│  ACR Image   │     │  Git Repo  │
│  Pipelines  │     │   Registry   │     │  (Values)  │
│    (CI)     │     └──────────────┘     └──────┬─────┘
└──────┬──────┘                                  │
       │                                         │
       └──────────git commit────────────────────┘
                                                 │
                                                 │ watches
                                                 ▼
                                          ┌────────────┐
                                          │  Argo CD   │
                                          │ Controller │
                                          └──────┬─────┘
                                                 │
                                          syncs from git
                                                 │
                                                 ▼
                                          ┌────────────┐
                                          │ AKS Cluster│
                                          └────────────┘
```

---

## Pipeline Comparison

### Old Pipeline (`cd-pipeline.yml`)
```yaml
stages:
  - stage: DeployDev
    jobs:
      - deployment: Deploy
        steps:
          - task: HelmDeploy@0
            inputs:
              command: 'upgrade'
              chartPath: 'helm-charts/otel-demo'
              releaseName: 'otel-demo'
              namespace: 'otel-demo-dev'
              arguments: '--values values-dev.yaml'
```

**Issues:**
- Requires cluster credentials in pipeline
- Pipeline has write access to production
- No Git-based audit trail for deployed state
- Drift can occur (manual kubectl changes)
- Difficult to rollback (need to re-run pipeline)

### New Pipeline (`ci-pipeline-gitops.yml`)
```yaml
stages:
  - stage: BuildAndScan
    jobs:
      - job: BuildImages
        steps:
          - task: Docker@2  # Build and push images
          
  - stage: UpdateGitDev
    jobs:
      - job: UpdateValuesFile
        steps:
          - script: |
              yq eval ".frontend.image = \"$ACR_LOGIN_SERVER/frontend:$NEW_TAG\"" -i values-dev.yaml
              git commit -am "chore: update dev image tags"
              git push
```

**Benefits:**
- No cluster credentials needed in pipeline
- All changes audited in Git history
- Argo CD enforces desired state (prevents drift)
- Easy rollback (git revert)
- Declarative deployment model

---

## Migration Strategy

### Phase 1: Parallel Run (Week 1-2)
- Install Argo CD in production clusters
- Create Application CRDs alongside existing deployments
- Keep old CD pipeline active
- Monitor Argo CD sync status

### Phase 2: Validation (Week 3)
- Deploy new features via Git commit (Argo CD path)
- Verify observability, metrics, logs
- Test rollback procedures
- Run smoke tests

### Phase 3: Cutover (Week 4)
- Disable old CD pipeline stages
- Enable new GitOps pipeline
- Document new deployment process
- Train team on Argo CD operations

### Phase 4: Cleanup (Week 5+)
- Remove old CD pipeline file
- Revoke pipeline service principal cluster access
- Archive old runbooks
- Update documentation

---

## Implementation Steps

### Step 1: Install Argo CD (Production Setup)

```bash
# Apply production Argo CD manifests
kubectl create namespace argocd
kubectl apply -n argocd -f kubernetes/argocd/production/argocd-ha-deployments.yaml
kubectl apply -n argocd -f kubernetes/argocd/production/argocd-redis-ha.yaml
kubectl apply -n argocd -f kubernetes/argocd/production/argocd-rbac.yaml
kubectl apply -n argocd -f kubernetes/argocd/production/argocd-pdb.yaml
kubectl apply -n argocd -f kubernetes/argocd/production/argocd-networkpolicy.yaml
kubectl apply -n argocd -f kubernetes/argocd/production/argocd-servicemonitor.yaml
kubectl apply -n argocd -f kubernetes/argocd/production/argocd-keyvault-csi.yaml
kubectl apply -n argocd -f kubernetes/argocd/production/argocd-ingress.yaml

# Wait for pods to be ready
kubectl wait --for=condition=Ready pods --all -n argocd --timeout=300s

# Retrieve admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

### Step 2: Create Argo CD Applications

```bash
# Apply Application CRDs for all environments
kubectl apply -f kubernetes/argocd/apps/otel-demo-dev.yaml
kubectl apply -f kubernetes/argocd/apps/otel-demo-staging.yaml
kubectl apply -f kubernetes/argocd/apps/otel-demo-prod.yaml

# Verify applications are created
argocd app list
```

### Step 3: Configure Azure Pipeline Service Connection

```bash
# Grant pipeline identity permission to commit to repo
# In Azure DevOps:
# Project Settings → Repositories → Security
# Add "Build Service" account with "Contribute" permission

# Or use Azure CLI for Azure Repos
az devops security permission update \
  --namespace-id 2e9eb7ed-3c0a-47d4-87c1-0ffdd275fd87 \
  --subject "Build Service" \
  --token "repoV2/<PROJECT_ID>/<REPO_ID>" \
  --allow-bit 4  # Allow contribute
```

### Step 4: Update Pipeline Variable Groups

```bash
# Add new variables to 'otel-demo-common' variable group
az pipelines variable-group variable create \
  --group-id <GROUP_ID> \
  --name GIT_USER_EMAIL \
  --value "azure-pipelines@example.com"

az pipelines variable-group variable create \
  --group-id <GROUP_ID> \
  --name GIT_USER_NAME \
  --value "Azure Pipelines Bot"
```

### Step 5: Enable New Pipeline

```bash
# In Azure DevOps UI:
# 1. Pipelines → Create Pipeline → Existing Azure Pipelines YAML file
# 2. Select: azure-pipelines/ci-pipeline-gitops.yml
# 3. Save and run

# Monitor first run
az pipelines runs list --pipeline-ids <PIPELINE_ID> --top 1
```

### Step 6: Configure Azure AD SSO (Optional but Recommended)

Follow the Azure AD configuration section in `docs/GITOPS_ARGOCD.md`:

1. Register Argo CD as an Azure AD app
2. Configure redirect URIs
3. Update `argocd-rbac.yaml` with tenant ID
4. Apply RBAC ConfigMap
5. Test SSO login

### Step 7: Verify Argo CD Sync

```bash
# Check sync status
argocd app get otel-demo-dev
argocd app get otel-demo-staging
argocd app get otel-demo-prod

# Verify all resources are healthy
kubectl get all -n otel-demo-dev
kubectl get all -n otel-demo-staging
kubectl get all -n otel-demo-prod
```

### Step 8: Test GitOps Workflow

```bash
# Make a test change to dev values
git checkout -b test/gitops-workflow
sed -i 's/replicas: 2/replicas: 3/' helm-charts/otel-demo/values-dev.yaml
git commit -am "test: increase frontend replicas"
git push origin test/gitops-workflow

# Create PR, merge to main

# Watch Argo CD sync (should happen within 3 minutes)
argocd app wait otel-demo-dev --timeout 300

# Verify replica count changed
kubectl get deployment -n otel-demo-dev -l app=frontend -o jsonpath='{.items[0].spec.replicas}'
```

### Step 9: Disable Old CD Pipeline

```bash
# In Azure DevOps:
# 1. Pipelines → cd-pipeline.yml → Edit
# 2. Add to top of file:
#    trigger: none
#    pr: none
# 3. Save (don't run)

# Or disable via CLI
az pipelines update --id <OLD_PIPELINE_ID> --enabled false
```

### Step 10: Document New Workflow

Update team documentation:
- Deployment process now uses Git commits
- Argo CD UI access instructions
- Rollback procedure (git revert)
- Emergency manual sync procedure

---

## Rollback Plan

### Emergency Rollback to Old Pipeline

If critical issues occur during migration:

```bash
# 1. Re-enable old CD pipeline
az pipelines update --id <OLD_PIPELINE_ID> --enabled true

# 2. Run old pipeline to redeploy last known good state
az pipelines run --id <OLD_PIPELINE_ID>

# 3. Suspend Argo CD Application (prevent fighting)
argocd app patch otel-demo-dev --patch '{"spec":{"syncPolicy":null}}'

# 4. Investigate issues, fix, and retry migration
```

### Application-Level Rollback

For application issues after GitOps deployment:

```bash
# Option 1: Git revert (recommended)
git revert <COMMIT_SHA>
git push origin main
# Argo CD will auto-sync the revert

# Option 2: Argo CD rollback to previous revision
argocd app rollback otel-demo-dev <REVISION_ID>

# Option 3: Manual kubectl (emergency only)
kubectl rollout undo deployment/frontend -n otel-demo-dev
```

---

## Validation & Testing

### Pre-Migration Checklist

- [ ] Argo CD installed and accessible
- [ ] Applications created for all environments
- [ ] Pipeline has Git commit permissions
- [ ] Variable groups updated
- [ ] Team trained on Argo CD UI
- [ ] Rollback plan documented and tested
- [ ] Monitoring/alerting configured for Argo CD

### Post-Migration Validation

```bash
# 1. Verify all apps are synced
argocd app list | grep -E 'Synced.*Healthy'

# 2. Check resource health
kubectl get pods --all-namespaces | grep -v Running

# 3. Verify metrics collection
kubectl port-forward -n argocd svc/argocd-metrics 8082:8082
curl http://localhost:8082/metrics | grep argocd_app_sync_total

# 4. Test deployment via Git commit
git commit --allow-empty -m "test: trigger sync"
git push origin main
argocd app wait otel-demo-dev --timeout 300

# 5. Verify observability stack
kubectl get servicemonitor -n argocd
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server --tail=50
```

### Smoke Tests

```bash
# Run existing smoke test suite
cd test/tracetesting
./run-tests.sh

# Check application endpoints
for env in dev staging prod; do
  echo "Testing $env environment..."
  curl -sSf https://otel-demo-$env.example.com/health || echo "FAILED: $env"
done

# Verify metrics/traces/logs
# (Use existing observability validation from cd-pipeline.yml)
```

---

## Post-Migration Operations

### Daily Operations

**Deploy New Version:**
1. CI pipeline builds image with tag `<BUILD_ID>`
2. CI pipeline commits updated tag to `values-<env>.yaml`
3. Argo CD detects change within 3 minutes
4. Argo CD syncs new image to cluster
5. Monitor via Argo CD UI or CLI

**Rollback:**
```bash
# Find previous revision
argocd app history otel-demo-prod

# Rollback
argocd app rollback otel-demo-prod <REVISION>

# Or via Git revert
git log --oneline helm-charts/otel-demo/values-production.yaml
git revert <COMMIT_SHA>
git push origin main
```

**Manual Sync (if auto-sync disabled):**
```bash
argocd app sync otel-demo-prod --prune
```

**Check Sync Status:**
```bash
argocd app get otel-demo-prod
argocd app diff otel-demo-prod  # Show pending changes
```

### Monitoring & Alerting

**Argo CD Metrics:**
- `argocd_app_sync_total`: Total sync operations
- `argocd_app_sync_status`: Current sync status (0=Synced, 1=OutOfSync)
- `argocd_app_health_status`: Application health (0=Healthy, 1=Degraded, 2=Missing)

**Prometheus Alerts:**
```yaml
- alert: ArgoCDAppOutOfSync
  expr: argocd_app_sync_status{namespace="argocd"} == 1
  for: 10m
  annotations:
    summary: "Argo CD app {{ $labels.name }} out of sync"

- alert: ArgoCDAppUnhealthy
  expr: argocd_app_health_status{namespace="argocd"} > 0
  for: 5m
  annotations:
    summary: "Argo CD app {{ $labels.name }} unhealthy"
```

### Troubleshooting

**Sync Stuck:**
```bash
# Check application events
argocd app get otel-demo-dev --show-operation

# Check controller logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller --tail=100

# Force hard refresh
argocd app sync otel-demo-dev --force --replace
```

**Git Commit Failures in Pipeline:**
```bash
# Check pipeline logs
az pipelines runs show --id <RUN_ID> --open

# Verify Git permissions
az devops security permission show \
  --namespace-id 2e9eb7ed-3c0a-47d4-87c1-0ffdd275fd87 \
  --subject "Build Service"

# Manual commit test
git clone <REPO_URL>
echo "test" >> test.txt
git commit -am "test"
git push origin main
```

**Argo CD Login Issues:**
```bash
# Reset admin password
argocd admin initial-password -n argocd

# Check SSO configuration
kubectl get configmap argocd-cm -n argocd -o yaml
```

---

## Summary

### Key Changes

| Aspect | Before | After |
|--------|--------|-------|
| Deployment Method | Push (Helm upgrade) | Pull (Git sync) |
| Pipeline Responsibility | Build + Deploy | Build + Update Git |
| Cluster Access | Pipeline | Argo CD only |
| Desired State Storage | Pipeline variables | Git repository |
| Rollback | Re-run pipeline | Git revert |
| Drift Detection | Manual | Automatic |
| Audit Trail | Pipeline logs | Git history |

### Benefits Realized

✅ **Security**: Pipeline no longer needs cluster credentials  
✅ **Auditability**: All changes tracked in Git  
✅ **Reliability**: Automatic drift correction  
✅ **Simplicity**: Declarative deployment model  
✅ **Velocity**: Faster rollbacks via Git  
✅ **Visibility**: Centralized view of all deployments  

### Next Steps

1. Monitor Argo CD sync metrics for 2 weeks
2. Train team on GitOps workflows
3. Implement Argo CD notifications (Slack/Teams)
4. Set up automated image update tools (Renovate, Argo CD Image Updater)
5. Expand GitOps to infrastructure (Terraform with Argo CD ApplicationSets)

---

## References

- [Argo CD Documentation](https://argo-cd.readthedocs.io/)
- [GitOps Principles](https://opengitops.dev/)
- [Azure DevOps Git Permissions](https://docs.microsoft.com/en-us/azure/devops/repos/git/set-git-repository-permissions)
- [Helm Values Files Best Practices](https://helm.sh/docs/chart_best_practices/values/)
- Project-specific: `docs/GITOPS_ARGOCD.md`
