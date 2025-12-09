output "key_vault_id" {
  value = azurerm_key_vault.main.id
}
output "secret_ids" {
  value = { for k, v in azurerm_key_vault_secret.secrets : k => v.id }
}
