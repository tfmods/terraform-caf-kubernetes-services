provider "azurerm" {
  features {}
}

provider "azuread" {}

#az aks admin from AAD
data "azuread_user" "aad" {
  mail_nickname = "rosthan.silva@swonelab.com"
}

data "azurerm_kubernetes_service_versions" "main" {
  location        = azurerm_resource_group.main.location
  include_preview = false
}

#Admin Group from AAD
resource "azuread_group" "main" {
  display_name = "Kubernetes Admins"
  members = [
    data.azuread_user.aad.object_id,
  ]
}

resource "azurerm_resource_group" "rg" {
  name     = "rg-example"
  location = "eastus"
  tags = {
    env       = "test"
    managedBy = "terraform"
  }
}

module "aks_vnet" {
  source              = "./mod/vnet"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  tags                = azurerm_resource_group.rg.tags
  vnet_name           = "vnet-aks"

  address_space = ["172.16.0.0/16"]
  subnets = {
    aks-subnet = {
      address_prefix = "172.16.0.0/24"
    }
    other-subnet = {
      address_prefix = "172.16.1.0/24"
    }
  }
  depends_on = [
    azurerm_resource_group.rg
  ]
}

resource "azurerm_user_assigned_identity" "main" {
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location

  name = "identity-aks-teste"
}


resource "azurerm_private_dns_zone" "main" {
  name                = "privatelink.eastus.azmk8s.io"
  resource_group_name = azurerm_resource_group.rg.name
}

resource "azurerm_role_assignment" "network" {
  scope                = azurerm_resource_group.rg.id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_user_assigned_identity.main.principal_id
}

resource "azurerm_role_assignment" "dns" {
  scope                = azurerm_private_dns_zone.main.id
  role_definition_name = "Private DNS Zone Contributor"
  principal_id         = azurerm_user_assigned_identity.main.principal_id
}

module "aks" {
  source = "../.."

  aks_name            = "teste"
  resource_group_name = azurerm_resource_group.rg

  user_assigned_identity_id = azurerm_user_assigned_identity.main.id

  enable_azure_active_directory   = true
  rbac_aad_managed                = true
  rbac_aad_admin_group_object_ids = [azuread_group.main.object_id]

  private_dns_zone_id = azurerm_private_dns_zone.main.id

  private_cluster_enabled = true

  availability_zones   = ["1", "2", "3"]
  enable_auto_scaling  = true
  max_pods             = 100
  orchestrator_version = data.azurerm_kubernetes_service_versions.main.latest_version
  vnet_subnet_id       = module.aks_vnet.vnet_subnet_id
  max_count            = 3
  min_count            = 1
  node_count           = 1

  enable_log_analytics_workspace = true

  network_plugin = "azure"
  network_policy = "calico"

  only_critical_addons_enabled = true

  node_pools = [
    {
      name                 = "user1"
      availability_zones   = ["1", "2", "3"]
      enable_auto_scaling  = true
      max_pods             = 100
      orchestrator_version = data.azurerm_kubernetes_service_versions.main.latest_version
      priority             = "Regular"
      max_count            = 3
      min_count            = 1
      node_count           = 1
    },
    {
      name                 = "spot1"
      max_pods             = 100
      orchestrator_version = data.azurerm_kubernetes_service_versions.main.latest_version
      priority             = "Spot"
      eviction_policy      = "Delete"
      spot_max_price       = 0.5 # note: this is the "maximum" price
      node_labels = {
        "kubernetes.azure.com/scalesetpriority" = "spot"
      }
      node_taints = [
        "kubernetes.azure.com/scalesetpriority=spot:NoSchedule"
      ]
      node_count = 1
    }
  ]

  tags = {
    "ManagedBy" = "Terraform"
  }

  depends_on = [
    module.rg,
    azurerm_role_assignment.dns,
    azurerm_role_assignment.network
  ]
}