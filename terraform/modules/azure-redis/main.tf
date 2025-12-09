# Azure Cache for Redis Module
# Used by Cart service for session storage

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

# Azure Cache for Redis
resource "azurerm_redis_cache" "main" {
  name                = "${var.project_name}-${var.environment}-redis"
  location            = var.location
  resource_group_name = var.resource_group_name
  capacity            = var.capacity
  family              = var.family
  sku_name            = var.sku_name
  enable_non_ssl_port = false
  minimum_tls_version = "1.2"
  
  redis_configuration {
    enable_authentication           = true
    maxmemory_reserved              = var.maxmemory_reserved
    maxfragmentationmemory_reserved = var.maxfragmentationmemory_reserved
    maxmemory_policy                = var.maxmemory_policy
  }

  # Premium SKU features
  dynamic "redis_configuration" {
    for_each = var.sku_name == "Premium" ? [1] : []
    content {
      rdb_backup_enabled            = var.enable_persistence
      rdb_backup_frequency          = var.backup_frequency
      rdb_storage_connection_string = var.backup_storage_connection_string
    }
  }

  # Zone redundancy for Premium
  zones = var.sku_name == "Premium" && var.enable_zone_redundancy ? ["1", "2", "3"] : null

  tags = var.tags
}

# Private endpoint for Redis (optional, for enhanced security)
resource "azurerm_private_endpoint" "redis" {
  count               = var.enable_private_endpoint ? 1 : 0
  name                = "${var.project_name}-${var.environment}-redis-pe"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.subnet_id

  private_service_connection {
    name                           = "${var.project_name}-${var.environment}-redis-psc"
    private_connection_resource_id = azurerm_redis_cache.main.id
    is_manual_connection           = false
    subresource_names              = ["redisCache"]
  }

  tags = var.tags
}
