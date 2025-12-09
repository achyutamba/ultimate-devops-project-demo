output "namespace_id" {
  description = "ID of the Event Hubs namespace"
  value       = azurerm_eventhub_namespace.main.id
}

output "namespace_name" {
  description = "Name of the Event Hubs namespace"
  value       = azurerm_eventhub_namespace.main.name
}

output "kafka_endpoint" {
  description = "Kafka endpoint for Event Hubs"
  value       = "${azurerm_eventhub_namespace.main.name}.servicebus.windows.net:9093"
}

output "orders_eventhub_name" {
  description = "Name of the orders Event Hub"
  value       = azurerm_eventhub.orders.name
}

output "producer_connection_string" {
  description = "Connection string for producers"
  value       = azurerm_eventhub_authorization_rule.producer.primary_connection_string
  sensitive   = true
}

output "consumer_connection_string" {
  description = "Connection string for consumers"
  value       = azurerm_eventhub_authorization_rule.consumer.primary_connection_string
  sensitive   = true
}

output "accounting_consumer_group" {
  description = "Name of accounting consumer group"
  value       = azurerm_eventhub_consumer_group.accounting.name
}

output "fraud_detection_consumer_group" {
  description = "Name of fraud detection consumer group"
  value       = azurerm_eventhub_consumer_group.fraud_detection.name
}
