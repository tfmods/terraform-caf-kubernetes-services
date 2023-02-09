data "azurerm_resource_group" "main" {
  name = var.resource_group_name
}

####     ===cC 
##  AKS - Get Last Version of Kubernetes 
####     ===cC               

data "azurerm_kubernetes_service_versions" "main" {
  location        = azurerm_resource_group.main.location
  include_preview = false
}

####     ===cC 
##  AKS - Create ssh Key for Linux Nodes 
####     ===cC               

resource "tls_private_key" "ssh" {
  count = var.admin_username == null ? 0 : 1
  algorithm = "RSA"
  rsa_bits  = 2048
}

####     ===cC 
##  AKS - Create Azure Ad Group for Azure Kubernetes Service 
####     ===cC               

resource "azuread_group" "main" {
  count = var.aad_group_name ? 1 : 0
  
  name        = format("${local.names.aad_group}-%03d", count.index + 1)
  description = "Azure AKS Kubernetes administrators for the ${var.prefix}-aks-cluster-administrators."
}

####     ===cC 
##  AKS - Enable Log nalitics For Kubernetes 
####     ===cC               

resource "azurerm_log_analytics_workspace" "main" {
  count = var.enable_log_log_analytics_workspace ? 1 : 0

  name                = format("${local.names.alw_name}-%03d", count.index + 1)
  location            = data.azurerm_resource_group.main.location
  resource_group_name = data.azurerm_resource_group.main.name
  sku                 = var.log_analytics_workspace_sku
  retention_in_days   = var.retention_in_days
  tags = "${merge(tomap({ResourceName = "${format("${local.names.alw_name}-%03d", count.index + 1)}"}),
   local.default_tags, 
   var.tags)
   }"
}

####     ===cC 
##  AKS - Azure Kubernetes Cluster Resource 
####     ===cC               


resource "azurerm_kubernetes_cluster" "main" {

  name                = local.names.aks
  location            = data.azurerm_resource_group.main.location
  resource_group_name = data.azurerm_resource_group.main.name
  dns_prefix          = local.names.aks
  kubernetes_version  = data.azurerm_kubernetes_service_versions.main.latest_version
  node_resource_group = "${local.names.aks}-nrg"
  
  dns_prefix_private_cluster = "${local.names.aks}-in"
  
  automatic_channel_upgrade       = var.automatic_channel_upgrade
  api_server_authorized_ip_ranges = var.api_server_authorized_ip_ranges
  disk_encryption_set_id          = var.disk_encryption_set_id
  private_cluster_enabled         = var.private_cluster_enabled
  private_dns_zone_id             = var.private_dns_zone_id
  sku_tier                        = var.sku_tier

  network_profile {
    network_plugin     = var.network_plugin
    network_policy     = var.network_policy
    dns_service_ip     = var.dns_service_ip
    docker_bridge_cidr = var.docker_bridge_cidr
    outbound_type      = var.outbound_type
    pod_cidr           = var.pod_cidr
    service_cidr       = var.service_cidr
    load_balancer_sku  = var.load_balancer_sku 
  }
  
  default_node_pool {
    name                         = "${local.names.aks}-SystemPool"
    vm_size                      = var.vm_size
    availability_zones           = var.availability_zones
    enable_auto_scaling          = var.enable_auto_scaling
    enable_host_encryption       = var.enable_host_encryption
    enable_node_public_ip        = var.enable_node_public_ip
    max_pods                     = var.max_pods
    node_labels                  = var.node_labels
    only_critical_addons_enabled = var.only_critical_addons_enabled
    orchestrator_version         = var.orchestrator_version
    os_disk_size_gb              = var.os_disk_size_gb
    os_disk_type                 = var.os_disk_type
    type                         = var.agent_type
    vnet_subnet_id               = var.vnet_subnet_id

    max_count  = var.enable_auto_scaling == true ? var.max_count : null
    min_count  = var.enable_auto_scaling == true ? var.min_count : null
    node_count = var.node_count

    dynamic "upgrade_settings" {
      for_each = var.max_surge == null ? [] : ["upgrade_settings"]
      content {
        max_surge = var.max_surge
      }
    }

    tags = "${merge(tomap({ResourceName = local.name.default_node_pool}), local.default_tags, var.tags)}"
  }
  

  identity {
    type                      = var.user_assigned_identity_id == "" ? "SystemAssigned" : "UserAssigned"
    user_assigned_identity_id = var.user_assigned_identity_id == "" ? null : var.user_assigned_identity_id
  }

  linux_profile {
    admin_username = var.admin_username

    ssh_key {
      # remove any new lines using the replace interpolation function
      key_data = replace(var.public_ssh_key == "" ? module.ssh-key.public_ssh_key : var.public_ssh_key, "\n", "")
    }
  }

  addon_profile {
    aci_connector_linux {
      enabled     = var.enable_aci_connector_linux
      subnet_name = var.enable_aci_connector_linux ? var.aci_connector_linux_subnet_name : null
    }

    azure_policy {
      enabled = var.enable_azure_policy
    }

    http_application_routing {
      enabled = var.enable_http_application_routing
    }

    kube_dashboard {
      enabled = var.enabled_kube_dashboard
    }

    oms_agent {
      enabled                    = var.enable_log_analytics_workspace
      log_analytics_workspace_id = var.enable_log_analytics_workspace ? azurerm_log_analytics_workspace.main[0].id : null
    }
  
  }


  
  lifecycle {
    ignore_changes = [
      tags,
      default_node_pool[0].node_count,
      default_node_pool[0].tags
    ]
  }

  role_based_access_control {
    enabled = var.enable_role_based_access_control

    dynamic "azure_active_directory" {
      for_each = var.enable_role_based_access_control && var.enable_azure_active_directory && var.rbac_aad_managed ? ["rbac"] : []
      content {
        managed                = true
        admin_group_object_ids = var.rbac_aad_admin_group_object_ids
      }
    }

    dynamic "azure_active_directory" {
      for_each = var.enable_role_based_access_control && var.enable_azure_active_directory && !var.rbac_aad_managed ? ["rbac"] : []
      content {
        managed           = false
        client_app_id     = var.rbac_aad_client_app_id
        server_app_id     = var.rbac_aad_server_app_id
        server_app_secret = var.rbac_aad_server_app_secret
      }
    }

  tags = "${merge(tomap({ResourceName = local.name.aks}), local.default_tags, var.tags)}"
}

}
####     === 
##  AKS - NodePool Tool - Module 
####     ===

module "nodes" {
  source = "./modules/node-pools"

  kubernetes_cluster_id = azurerm_kubernetes_cluster.main.id
  vnet_subnet_id        = var.vnet_subnet_id

  node_pools = var.node_pools
}