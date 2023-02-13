output "name" {
  value = module.aks.aks_cluster_name
}

output "id" {
  value = module.aks.aks_cluster_id
}

# output "fqdn" {
#   value = module.aks.fqdn
# }

# output "private_fqdn" {
#   value = module.aks.private_fqdn
# }

# output "kube_admin_config_raw" {
#   value = module.aks.kube_admin_config_raw
# }

output "kube_config_raw" {
  sensitive = true
  value     = module.aks.kube_config
}

output "default_node_pool_rg_name" {
  value = module.aks.default_node_pool_rg_name
}

# output "kubelet_identity" {
#   value = module.aks.kubelet_identity
# }

# output "identity" {
#   value = module.aks.identity
# }