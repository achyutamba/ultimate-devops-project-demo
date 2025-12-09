resource "azurerm_role_assignment" "aks_acr" {
  for_each = var.aks_acr_assignments
  principal_id         = each.value.principal_id
  role_definition_name = each.value.role
  scope                = each.value.scope
}

resource "azurerm_role_assignment" "pipeline" {
  for_each = var.pipeline_assignments
  principal_id         = each.value.principal_id
  role_definition_name = each.value.role
  scope                = each.value.scope
}
