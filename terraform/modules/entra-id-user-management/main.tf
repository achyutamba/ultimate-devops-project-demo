resource "azuread_user" "users" {
  for_each = { for u in var.users : u.user_principal_name => u }

  user_principal_name = each.value.user_principal_name
  display_name        = each.value.display_name
  password            = each.value.password
  force_password_change = false
}

resource "azuread_group" "groups" {
  for_each = { for g in var.groups : g.display_name => g }

  display_name = each.value.display_name
  description  = each.value.description
}
