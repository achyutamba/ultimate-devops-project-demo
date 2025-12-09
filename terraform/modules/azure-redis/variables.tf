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

variable "sku_name" {
  description = "Redis SKU: Basic, Standard, or Premium"
  type        = string
  default     = "Standard"
}

variable "family" {
  description = "Redis family: C (Basic/Standard) or P (Premium)"
  type        = string
  default     = "C"
}

variable "capacity" {
  description = "Redis cache capacity (0-6 for C/P family)"
  type        = number
  default     = 1
}

variable "maxmemory_reserved" {
  description = "Maxmemory reserved (MB)"
  type        = number
  default     = 50
}

variable "maxfragmentationmemory_reserved" {
  description = "Max fragmentation memory reserved (MB)"
  type        = number
  default     = 50
}

variable "maxmemory_policy" {
  description = "Eviction policy when maxmemory is reached"
  type        = string
  default     = "allkeys-lru"
}

variable "enable_persistence" {
  description = "Enable RDB persistence (Premium only)"
  type        = bool
  default     = false
}

variable "backup_frequency" {
  description = "Backup frequency in minutes (15, 30, 60, 360, 720, 1440)"
  type        = number
  default     = 60
}

variable "backup_storage_connection_string" {
  description = "Storage account connection string for backups"
  type        = string
  default     = ""
  sensitive   = true
}

variable "enable_zone_redundancy" {
  description = "Enable zone redundancy (Premium only)"
  type        = bool
  default     = false
}

variable "enable_private_endpoint" {
  description = "Enable private endpoint for Redis"
  type        = bool
  default     = false
}

variable "subnet_id" {
  description = "Subnet ID for private endpoint"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
