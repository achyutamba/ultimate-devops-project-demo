# Development Environment - Complete Azure Infrastructure
# OpenTelemetry Demo on AKS
# Deployment triggered: 2025-12-10 - Fresh deployment after cleanup

terraform {
  required_version = ">= 1.6"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }

  backend "azurerm" {
    resource_group_name  = "otel-demo-terraform-state-rg"
    storage_account_name = "oteldemotfstate"
    container_name       = "tfstate"
    key                  = "dev.terraform.tfstate"
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
    key_vault {
      purge_soft_delete_on_destroy = true
    }
  }
}

# Random password for PostgreSQL
resource "random_password" "postgres" {
  length  = 24
  special = true
}

# Local variables
locals {
  project_name = var.project_name
  environment  = "dev"
  location     = var.location
  
  common_tags = {
    Project     = local.project_name
    Environment = local.environment
    ManagedBy   = "Terraform"
    CostCenter  = "DevOps"
  }
}

# Networking Module
module "vnet" {
  source = "../../modules/azure-vnet"
  
  project_name             = local.project_name
  environment              = local.environment
  location                 = local.location
  vnet_address_space       = "10.0.0.0/16"
  aks_subnet_address_prefix = "10.0.1.0/24"
  appgw_subnet_address_prefix = "10.0.2.0/24"
  database_subnet_address_prefix = "10.0.3.0/24"
  
  tags = local.common_tags
}

# Monitoring Module (create Log Analytics workspace first, alerts after AKS)
module "monitor" {
  source = "../../modules/azure-monitor"
  
  project_name        = local.project_name
  environment         = local.environment
  location            = local.location
  resource_group_name = module.vnet.resource_group_name
  aks_cluster_id      = null  # Will be set after AKS is created
  alert_email         = var.alert_email
  retention_in_days   = 30
  
  tags = local.common_tags
  
  depends_on = [module.vnet]
}

# Azure Container Registry
module "acr" {
  source = "../../modules/azure-acr"
  
  project_name        = local.project_name
  environment         = local.environment
  location            = local.location
  resource_group_name = module.vnet.resource_group_name
  sku                 = "Standard"
  admin_enabled       = false
  enable_retention_policy = true
  retention_days      = 7
  log_analytics_workspace_id = module.monitor.log_analytics_workspace_id
  
  tags = local.common_tags
  
  depends_on = [module.vnet]
}

# AKS Cluster
module "aks" {
  source = "../../modules/azure-aks"
  
  project_name           = local.project_name
  environment            = local.environment
  location               = local.location
  resource_group_name    = module.vnet.resource_group_name
  subnet_id              = module.vnet.aks_subnet_id
  vnet_id                = module.vnet.vnet_id
  kubernetes_version     = "1.32.9"
  
  # Node pools
  system_node_count      = 2
  system_node_size       = "Standard_B2s"
  enable_auto_scaling    = true
  min_node_count         = 2
  max_node_count         = 4
  
  create_user_node_pool  = false  # Single node pool for dev
  
  # Monitoring
  log_analytics_workspace_id = module.monitor.log_analytics_workspace_id
  
  # ACR integration
  acr_id                 = module.acr.acr_id
  
  tags = local.common_tags
  
  depends_on = [module.vnet, module.monitor, module.acr]
}

# PostgreSQL Database
module "postgres" {
  source = "../../modules/azure-postgres"
  
  project_name        = local.project_name
  environment         = local.environment
  location            = local.location
  resource_group_name = module.vnet.resource_group_name
  subnet_id           = module.vnet.database_subnet_id
  private_dns_zone_id = module.vnet.private_dns_zone_id
  
  postgres_version    = "15"
  admin_username      = "oteldbadmin"
  admin_password      = random_password.postgres.result
  database_name       = "oteldb"
  
  # Dev SKU (Burstable)
  sku_name            = "B_Standard_B1ms"
  storage_mb          = 32768  # 32 GB
  backup_retention_days = 7
  geo_redundant_backup_enabled = false
  high_availability_mode = "Disabled"
  
  tags = local.common_tags
  
  depends_on = [module.vnet]
}

# Redis Cache
module "redis" {
  source = "../../modules/azure-redis"
  
  project_name        = local.project_name
  environment         = local.environment
  location            = local.location
  resource_group_name = module.vnet.resource_group_name
  
  # Dev SKU (Basic)
  sku_name            = "Basic"
  family              = "C"
  capacity            = 0
  
  tags = local.common_tags
  
  depends_on = [module.vnet]
}

# Event Hubs (Kafka-compatible)
module "eventhubs" {
  source = "../../modules/azure-eventhubs"
  
  project_name        = local.project_name
  environment         = local.environment
  location            = local.location
  resource_group_name = module.vnet.resource_group_name
  
  # Dev SKU (Standard - required for consumer groups)
  sku                  = "Standard"
  capacity             = 1
  partition_count      = 2
  message_retention    = 1
  
  tags = local.common_tags
  
  depends_on = [module.vnet]
}

# Key Vault for Secrets
resource "azurerm_key_vault" "main" {
  name                = "${local.project_name}-${local.environment}-kv"
  location            = local.location
  resource_group_name = module.vnet.resource_group_name
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"
  
  soft_delete_retention_days = 7
  purge_protection_enabled   = false
  
  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id
    
    secret_permissions = [
      "Get", "List", "Set", "Delete", "Purge", "Recover"
    ]
  }
  
  # AKS access policy
  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = module.aks.kubelet_identity_object_id
    
    secret_permissions = [
      "Get", "List"
    ]
  }
  
  tags = local.common_tags
}

# Store secrets in Key Vault
resource "azurerm_key_vault_secret" "postgres_password" {
  name         = "postgres-admin-password"
  value        = random_password.postgres.result
  key_vault_id = azurerm_key_vault.main.id
}

resource "azurerm_key_vault_secret" "postgres_connection_string" {
  name         = "postgres-connection-string"
  value        = "${module.postgres.connection_string};Password=${random_password.postgres.result}"
  key_vault_id = azurerm_key_vault.main.id
}

resource "azurerm_key_vault_secret" "redis_connection_string" {
  name         = "redis-connection-string"
  value        = module.redis.redis_connection_string
  key_vault_id = azurerm_key_vault.main.id
}

resource "azurerm_key_vault_secret" "eventhubs_connection_string" {
  name         = "eventhubs-producer-connection-string"
  value        = module.eventhubs.producer_connection_string
  key_vault_id = azurerm_key_vault.main.id
}

# Data source for current Azure context
data "azurerm_client_config" "current" {}
