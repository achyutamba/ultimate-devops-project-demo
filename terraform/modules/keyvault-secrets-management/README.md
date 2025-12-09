# Azure Key Vault Secrets Management Module

This module provisions an Azure Key Vault and stores secrets.

## Example Usage
```
module "keyvault_secrets" {
  source              = "./modules/keyvault-secrets-management"
  key_vault_name      = "mykvdemo"
  location            = "East US"
  resource_group_name = "demo-rg"
  tenant_id           = "<tenant_id>"
  secrets = {
    db-password = "supersecret123"
    api-key     = "apikeyvalue"
  }
}
```

## Inputs
- `key_vault_name`: Name of the Key Vault
- `location`: Azure region
- `resource_group_name`: Resource group
- `tenant_id`: Azure tenant
- `secrets`: Map of secret names to values

## Outputs
- `key_vault_id`: Key Vault resource ID
- `secret_ids`: Map of secret names to secret resource IDs
