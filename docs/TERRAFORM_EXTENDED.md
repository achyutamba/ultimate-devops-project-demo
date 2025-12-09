# Terraform (Extended) — Modules, variables and operational notes

This extended guide expands on `TERRAFORM.md` with module-level details and pipeline integration notes.

Modules overview
- `azure-vnet`
  - Creates resource group, VNet, subnets, private DNS zones, and outputs ids used by other modules.
- `azure-monitor`
  - Creates Log Analytics workspace and connects AKS for monitoring. Exposes workspace id for AKS and ACR logging integration.
- `azure-acr`
  - Provision ACR with content retention rules and integration with AKS (pull role assignments).
- `azure-aks`
  - Creates AKS cluster and optionally node pools. Exposes kubelet identity object id and cluster id.
- `azure-postgres`
  - Configures Postgres Flexible Server. Supports private access and connection string outputs.
- `azure-redis`
  - Creates Redis cache and produces connection string output.
- `azure-eventhubs`
  - Provisions Event Hubs namespace and a default hub for producers/consumers.
- `keyvault-secrets-management`
  - (Optional) helper for storing initial secrets in Key Vault via Terraform.
- `rbac-least-privilege`
  - Creates role assignments and service principals with scoped permissions for pipelines.

Important variables and outputs
- `project_name`, `environment`, `location` — used across modules for consistent naming
- Module outputs of interest
  - `vnet.vnet_id`, `vnet.aks_subnet_id`
  - `monitor.log_analytics_workspace_id`
  - `acr.acr_id`, `acr.login_server`
  - `aks.cluster_id`, `aks.kubelet_identity_object_id`
  - `postgres.connection_string`
  - `eventhubs.producer_connection_string`

Pipeline integration
- The CD pipeline expects Terraform outputs to find resource IDs and kubeconfigs. Add `terraform output -json` in CI tasks or store outputs in pipeline variables/secrets.
- For multi-cluster deploys, ensure outputs include kubeconfig or create a short-lived kubeconfig file from `az aks get-credentials` in the pipeline.

State & collaboration
- Use the `azurerm` backend with container + blob storage. Ensure the service principal used by CI has Storage Blob Data Contributor permission on the state storage container.

Secrets and sensitive data
- Do not hard-code secrets in `.tf` files. Use `azurerm_key_vault_secret` to centrally store them, and access via Key Vault from pipelines.

Rollback & drift control
- Use `terraform plan` and store plans for review. If changes are made outside Terraform, run `terraform import` to bring resources under management.

Common terraform debug tips
- `terraform init -upgrade` to refresh provider plugins
- `TF_LOG=DEBUG terraform apply` for verbose logs (avoid in shared CI logs)

This extended doc helps operators understand how to extend modules or add new resources without breaking existing references used by the pipeline.
