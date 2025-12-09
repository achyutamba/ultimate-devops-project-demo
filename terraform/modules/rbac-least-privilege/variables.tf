variable "aks_acr_assignments" {
  type = map(object({
    principal_id = string
    role         = string
    scope        = string
  }))
  description = "Map of AKS/ACR role assignments."
}

variable "pipeline_assignments" {
  type = map(object({
    principal_id = string
    role         = string
    scope        = string
  }))
  description = "Map of pipeline role assignments."
}
