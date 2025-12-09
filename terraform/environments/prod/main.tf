# Production Environment - Complete Azure Infrastructure
# OpenTelemetry Demo on AKS

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
    key                  = "prod.terraform.tfstate"
  }
}

provider "azurerm" {
  features {}
}

resource "random_password" "postgres" {
  length  = 24
  special = true
}

locals {
  project_name = var.project_name
  environment  = "prod"
  location     = var.location
  common_tags = {
    Project     = local.project_name
    Environment = local.environment
    ManagedBy   = "Terraform"
    CostCenter  = "DevOps"
  }
}

module "vnet" {
  source = "../../modules/azure-vnet"
  project_name = local.project_name
  environment = local.environment
  location = local.location
  vnet_address_space = "10.2.0.0/16"
  aks_subnet_address_prefix = "10.2.1.0/24"
  appgw_subnet_address_prefix = "10.2.2.0/24"
  database_subnet_address_prefix = "10.2.3.0/24"
  tags = local.common_tags
}

module "monitor" {
  source = "../../modules/azure-monitor"
  project_name = local.project_name
  environment = local.environment
  location = local.location
  resource_group_name = module.vnet.resource_group_name
  aks_cluster_id = module.aks.cluster_id
  alert_email = var.alert_email
  retention_in_days = 30
  tags = local.common_tags
  depends_on = [module.vnet]
}

module "acr" {
  source = "../../modules/azure-acr"
  project_name = local.project_name
  environment = local.environment
  location = local.location
  resource_group_name = module.vnet.resource_group_name
  sku = "Premium"
  admin_enabled = false
  enable_retention_policy = true
  retention_days = 30
  log_analytics_workspace_id = module.monitor.log_analytics_workspace_id
  tags = local.common_tags
  depends_on = [module.vnet]
}

module "aks" {
  source = "../../modules/azure-aks"
  project_name = local.project_name
  environment = local.environment
  location = local.location
  resource_group_name = module.vnet.resource_group_name
  subnet_id = module.vnet.aks_subnet_id
  vnet_id = module.vnet.vnet_id
  kubernetes_version = "1.28"
  system_node_count = 5
  system_node_size = "Standard_D4s_v3"
  enable_auto_scaling = true
  min_node_count = 5
  max_node_count = 10
  create_user_node_pool = true
  user_node_count = 3
  user_node_size = "Standard_D4s_v3"
  log_analytics_workspace_id = module.monitor.log_analytics_workspace_id
  acr_id = module.acr.acr_id
  tags = local.common_tags
  depends_on = [module.vnet, module.monitor, module.acr]
}

module "postgres" {
  source = "../../modules/azure-postgres"
  project_name = local.project_name
  environment = local.environment
  location = local.location
  resource_group_name = module.vnet.resource_group_name
  subnet_id = module.vnet.database_subnet_id
  private_dns_zone_id = module.vnet.private_dns_zone_id
  postgres_version = "15"
  admin_username = "oteldbadmin"
  admin_password = random_password.postgres.result
  database_name = "oteldb"
  sku_name = "GP_Standard_D4s_v3"
  storage_mb = 131072
  backup_retention_days = 30
  geo_redundant_backup_enabled = true
  high_availability_mode = "ZoneRedundant"
  tags = local.common_tags
  depends_on = [module.vnet]
}

module "redis" {
  source = "../../modules/azure-redis"
  project_name = local.project_name
  environment = local.environment
  location = local.location
  resource_group_name = module.vnet.resource_group_name
  sku_name = "Premium"
  family = "P"
  capacity = 2
  tags = local.common_tags
  depends_on = [module.vnet]
}

module "eventhubs" {
  source = "../../modules/azure-eventhubs"
  project_name = local.project_name
  environment = local.environment
  location = local.location
  resource_group_name = module.vnet.resource_group_name
  sku = "Premium"
  capacity = 4
  partition_count = 8
  message_retention = 7
  tags = local.common_tags
  depends_on = [module.vnet]
}

resource "azurerm_key_vault" "main" {
  name = "${local.project_name}-${local.environment}-kv"
  location = local.location
  resource_group_name = module.vnet.resource_group_name
  tenant_id = data.azurerm_client_config.current.tenant_id
  sku_name = "premium"
  soft_delete_retention_days = 30
  purge_protection_enabled = true
  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id
    secret_permissions = ["Get", "List", "Set", "Delete", "Purge", "Recover"]
  }
  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = module.aks.kubelet_identity_object_id
    secret_permissions = ["Get", "List"]
  }
  tags = local.common_tags
}

resource "azurerm_key_vault_secret" "postgres_password" {
  name = "postgres-admin-password"
  value = random_password.postgres.result
  key_vault_id = azurerm_key_vault.main.id
}

resource "azurerm_key_vault_secret" "postgres_connection_string" {
  name = "postgres-connection-string"
  value = "${module.postgres.connection_string};Password=${random_password.postgres.result}"
  key_vault_id = azurerm_key_vault.main.id
}

resource "azurerm_key_vault_secret" "redis_connection_string" {
  name = "redis-connection-string"
  value = module.redis.redis_connection_string
  key_vault_id = azurerm_key_vault.main.id
}

resource "azurerm_key_vault_secret" "eventhubs_connection_string" {
  name = "eventhubs-producer-connection-string"
  value = module.eventhubs.producer_connection_string
  key_vault_id = azurerm_key_vault.main.id
}

data "azurerm_client_config" "current" {}
