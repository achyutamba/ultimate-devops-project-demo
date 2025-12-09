# Resource Group
output "resource_group_name" {
  description = "Name of the resource group"
  value       = module.vnet.resource_group_name
}

# AKS
output "aks_cluster_name" {
  description = "Name of the AKS cluster"
  value       = module.aks.cluster_name
}

output "aks_cluster_fqdn" {
  description = "FQDN of the AKS cluster"
  value       = module.aks.cluster_fqdn
}

output "aks_get_credentials_command" {
  description = "Command to get AKS credentials"
  value       = "az aks get-credentials --resource-group ${module.vnet.resource_group_name} --name ${module.aks.cluster_name}"
}

# ACR
output "acr_login_server" {
  description = "ACR login server URL"
  value       = module.acr.acr_login_server
}

output "acr_login_command" {
  description = "Command to login to ACR"
  value       = "az acr login --name ${module.acr.acr_name}"
}

# PostgreSQL
output "postgres_fqdn" {
  description = "PostgreSQL server FQDN"
  value       = module.postgres.server_fqdn
}

output "postgres_database_name" {
  description = "PostgreSQL database name"
  value       = module.postgres.database_name
}

# Redis
output "redis_hostname" {
  description = "Redis hostname"
  value       = module.redis.redis_hostname
}

output "redis_port" {
  description = "Redis SSL port"
  value       = module.redis.redis_ssl_port
}

# Event Hubs
output "eventhubs_kafka_endpoint" {
  description = "Event Hubs Kafka endpoint"
  value       = module.eventhubs.kafka_endpoint
}

output "eventhubs_namespace" {
  description = "Event Hubs namespace"
  value       = module.eventhubs.namespace_name
}

# Monitoring
output "log_analytics_workspace_id" {
  description = "Log Analytics Workspace ID"
  value       = module.monitor.workspace_id
}

output "application_insights_name" {
  description = "Application Insights name"
  value       = module.monitor.application_insights_name
}

# Key Vault
output "key_vault_name" {
  description = "Key Vault name"
  value       = azurerm_key_vault.main.name
}

output "key_vault_uri" {
  description = "Key Vault URI"
  value       = azurerm_key_vault.main.vault_uri
}

# Quick Start Commands
output "quick_start_commands" {
  description = "Commands to get started"
  value = <<-EOT
    # Get AKS credentials
    az aks get-credentials --resource-group ${module.vnet.resource_group_name} --name ${module.aks.cluster_name}
    
    # Login to ACR
    az acr login --name ${module.acr.acr_name}
    
    # View Key Vault secrets
    az keyvault secret list --vault-name ${azurerm_key_vault.main.name}
    
    # Get PostgreSQL connection details
    az keyvault secret show --vault-name ${azurerm_key_vault.main.name} --name postgres-connection-string --query value -o tsv
  EOT
}
