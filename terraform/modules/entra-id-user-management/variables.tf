variable "users" {
  description = "List of user objects to create in Entra ID."
  type = list(object({
    user_principal_name = string
    display_name        = string
    password            = string
  }))
  default = []
}

variable "groups" {
  description = "List of group objects to create in Entra ID."
  type = list(object({
    display_name = string
    description  = string
  }))
  default = []
}
