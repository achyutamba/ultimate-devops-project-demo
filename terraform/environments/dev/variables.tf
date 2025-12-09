variable "project_name" {
  description = "Project name"
  type        = string
  default     = "otel-demo"
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "eastus"
}

variable "alert_email" {
  description = "Email for monitoring alerts"
  type        = string
  default     = "devops@example.com"
}
