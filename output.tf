# Create Outputs
# 1. Resource Group Location
# 2. Resource Group Id
# 3. Resource Group Name

# Resource Group Outputs
# output "location" {
#   value = azurerm_resource_group.aks_rg.location
# }

# output "resource_group_id" {
#   value = azurerm_resource_group.aks_rg.id
# }

# output "resource_group_name" {
#   value = azurerm_resource_group.aks_rg.name
# }

# Azure AKS Versions Datasource
output "versions" {
  value = data.azurerm_kubernetes_service_versions.main.versions
}

output "latest_version" {
  value = data.azurerm_kubernetes_service_versions.main.latest_version
}

# Azure AD Group Object Id
output "azure_ad_group_id" {
  value = azuread_group.main[*].id
}
output "azure_ad_group_objectid" {
  value = azuread_group.main[*].object_id
}


# Azure AKS Outputs

output "aks_cluster_id" {
  value = azurerm_kubernetes_cluster.main.id
}

output "aks_cluster_name" {
  value = azurerm_kubernetes_cluster.main.name
}

output "aks_cluster_kubernetes_version" {
  value = azurerm_kubernetes_cluster.main.kubernetes_version
}


# Kubernetes Files Output
output "client_certificate" {
  value     = azurerm_kubernetes_cluster.main.kube_config.0.client_certificate
  sensitive = true
}

output "default_node_pool_rg_name" {
  value = "${local.names.aks}-nrg"
}
output "kube_config" {
  value = azurerm_kubernetes_cluster.main.kube_config_raw

  sensitive = true
}