variable "key_vault_name" { type = string }
variable "location" { type = string }
variable "resource_group_name" { type = string }
variable "tenant_id" { type = string }
variable "secrets" {
  type = map(string)
  description = "Map of secret names to values."
}
