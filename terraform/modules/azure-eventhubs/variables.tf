variable "project_name" {
  description = "Project name used for resource naming"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, staging, production)"
  type        = string
}

variable "location" {
  description = "Azure region for resources"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "sku" {
  description = "Event Hubs namespace SKU: Basic, Standard, or Premium"
  type        = string
  default     = "Standard"
}

variable "capacity" {
  description = "Throughput units (1-20 for Standard, 1-10 for Premium)"
  type        = number
  default     = 1
}

variable "auto_inflate_enabled" {
  description = "Enable auto-inflate for throughput units"
  type        = bool
  default     = false
}

variable "maximum_throughput_units" {
  description = "Maximum throughput units for auto-inflate"
  type        = number
  default     = 5
}

variable "zone_redundant" {
  description = "Enable zone redundancy"
  type        = bool
  default     = false
}

variable "partition_count" {
  description = "Number of partitions for Event Hub"
  type        = number
  default     = 4
}

variable "message_retention" {
  description = "Message retention in days (1-7 for Standard, up to 90 for Premium)"
  type        = number
  default     = 1
}

variable "default_network_action" {
  description = "Default network action: Allow or Deny"
  type        = string
  default     = "Allow"
}

variable "subnet_ids" {
  description = "List of subnet IDs allowed to access Event Hubs"
  type        = list(string)
  default     = []
}

variable "ip_rules" {
  description = "List of IP addresses/CIDR blocks allowed to access Event Hubs"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
