# Argo CD Pipeline Integration - Quick Reference

## Pipeline Update Summary

**Your pipeline DOES need updating for Argo CD.** The setup is **partially complete**:

✅ **Already Complete:**
- Argo CD production manifests with HA, RBAC, SSO, NetworkPolicies, PDBs
- Argo CD Application CRDs for dev/staging/prod environments
- Complete documentation (`docs/GITOPS_ARGOCD.md`)

❌ **Still Needed:**
- Update CI/CD pipeline to use GitOps model (push to Git, not cluster)
- Remove old Helm deployment stages
- Configure pipeline Git commit permissions

---

## What Changed

### Old Flow (Push-Based)
```
Code → CI builds images → CD deploys with Helm → AKS
```

### New Flow (GitOps Pull-Based)
```
Code → CI builds images → CI updates Git values → Argo CD syncs → AKS
```

---

## Quick Migration Steps

### 1. Replace Your Pipeline

**Old:** `azure-pipelines/cd-pipeline.yml` (direct Helm deployment)  
**New:** `azure-pipelines/ci-pipeline-gitops.yml` (Git commit only)

```bash
# In Azure DevOps, update pipeline to use new file
# Pipeline → Edit → More actions → Triggers → YAML file path
# Change to: azure-pipelines/ci-pipeline-gitops.yml
```

### 2. Grant Git Commit Permission

```bash
# Azure DevOps → Project Settings → Repositories → Security
# Find "Build Service (<Project Name>)" account
# Grant "Contribute" permission
```

### 3. Install Argo CD (if not already)

```bash
kubectl apply -n argocd -f kubernetes/argocd/production/
```

### 4. Create Applications

```bash
kubectl apply -f kubernetes/argocd/apps/
```

### 5. Test the Flow

```bash
# Trigger pipeline (builds images, commits new tags to Git)
# Argo CD will auto-sync within 3 minutes

# Watch sync status
argocd app list
argocd app get otel-demo-dev
```

---

## Key Differences

| Aspect | Old Pipeline | New Pipeline |
|--------|--------------|--------------|
| **Image Build** | ✅ Yes | ✅ Yes |
| **Push to ACR** | ✅ Yes | ✅ Yes |
| **Helm Deploy** | ✅ Yes (direct) | ❌ No |
| **Git Commit** | ❌ No | ✅ Yes (updates values files) |
| **Who Deploys** | Pipeline | Argo CD |
| **Cluster Creds** | Pipeline needs | Only Argo CD needs |
| **Approval Gates** | Azure DevOps Environments | Azure DevOps Environments (for Git commit) |

---

## Validation Commands

```bash
# 1. Check Argo CD is running
kubectl get pods -n argocd

# 2. Check applications exist
kubectl get applications -n argocd

# 3. Check sync status
argocd app list

# 4. Watch a sync happen
argocd app sync otel-demo-dev
argocd app wait otel-demo-dev

# 5. View deployed resources
kubectl get all -n otel-demo-dev
```

---

## Rollback Plan

If issues occur:

```bash
# Option 1: Git revert (recommended)
git revert <COMMIT_SHA>
git push origin main

# Option 2: Argo CD rollback
argocd app rollback otel-demo-dev <REVISION>

# Option 3: Emergency - revert to old pipeline
# Re-enable azure-pipelines/cd-pipeline.yml
# Disable Argo CD auto-sync
argocd app patch otel-demo-dev --patch '{"spec":{"syncPolicy":null}}'
```

---

## What Gets Deployed How

### CI Pipeline Responsibilities
1. **Build** Docker images from `src/`
2. **Scan** images with Trivy
3. **Push** images to ACR with tag `$(Build.BuildId)`
4. **Update** Git files:
   - `helm-charts/otel-demo/values-dev.yaml`
   - `helm-charts/otel-demo/values-staging.yaml` (after approval)
   - `helm-charts/otel-demo/values-production.yaml` (after approval)
5. **Commit** changes with message like "chore: update dev image tags to 12345"

### Argo CD Responsibilities
1. **Watch** Git repository for changes to `helm-charts/otel-demo/`
2. **Detect** changes within 3 minutes (default refresh interval)
3. **Compare** desired state (Git) vs actual state (cluster)
4. **Sync** by running Helm internally to update cluster
5. **Prune** old resources if removed from Git
6. **Report** health status to UI/metrics

---

## Common Issues

### Issue: Pipeline can't commit to Git
**Solution:** Grant "Build Service" account "Contribute" permission on repo

### Issue: Argo CD not syncing
**Solution:** Check Application spec has `syncPolicy.automated` enabled
```yaml
syncPolicy:
  automated:
    prune: true
    selfHeal: true
```

### Issue: Image pull errors
**Solution:** Ensure ACR credentials are configured in cluster
```bash
kubectl create secret docker-registry acr-secret \
  --docker-server=$ACR_LOGIN_SERVER \
  --docker-username=$ACR_USERNAME \
  --docker-password=$ACR_PASSWORD \
  -n otel-demo-dev
```

### Issue: Sync stuck "OutOfSync"
**Solution:** Check for manual changes in cluster (Argo CD detects drift)
```bash
argocd app diff otel-demo-dev
argocd app sync otel-demo-dev --force --replace
```

---

## Documentation Links

- **Full Migration Guide:** `docs/PIPELINE_MIGRATION_ARGOCD.md`
- **Argo CD Architecture:** `docs/GITOPS_ARGOCD.md`
- **Production Manifests:** `kubernetes/argocd/production/`
- **Application CRDs:** `kubernetes/argocd/apps/`
- **New Pipeline:** `azure-pipelines/ci-pipeline-gitops.yml`

---

## Status Summary

| Component | Status | Action Required |
|-----------|--------|-----------------|
| Argo CD Manifests | ✅ Complete | None |
| Application CRDs | ✅ Complete | Apply to cluster |
| Documentation | ✅ Complete | Read and follow |
| GitOps Pipeline | ✅ Created | Switch to this pipeline |
| Old Pipeline | ⚠️ Still Active | Disable after validation |
| Git Permissions | ❌ Not Set | Grant in Azure DevOps |
| Argo CD Installation | ❓ Unknown | Check with `kubectl get pods -n argocd` |

---

## Next Actions

1. **Review** migration guide: `docs/PIPELINE_MIGRATION_ARGOCD.md`
2. **Install** Argo CD if not already: `kubectl apply -f kubernetes/argocd/production/`
3. **Grant** Git commit permission to pipeline service principal
4. **Switch** pipeline to `ci-pipeline-gitops.yml`
5. **Test** with a small change (e.g., increase replica count)
6. **Monitor** Argo CD sync status
7. **Disable** old `cd-pipeline.yml` after validation period

**Estimated Time:** 2-4 hours for initial setup, 1-2 weeks for validation before full cutover.
