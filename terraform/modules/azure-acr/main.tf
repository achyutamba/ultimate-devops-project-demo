# Azure Container Registry Module

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

# Azure Container Registry
resource "azurerm_container_registry" "main" {
  name                = replace("${var.project_name}${var.environment}acr", "-", "")
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = var.sku
  admin_enabled       = var.admin_enabled

  # Geo-replication for Premium SKU
  dynamic "georeplications" {
    for_each = var.sku == "Premium" ? var.georeplications : []
    content {
      location                = georeplications.value.location
      zone_redundancy_enabled = georeplications.value.zone_redundancy_enabled
      tags                    = var.tags
    }
  }

  # Network rules for Premium SKU
  # Network rules disabled for Standard SKU
  # dynamic "network_rule_set" {
  #   for_each = var.sku == "Premium" && var.enable_network_rules ? [1] : []
  #   content {
  #     default_action = var.default_network_action
  #   }
  # }

  # Enable content trust for image signing (Premium only)
  dynamic "trust_policy" {
    for_each = var.sku == "Premium" ? [1] : []
    content {
      enabled = var.enable_content_trust
    }
  }

  # Retention policy (Premium only)
  dynamic "retention_policy" {
    for_each = var.sku == "Premium" && var.enable_retention_policy ? [1] : []
    content {
      enabled = true
      days    = var.retention_days
    }
  }

  tags = var.tags
}

# Diagnostic settings for ACR
resource "azurerm_monitor_diagnostic_setting" "acr" {
  name                       = "${var.project_name}-${var.environment}-acr-diagnostics"
  target_resource_id         = azurerm_container_registry.main.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "ContainerRegistryRepositoryEvents"
  }

  enabled_log {
    category = "ContainerRegistryLoginEvents"
  }

  metric {
    category = "AllMetrics"
  }
}
