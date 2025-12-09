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
  description = "ACR SKU: Basic, Standard, or Premium"
  type        = string
  default     = "Standard"
}

variable "admin_enabled" {
  description = "Enable admin user (not recommended for production)"
  type        = bool
  default     = false
}

variable "georeplications" {
  description = "List of geo-replication configurations (Premium only)"
  type = list(object({
    location                = string
    zone_redundancy_enabled = bool
  }))
  default = []
}

variable "enable_network_rules" {
  description = "Enable network rules (Premium only)"
  type        = bool
  default     = false
}

variable "default_network_action" {
  description = "Default network action: Allow or Deny"
  type        = string
  default     = "Allow"
}

variable "ip_rules" {
  description = "List of IP CIDR blocks allowed to access ACR"
  type        = list(string)
  default     = []
}

variable "subnet_ids" {
  description = "List of subnet IDs allowed to access ACR"
  type        = list(string)
  default     = []
}

variable "enable_content_trust" {
  description = "Enable content trust (image signing)"
  type        = bool
  default     = false
}

variable "enable_retention_policy" {
  description = "Enable retention policy for untagged manifests"
  type        = bool
  default     = true
}

variable "retention_days" {
  description = "Number of days to retain untagged manifests"
  type        = number
  default     = 7
}

variable "enable_quarantine_policy" {
  description = "Enable quarantine policy (scan images before pull)"
  type        = bool
  default     = false
}

variable "log_analytics_workspace_id" {
  description = "ID of Log Analytics workspace for diagnostics"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
