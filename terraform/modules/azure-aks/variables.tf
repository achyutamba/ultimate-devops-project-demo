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

variable "subnet_id" {
  description = "ID of the subnet for AKS"
  type        = string
}

variable "vnet_id" {
  description = "ID of the virtual network"
  type        = string
}

variable "kubernetes_version" {
  description = "Kubernetes version"
  type        = string
  default     = "1.28"
}

variable "system_node_count" {
  description = "Number of nodes in system pool"
  type        = number
  default     = 2
}

variable "system_node_size" {
  description = "VM size for system nodes"
  type        = string
  default     = "Standard_D2s_v3"
}

variable "enable_auto_scaling" {
  description = "Enable auto-scaling for node pools"
  type        = bool
  default     = true
}

variable "min_node_count" {
  description = "Minimum node count for system pool"
  type        = number
  default     = 2
}

variable "max_node_count" {
  description = "Maximum node count for system pool"
  type        = number
  default     = 5
}

variable "create_user_node_pool" {
  description = "Create separate user node pool"
  type        = bool
  default     = true
}

variable "user_node_count" {
  description = "Number of nodes in user pool"
  type        = number
  default     = 2
}

variable "user_node_size" {
  description = "VM size for user nodes"
  type        = string
  default     = "Standard_D2s_v3"
}

variable "user_min_node_count" {
  description = "Minimum node count for user pool"
  type        = number
  default     = 2
}

variable "user_max_node_count" {
  description = "Maximum node count for user pool"
  type        = number
  default     = 10
}

variable "service_cidr" {
  description = "CIDR for Kubernetes services"
  type        = string
  default     = "10.1.0.0/16"
}

variable "dns_service_ip" {
  description = "IP address for Kubernetes DNS service"
  type        = string
  default     = "10.1.0.10"
}

variable "log_analytics_workspace_id" {
  description = "ID of Log Analytics workspace for monitoring"
  type        = string
}

variable "acr_id" {
  description = "ID of Azure Container Registry"
  type        = string
}

variable "appgw_subnet_id" {
  description = "ID of Application Gateway subnet"
  type        = string
  default     = ""
}

variable "enable_application_gateway" {
  description = "Enable Application Gateway Ingress Controller"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}
