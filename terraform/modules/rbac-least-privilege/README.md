# RBAC Least Privilege Module

This module assigns roles to AKS, ACR, and pipeline identities with least privilege.

## Example Usage
```
module "rbac_least_privilege" {
  source = "./modules/rbac-least-privilege"
  aks_acr_assignments = {
    aks1 = {
      principal_id = "<aks_sp_id>"
      role         = "AcrPull"
      scope        = "<acr_resource_id>"
    }
  }
  pipeline_assignments = {
    pipeline1 = {
      principal_id = "<pipeline_sp_id>"
      role         = "Contributor"
      scope        = "<resource_group_id>"
    }
  }
}
```

## Inputs
- `aks_acr_assignments`: Map of AKS/ACR role assignments
- `pipeline_assignments`: Map of pipeline role assignments
