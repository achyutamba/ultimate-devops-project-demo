output "user_ids" {
  description = "List of created user IDs."
  value = [for u in azuread_user.users : u.id]
}

output "group_ids" {
  description = "List of created group IDs."
  value = [for g in azuread_group.groups : g.id]
}
