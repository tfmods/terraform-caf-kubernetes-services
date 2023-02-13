resource "azurerm_user_assigned_identity" "aks" {
  location            = data.azurerm_resource_group.main.location
  name                = local.names.aks
  resource_group_name = data.azurerm_resource_group.main.name
}

resource "azurerm_role_assignment" "aks_uai_private_dns_zone_contributor" {
  count = var.private_cluster_enabled ? 1 : 0

  scope                = var.private_dns_zone_id
  role_definition_name = "Private DNS Zone Contributor"
  principal_id         = azurerm_user_assigned_identity.aks.principal_id
}

resource "azurerm_role_assignment" "aks_uai_vnet_network_contributor" {
  count = var.private_cluster_enabled ? 1 : 0

  scope                = var.vnet_id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_user_assigned_identity.aks.principal_id
}

