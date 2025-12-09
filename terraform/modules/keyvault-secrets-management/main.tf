resource "azurerm_key_vault" "main" {
  name                = var.key_vault_name
  location            = var.location
  resource_group_name = var.resource_group_name
  tenant_id           = var.tenant_id
  sku_name            = "standard"
}

resource "azurerm_key_vault_secret" "secrets" {
  for_each = var.secrets
  name     = each.key
  value    = each.value
  key_vault_id = azurerm_key_vault.main.id
}
