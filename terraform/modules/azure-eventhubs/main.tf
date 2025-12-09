# Azure Event Hubs Module (Kafka-compatible)
# Used by Checkout, Accounting, and Fraud Detection services

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

# Event Hubs Namespace
resource "azurerm_eventhub_namespace" "main" {
  name                = "${var.project_name}-${var.environment}-ehns"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = var.sku
  capacity            = var.capacity
  
  # Enable Kafka for compatibility with existing services
  kafka_enabled = true
  
  # Auto-inflate for Standard/Premium tiers
  auto_inflate_enabled     = var.auto_inflate_enabled
  maximum_throughput_units = var.auto_inflate_enabled ? var.maximum_throughput_units : null
  
  # Zone redundancy for Premium
  zone_redundant = var.zone_redundant

  # Network rules
  network_rulesets {
    default_action                 = var.default_network_action
    trusted_service_access_enabled = true
    
    dynamic "virtual_network_rule" {
      for_each = var.subnet_ids
      content {
        subnet_id = virtual_network_rule.value
      }
    }
    
    dynamic "ip_rule" {
      for_each = var.ip_rules
      content {
        ip_mask = ip_rule.value
      }
    }
  }

  tags = var.tags
}

# Event Hub for Orders (used by Checkout -> Accounting)
resource "azurerm_eventhub" "orders" {
  name                = "orders"
  namespace_name      = azurerm_eventhub_namespace.main.name
  resource_group_name = var.resource_group_name
  partition_count     = var.partition_count
  message_retention   = var.message_retention
}

# Consumer group for Accounting service
resource "azurerm_eventhub_consumer_group" "accounting" {
  name                = "accounting-consumer"
  namespace_name      = azurerm_eventhub_namespace.main.name
  eventhub_name       = azurerm_eventhub.orders.name
  resource_group_name = var.resource_group_name
}

# Consumer group for Fraud Detection service
resource "azurerm_eventhub_consumer_group" "fraud_detection" {
  name                = "fraud-detection-consumer"
  namespace_name      = azurerm_eventhub_namespace.main.name
  eventhub_name       = azurerm_eventhub.orders.name
  resource_group_name = var.resource_group_name
}

# Authorization rule for producers (Checkout service)
resource "azurerm_eventhub_authorization_rule" "producer" {
  name                = "producer-auth"
  namespace_name      = azurerm_eventhub_namespace.main.name
  eventhub_name       = azurerm_eventhub.orders.name
  resource_group_name = var.resource_group_name
  listen              = false
  send                = true
  manage              = false
}

# Authorization rule for consumers (Accounting, Fraud Detection)
resource "azurerm_eventhub_authorization_rule" "consumer" {
  name                = "consumer-auth"
  namespace_name      = azurerm_eventhub_namespace.main.name
  eventhub_name       = azurerm_eventhub.orders.name
  resource_group_name = var.resource_group_name
  listen              = true
  send                = false
  manage              = false
}
