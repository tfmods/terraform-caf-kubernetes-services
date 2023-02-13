provider "azurerm" {
  features {}
}

provider "azuread" {}

resource "random_pet" "pet" {
  length    = 2
  separator = "-"
}

#az aks admin from AAD
data "azuread_user" "aad" {
  #how to find the user ID
  #az ad user show --id xpto@xarope.com
  object_id = "3afdbb27-fcc9-45a1-bca0-fcb6028386a0"
}

# Get latest kubernetes Version
data "azurerm_kubernetes_service_versions" "main" {
  location        = azurerm_resource_group.main.location
  include_preview = false
}

#Admin Group from AAD
# resource "azuread_group" "main" {
#   display_name = "Kubernetes Admins"
#   members = [
#     data.azuread_user.aad.object_id,
#   ]
# }

resource "azurerm_resource_group" "main" {
  name     = "rg-aks"
  location = "eastus"
  tags = {
    env       = "test"
    managedBy = "terraform"
  }
}

module "aks_vnet" {
  source              = "git@ssh.dev.azure.com:v3/swonelab/Modulos_Terraform/terraform-azurerm-virtual-network"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  vnet_name           = join("-", ["vnet", random_pet.pet.id])
  address_space       = ["10.1.0.0/16", "192.169.0.0/24"]
  subnets = {
    aks_subnet = {
      address_prefix = "10.1.0.0/24"
      routes = {
        route1 = {
          address_prefix = "10.0.0.0/24"
        }
        route2 = {
          address_prefix = "10.10.0.0/24"
        }
      }
      nsg_name = "nsg1"
      # nsg_rules = [
      #   {
      #     # NSG Rules
      #   }
      # ]
    }
    linux = {
      address_prefix = "10.1.1.0/24"
      nsg_name       = "nsg2"
      routes         = {}
      # nsg_rules = [
      #   {
      #     # NSG Rules
      #   }
      # ]
    }
    AzureBastionSubnet = {
      address_prefix = "192.169.0.0/27"
      nsg_name       = "nsg3"
      routes = {
        #   myroute = {
        #     address_prefix = "10.10.0.0/24"
        #     next_hop_type  = "VirtualNetworkGateway" # Aceita VirtualNetworkGateway, Internet, VirtualAppliance, VnetLocal ou None (Padrão: None)
        #     # next_hop_in_ip_address = "10.0.0.4" # Somente é usado quando especifica o tipo VirtualAppliance.
        #   }
      }
      # nsg_rules = [
      #   {
      #     # NSG Rules
      #   }
      # ]
    }
    ingress-subent = {
      address_prefix = "10.1.10.0/27"
      nsg_name       = "nsg4"
      routes = {
        #   myroute = {
        #     address_prefix = "10.10.0.0/24"
        #     next_hop_type  = "VirtualNetworkGateway" # Aceita VirtualNetworkGateway, Internet, VirtualAppliance, VnetLocal ou None (Padrão: None)
        #     # next_hop_in_ip_address = "10.0.0.4" # Somente é usado quando especifica o tipo VirtualAppliance.
        #   }
      }
      # nsg_rules = [
      #   {
      #     # NSG Rules
      #   }
      # ]
    }
  }

  depends_on = [
    azurerm_resource_group.main
  ]
}

resource "azurerm_user_assigned_identity" "main" {
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location

  name = "identity-aks-teste"
}


resource "azurerm_private_dns_zone" "main" {
  name                = "privatelink.eastus.azmk8s.io"
  resource_group_name = azurerm_resource_group.main.name
}

resource "azurerm_role_assignment" "network" {
  scope                = azurerm_resource_group.main.id
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

  # prefixo de nome do aks
  aks_name                           = "lab"
  resource_group_name                = azurerm_resource_group.main.name
  enable_azurerm_key_vault           = true
  user_assigned_identity_id          = azurerm_user_assigned_identity.main.id
  aad_aks_group_ownners              = ["rosthan.silva@swonelab.com"]
  enable_azure_active_directory      = true
  rbac_aad_managed                   = true
  key_vault_secrets_provider_enabled = true
  #rbac_aad_admin_group_object_ids = [azuread_group.main.object_id]
  private_dns_zone_id     = azurerm_private_dns_zone.main.id
  private_cluster_enabled = true

  availability_zones   = ["1", "2", "3"]
  enable_auto_scaling  = "true"
  max_pods             = 100
  orchestrator_version = data.azurerm_kubernetes_service_versions.main.latest_version
  vnet_subnet_id       = module.aks_vnet.vnet_subnet_ids["aks_subnet"]
  vnet_id              = module.aks_vnet.vnet_id
  max_count            = 3
  min_count            = 1
  node_count           = 1

  enable_log_analytics_workspace = true

  network_plugin    = "azure"
  network_policy    = "calico"
  load_balancer_sku = "standard"

  only_critical_addons_enabled = true
  # bastion_service_subnet_name = "linux"
  # bastion_service_address_prefixes = ["10.1.101.0/27"]

  # default_node_pool = {

  #   vm_size                  = "Standard_DS2_v2"
  #   orchestrator_version     = data.azurerm_kubernetes_service_versions.main.latest_version
  #   availability_zones       = [1, 2, 3]
  #   enable_auto_scaling      = true
  #   max_count                = 3
  #   min_count                = 1
  #   os_disk_size_gb          = 30
  #   type                     = "VirtualMachineScaleSets"
  #   enable_azurerm_key_vault = "true"
  # }


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
      enable_auto_scaling  = true
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
    azurerm_resource_group.main,
    azurerm_role_assignment.dns,
    azurerm_role_assignment.network
  ]
}