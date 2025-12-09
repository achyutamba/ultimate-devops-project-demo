# Entra ID User Management Terraform Module

This module provisions users and groups in Microsoft Entra ID (Azure AD).

## Usage Example

```
module "entra_id_user_management" {
  source = "./modules/entra-id-user-management"

  users = [
    {
      user_principal_name = "alice@example.com"
      display_name        = "Alice Example"
      password            = "P@ssw0rd123!"
    },
    {
      user_principal_name = "bob@example.com"
      display_name        = "Bob Example"
      password            = "P@ssw0rd456!"
    }
  ]

  groups = [
    {
      display_name = "Developers"
      description  = "Dev team"
    },
    {
      display_name = "Admins"
      description  = "Admin team"
    }
  ]
}
```

## Required Providers
- AzureAD (Entra ID)

## Inputs
- `users`: List of user objects
- `groups`: List of group objects

## Outputs
- `user_ids`: List of created user IDs
- `group_ids`: List of created group IDs
