variable "project_name" {
  description = "Project name"
  type        = string
  default     = "otel-demo"
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "westus2"
}

variable "alert_email" {
  description = "Email for monitoring alerts"
  type        = string
  default     = "devops@example.com"
}
