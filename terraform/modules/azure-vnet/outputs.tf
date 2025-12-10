output "resource_group_name" {
  description = "Name of the resource group"
  value       = azurerm_resource_group.main.name
}

output "resource_group_id" {
  description = "ID of the resource group"
  value       = azurerm_resource_group.main.id
}

output "vnet_id" {
  description = "ID of the virtual network"
  value       = azurerm_virtual_network.main.id
}

output "vnet_name" {
  description = "Name of the virtual network"
  value       = azurerm_virtual_network.main.name
}

output "aks_subnet_id" {
  description = "ID of the AKS subnet"
  value       = azurerm_subnet.aks.id
}

output "appgw_subnet_id" {
  description = "ID of the Application Gateway subnet"
  value       = azurerm_subnet.appgw.id
}

output "database_subnet_id" {
  description = "ID of the database subnet"
  value       = azurerm_subnet.database.id
}

output "private_dns_zone_id" {
  description = "ID of the private DNS zone for PostgreSQL"
  value       = azurerm_private_dns_zone.postgres.id
}

# Application Gateway outputs - disabled (not used in dev)
# output "appgw_public_ip_id" {
#   description = "ID of the Application Gateway public IP"
#   value       = azurerm_public_ip.appgw.id
# }

# output "appgw_public_ip_address" {
#   description = "IP address of the Application Gateway"
#   value       = azurerm_public_ip.appgw.ip_address
# }

output "location" {
  description = "Azure region"
  value       = azurerm_resource_group.main.location
}
