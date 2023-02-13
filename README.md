<!-- BEGIN_TF_DOCS -->
# Azure Aks Caf Module

[[_TOC_]]

## Usage Examples
### Simplified structure
``` Go
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
```

### Complex structure
``` Go
To be created
```

## Providers

| Name | Version |
|------|---------|
| <a name="provider_azuread"></a> [azuread](#provider\_azuread) | n/a |
| <a name="provider_azurerm"></a> [azurerm](#provider\_azurerm) | n/a |
| <a name="provider_tls"></a> [tls](#provider\_tls) | n/a |

## Resources

| Name | Type |
|------|------|
| [azuread_group.main](https://registry.terraform.io/providers/hashicorp/azuread/latest/docs/resources/group) | resource |
| [azurerm_container_registry.main](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/container_registry) | resource |
| [azurerm_key_vault.main](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/key_vault) | resource |
| [azurerm_kubernetes_cluster.main](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/kubernetes_cluster) | resource |
| [azurerm_log_analytics_workspace.main](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/log_analytics_workspace) | resource |
| [azurerm_role_assignment.acr](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment) | resource |
| [azurerm_role_assignment.aks_uai_private_dns_zone_contributor](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment) | resource |
| [azurerm_role_assignment.aks_uai_vnet_network_contributor](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment) | resource |
| [azurerm_role_assignment.aks_user_assigned](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment) | resource |
| [azurerm_user_assigned_identity.aks](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/user_assigned_identity) | resource |
| [tls_private_key.main](https://registry.terraform.io/providers/hashicorp/tls/latest/docs/resources/private_key) | resource |
| [azuread_client_config.main](https://registry.terraform.io/providers/hashicorp/azuread/latest/docs/data-sources/client_config) | data source |
| [azurerm_kubernetes_service_versions.main](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/kubernetes_service_versions) | data source |
| [azurerm_resource_group.main](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/resource_group) | data source |
| [azurerm_subscription.main](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/subscription) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_aad_aks_group_ownners"></a> [aad\_aks\_group\_ownners](#input\_aad\_aks\_group\_ownners) | AAD Kubernetes Admin group Owners. This users can manipulate users in the aks amin group | `list(string)` | n/a | yes |
| <a name="input_aks_name"></a> [aks\_name](#input\_aks\_name) | The name of the Managed Kubernetes Cluster to create.<br>Changing this forces a new resource to be created. | `string` | n/a | yes |
| <a name="input_enable_auto_scaling"></a> [enable\_auto\_scaling](#input\_enable\_auto\_scaling) | (Optional) Should the Kubernetes Auto Scaler be enabled for this Node Pool?<br>     Note:<br>     This requires that the type is set to VirtualMachineScaleSets.<br><br>     Note:<br>     If you're using AutoScaling, you may wish to use Terraform's ignore\_changes functionality to ignore changes to the node\_count field. | `string` | n/a | yes |
| <a name="input_vnet_id"></a> [vnet\_id](#input\_vnet\_id) | n/a | `any` | n/a | yes |
| <a name="input_aci_connector_linux_subnet_name"></a> [aci\_connector\_linux\_subnet\_name](#input\_aci\_connector\_linux\_subnet\_name) | The subnet name for the virtual nodes to run.<br>AKS will add a delegation to the subnet named here.<br>To prevent further runs from failing you should make sure that the subnet<br>you create for virtual nodes has a delegation, like so.<pre>hcl<br>resource "azurerm_subnet" "virtual" {<br>  #...<br>  delegation {<br>    name = "aciDelegation"<br>    service_delegation {<br>      name    = "Microsoft.ContainerInstance/containerGroups"<br>      actions = ["Microsoft.Network/virtualNetworks/subnets/action"]<br>    }<br>  }<br>}</pre> | `string` | `null` | no |
| <a name="input_acr_id"></a> [acr\_id](#input\_acr\_id) | Attach ACR ID to allow ACR Pull from the SP/Managed Indentity. | `string` | `""` | no |
| <a name="input_admin_username"></a> [admin\_username](#input\_admin\_username) | The Admin Username for the Cluster.<br>Changing this forces a new resource to be created. | `string` | `"azureuser"` | no |
| <a name="input_agent_tags"></a> [agent\_tags](#input\_agent\_tags) | A mapping of tags to assign to the Node Pool. | `map(string)` | `{}` | no |
| <a name="input_agent_type"></a> [agent\_type](#input\_agent\_type) | The type of Node Pool which should be created.<br>Possible values are AvailabilitySet and VirtualMachineScaleSets. | `string` | `"VirtualMachineScaleSets"` | no |
| <a name="input_alw_name"></a> [alw\_name](#input\_alw\_name) | name - (Required) The name of the Managed Kubernetes Cluster to create. Changing this forces a new resource to be created. | `string` | `"alw"` | no |
| <a name="input_api_server_authorized_ip_ranges"></a> [api\_server\_authorized\_ip\_ranges](#input\_api\_server\_authorized\_ip\_ranges) | The IP ranges to whitelist for incoming traffic to the masters. | `list(string)` | `null` | no |
| <a name="input_automatic_channel_upgrade"></a> [automatic\_channel\_upgrade](#input\_automatic\_channel\_upgrade) | The upgrade channel for this Kubernetes Cluster.<br>Possible values are none, patch, rapid, and stable.<br>Cluster Auto-Upgrade will update the Kubernetes Cluster (and it's Node Pools)<br>to the latest GA version of Kubernetes automatically.<br>Please see [the Azure documentation for more information](https://docs.microsoft.com/en-us/azure/aks/upgrade-cluster#set-auto-upgrade-channel-preview). | `string` | `null` | no |
| <a name="input_availability_zones"></a> [availability\_zones](#input\_availability\_zones) | A list of Availability Zones across which the Node Pool should be spread.<br>Changing this forces a new resource to be created.<br>This requires that the type is set to VirtualMachineScaleSets and that<br>load\_balancer\_sku is set to Standard. | `list(string)` | `null` | no |
| <a name="input_azure_policy_enable"></a> [azure\_policy\_enable](#input\_azure\_policy\_enable) | Boolean value to enable Azure Police over Kubernetes resources | `bool` | `false` | no |
| <a name="input_costcentre"></a> [costcentre](#input\_costcentre) | A cost centre is a department within a business to which costs can be allocated.<br>        The term includes departments which do not produce directly but they incur costs to the business,<br>        when the manager and employees of the cost centre are not accountable for the profitability and investment decisions of the business but they are responsible for some of its costs. | `string` | `"Gothan"` | no |
| <a name="input_create_aad_group"></a> [create\_aad\_group](#input\_create\_aad\_group) | definition to create an azure ad group | `bool` | `true` | no |
| <a name="input_departament"></a> [departament](#input\_departament) | a distinct part of anything arranged in divisions; a division of a complex whole or organized system. one of the principal branches of a governmental organization: the sanitation department. | `string` | `"Security"` | no |
| <a name="input_departament_principal"></a> [departament\_principal](#input\_departament\_principal) | An IT manager oversees all computer-related tasks, problems, and solutions within a business. Depending on the sector they work in and the organization they work for, they may also be referred to as IT directors or computer and information systems managers. | `string` | `"Joker"` | no |
| <a name="input_disk_encryption_set_id"></a> [disk\_encryption\_set\_id](#input\_disk\_encryption\_set\_id) | (Optional) The ID of the Disk Encryption Set which should be used for the Nodes and Volumes.<br>Please see [the documentation](https://docs.microsoft.com/en-us/azure/aks/azure-disk-customer-managed-keys)<br>and [disk\_encryption\_set](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/disk_encryption_set)<br>for more information. | `string` | `null` | no |
| <a name="input_dns_service_ip"></a> [dns\_service\_ip](#input\_dns\_service\_ip) | IP address within the Kubernetes service address range that will be used by<br>cluster service discovery (kube-dns).<br>Changing this forces a new resource to be created. | `string` | `null` | no |
| <a name="input_docker_bridge_cidr"></a> [docker\_bridge\_cidr](#input\_docker\_bridge\_cidr) | IP address (in CIDR notation) used as the Docker bridge IP address on nodes.<br>Changing this forces a new resource to be created. | `string` | `null` | no |
| <a name="input_enable_attach_acr"></a> [enable\_attach\_acr](#input\_enable\_attach\_acr) | Enable ACR Pull attach. Needs acr\_id to be defined. | `bool` | `false` | no |
| <a name="input_enable_azure_active_directory"></a> [enable\_azure\_active\_directory](#input\_enable\_azure\_active\_directory) | Enable Azure Active Directory Integration? | `bool` | `false` | no |
| <a name="input_enable_azure_policy"></a> [enable\_azure\_policy](#input\_enable\_azure\_policy) | Is the Azure Policy for Kubernetes Add On enabled? | `bool` | `false` | no |
| <a name="input_enable_azurerm_key_vault"></a> [enable\_azurerm\_key\_vault](#input\_enable\_azurerm\_key\_vault) | Enable Secret manager azure key vault for Azure Kubernetes Service. | `string` | `false` | no |
| <a name="input_enable_container_registry"></a> [enable\_container\_registry](#input\_enable\_container\_registry) | Value to enable Azure Container Registry to Azure kubernetes Service | `bool` | `false` | no |
| <a name="input_enable_host_encryption"></a> [enable\_host\_encryption](#input\_enable\_host\_encryption) | Should the nodes in the Default Node Pool have host encryption enabled? | `bool` | `false` | no |
| <a name="input_enable_http_application_routing"></a> [enable\_http\_application\_routing](#input\_enable\_http\_application\_routing) | Is HTTP Application Routing Enabled? | `bool` | `false` | no |
| <a name="input_enable_log_analytics_workspace"></a> [enable\_log\_analytics\_workspace](#input\_enable\_log\_analytics\_workspace) | Enable the creation of azurerm\_log\_analytics\_workspace and<br>azurerm\_log\_analytics\_solution or not | `bool` | `false` | no |
| <a name="input_enable_log_log_analytics_workspace"></a> [enable\_log\_log\_analytics\_workspace](#input\_enable\_log\_log\_analytics\_workspace) | Variable to Enable Log analytics to Aks Cluster | `bool` | `false` | no |
| <a name="input_enable_node_public_ip"></a> [enable\_node\_public\_ip](#input\_enable\_node\_public\_ip) | Should nodes in this Node Pool have a Public IP Address? | `bool` | `false` | no |
| <a name="input_enable_role_based_access_control"></a> [enable\_role\_based\_access\_control](#input\_enable\_role\_based\_access\_control) | Is Role Based Access Control Enabled?<br>Changing this forces a new resource to be created. | `bool` | `true` | no |
| <a name="input_enabled_kube_dashboard"></a> [enabled\_kube\_dashboard](#input\_enabled\_kube\_dashboard) | Is the Kubernetes Dashboard enabled? | `bool` | `false` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | 3 to 5 letter Abreviation from Client company or project environment<br>        Example: <br>          environment : Development<br>          tfvars value : environment = dev<br><br>          environment = production<br>          tfvars value : project = prd | `string` | `"test"` | no |
| <a name="input_key_vault_secrets_provider_enabled"></a> [key\_vault\_secrets\_provider\_enabled](#input\_key\_vault\_secrets\_provider\_enabled) | (Optional) A key\_vault\_secrets\_provider block as defined below. For more details, please visit Azure Keyvault Secrets Provider for AKS. | `bool` | `false` | no |
| <a name="input_kubernetes_version"></a> [kubernetes\_version](#input\_kubernetes\_version) | Version of Kubernetes specified when creating the AKS managed cluster.<br>If not specified, the latest recommended version will be used at provisioning time (but won't auto-upgrade). | `string` | `null` | no |
| <a name="input_load_balancer_sku"></a> [load\_balancer\_sku](#input\_load\_balancer\_sku) | Specifies the SKU of the Load Balancer used for this Kubernetes Cluster.<br>Possible values are Basic and Standard. | `string` | `"Standard"` | no |
| <a name="input_location"></a> [location](#input\_location) | Cloud Location to deploy cloud resources.<br>        Changing this forces a new resource to be created.<br>    <br>        Example: <br>            DisplayName               Name                 RegionalDisplayName<br>            ------------------------  -------------------  -------------------------------------<br>            East US                   eastus               (US) East US<br>            East US 2                 eastus2              (US) East US 2<br>            South Central US          southcentralus       (US) South Central US<br>            West US 2                 westus2              (US) West US 2<br>            West US 3                 westus3              (US) West US 3<br>            Australia East            australiaeast        (Asia Pacific) Australia East<br>            Southeast Asia            southeastasia        (Asia Pacific) Southeast Asia<br>            North Europe              northeurope          (Europe) North Europe<br>            Sweden Central            swedencentral        (Europe) Sweden Central<br>            UK South                  uksouth              (Europe) UK South<br>            West Europe               westeurope           (Europe) West Europe<br>            Central US                centralus            (US) Central US<br>            South Africa North        southafricanorth     (Africa) South Africa North<br>            Central India             centralindia         (Asia Pacific) Central India<br>            East Asia                 eastasia             (Asia Pacific) East Asia<br>            Japan East                japaneast            (Asia Pacific) Japan East<br>            Korea Central             koreacentral         (Asia Pacific) Korea Central<br>            Canada Central            canadacentral        (Canada) Canada Central<br>            France Central            francecentral        (Europe) France Central<br>            Germany West Central      germanywestcentral   (Europe) Germany West Central<br>            Norway East               norwayeast           (Europe) Norway East<br>            Switzerland North         switzerlandnorth     (Europe) Switzerland North<br>            UAE North                 uaenorth             (Middle East) UAE North<br>            Brazil South              brazilsouth          (South America) Brazil South<br>            East US 2 EUAP            eastus2euap          (US) East US 2 EUAP<br>            Qatar Central             qatarcentral         (Middle East) Qatar Central<br>            Central US (Stage)        centralusstage       (US) Central US (Stage)<br>            East US (Stage)           eastusstage          (US) East US (Stage)<br>            East US 2 (Stage)         eastus2stage         (US) East US 2 (Stage)<br>            North Central US (Stage)  northcentralusstage  (US) North Central US (Stage)<br>            South Central US (Stage)  southcentralusstage  (US) South Central US (Stage)<br>            West US (Stage)           westusstage          (US) West US (Stage)<br>            West US 2 (Stage)         westus2stage         (US) West US 2 (Stage)<br>            Asia                      asia                 Asia<br>            Asia Pacific              asiapacific          Asia Pacific<br>            Australia                 australia            Australia<br>            Brazil                    brazil               Brazil<br>            Canada                    canada               Canada<br>            Europe                    europe               Europe<br>            France                    france               France<br>            Germany                   germany              Germany<br>            Global                    global               Global<br>            India                     india                India<br>            Japan                     japan                Japan<br>            Korea                     korea                Korea<br>            Norway                    norway               Norway<br>            Singapore                 singapore            Singapore<br>            South Africa              southafrica          South Africa<br>            Switzerland               switzerland          Switzerland<br>            United Arab Emirates      uae                  United Arab Emirates<br>            United Kingdom            uk                   United Kingdom<br>            United States             unitedstates         United States<br>            United States EUAP        unitedstateseuap     United States EUAP<br>            East Asia (Stage)         eastasiastage        (Asia Pacific) East Asia (Stage)<br>            Southeast Asia (Stage)    southeastasiastage   (Asia Pacific) Southeast Asia (Stage)<br>            East US STG               eastusstg            (US) East US STG<br>            South Central US STG      southcentralusstg    (US) South Central US STG<br>            North Central US          northcentralus       (US) North Central US<br>            West US                   westus               (US) West US<br>            Jio India West            jioindiawest         (Asia Pacific) Jio India West<br>            Central US EUAP           centraluseuap        (US) Central US EUAP<br>            West Central US           westcentralus        (US) West Central US<br>            South Africa West         southafricawest      (Africa) South Africa West<br>            Australia Central         australiacentral     (Asia Pacific) Australia Central<br>            Australia Central 2       australiacentral2    (Asia Pacific) Australia Central 2<br>            Australia Southeast       australiasoutheast   (Asia Pacific) Australia Southeast<br>            Japan West                japanwest            (Asia Pacific) Japan West<br>            Jio India Central         jioindiacentral      (Asia Pacific) Jio India Central<br>            Korea South               koreasouth           (Asia Pacific) Korea South<br>            South India               southindia           (Asia Pacific) South India<br>            West India                westindia            (Asia Pacific) West India<br>            Canada East               canadaeast           (Canada) Canada East<br>            France South              francesouth          (Europe) France South<br>            Germany North             germanynorth         (Europe) Germany North<br>            Norway West               norwaywest           (Europe) Norway West<br>            Switzerland West          switzerlandwest      (Europe) Switzerland West<br>            UK West                   ukwest               (Europe) UK West<br>            UAE Central               uaecentral           (Middle East) UAE Central<br>            Brazil Southeast          brazilsoutheast      (South America) Brazil Southeast | `string` | `"eastus"` | no |
| <a name="input_log_analytics_workspace_sku"></a> [log\_analytics\_workspace\_sku](#input\_log\_analytics\_workspace\_sku) | The SKU (pricing level) of the Log Analytics workspace.<br>For new subscriptions the SKU should be set to PerGB2018 | `string` | `"PerGB2018"` | no |
| <a name="input_max_count"></a> [max\_count](#input\_max\_count) | The maximum number of nodes which should exist in this Node Pool.<br>If specified this must be between 1 and 1000. | `number` | `null` | no |
| <a name="input_max_pods"></a> [max\_pods](#input\_max\_pods) | The maximum number of pods that can run on each agent.<br>Changing this forces a new resource to be created. | `number` | `null` | no |
| <a name="input_max_surge"></a> [max\_surge](#input\_max\_surge) | The maximum number or percentage of nodes which will be added to the Node Pool<br>size during an upgrade.<br>If a percentage is provided, the number of surge nodes is calculated from the<br>node\_count value on the current cluster. Node surge can allow a cluster to<br>have more nodes than max\_count during an upgrade. | `string` | `null` | no |
| <a name="input_min_count"></a> [min\_count](#input\_min\_count) | The minimum number of nodes which should exist in this Node Pool.<br>If specified this must be between 1 and 1000. | `number` | `null` | no |
| <a name="input_network_plugin"></a> [network\_plugin](#input\_network\_plugin) | Network plugin to use for networking. Currently supported values are azure and kubenet.<br>Changing this forces a new resource to be created. | `string` | `"kubenet"` | no |
| <a name="input_network_policy"></a> [network\_policy](#input\_network\_policy) | Sets up network policy to be used with Azure CNI.<br>Currently supported values are calico and azure.<br>Changing this forces a new resource to be created. | `string` | `null` | no |
| <a name="input_network_profile_network_plugin"></a> [network\_profile\_network\_plugin](#input\_network\_profile\_network\_plugin) | (Required) Network plugin to use for networking. Currently supported values are azure, kubenet and none. Changing this forces a new resource to be created.<br> <br>   Note:<br>   When network\_plugin is set to azure - the vnet\_subnet\_id field in the default\_node\_pool block must be set and pod\_cidr must not be set.<br> <br>   More Information Visiting : https://learn.microsoft.com/en-us/azure/aks/configure-azure-cni | `string` | `"kubenet"` | no |
| <a name="input_network_profile_network_policy"></a> [network\_profile\_network\_policy](#input\_network\_profile\_network\_policy) | (Optional) Sets up network policy to be used with Azure CNI. Network policy allows us to control the traffic flow between pods. Currently supported values are calico and azure. Changing this forces a new resource to be created.<br>   <br>      More Info : https://learn.microsoft.com/pt-br/azure/aks/use-network-policies | `string` | `"calico"` | no |
| <a name="input_node_count"></a> [node\_count](#input\_node\_count) | The initial number of nodes which should exist in this Node Pool. If specified<br>this must be between 1 and 1000 and between min\_count and max\_count. | `number` | `1` | no |
| <a name="input_node_labels"></a> [node\_labels](#input\_node\_labels) | A map of Kubernetes labels which should be applied to nodes in the Default Node Pool.<br>Changing this forces a new resource to be created. | `map(string)` | `{}` | no |
| <a name="input_node_pools"></a> [node\_pools](#input\_node\_pools) | Allows to create multiple Node Pools.<br>node\_pools can have more than one pool. The name attribute is used<br>to create key/value map, and priority is needed to filter, but all the other<br>elements are optional.<pre>hcl<br>node_pools = [<br>  {<br>    name = "user1"<br>    priority = "Regular"<br>  },<br>  {<br>    name = "spot1"<br>    priority = "Spot"<br>  }<br>]</pre>Valid fields are:<br>* vm\_size<br>* availability\_zones<br>* enable\_auto\_scaling<br>* enable\_host\_encryption<br>* enable\_node\_public\_ip<br>* eviction\_policy<br>* max\_pods<br>* mode<br>* node\_labels<br>* node\_taints<br>* orchestrator\_version<br>* os\_disk\_size\_gb<br>* os\_disk\_type<br>* os\_type<br>* priority<br>* spto\_max\_price<br>* tags<br>* max\_count<br>* min\_count<br>* node\_count<br>* max\_surge | `any` | `[]` | no |
| <a name="input_node_resource_group"></a> [node\_resource\_group](#input\_node\_resource\_group) | The name of the Resource Group where the Kubernetes Nodes should exist.<br>Changing this forces a new resource to be created.<br>Azure requires that a new, non-existent Resource Group is used, as otherwise the<br>provisioning of the Kubernetes Service will fail. | `string` | `null` | no |
| <a name="input_only_critical_addons_enabled"></a> [only\_critical\_addons\_enabled](#input\_only\_critical\_addons\_enabled) | Enabling this option will taint default node pool with<br>CriticalAddonsOnly=true:NoSchedule taint.<br>Changing this forces a new resource to be created. | `bool` | `false` | no |
| <a name="input_orchestrator_version"></a> [orchestrator\_version](#input\_orchestrator\_version) | Version of Kubernetes used for the Agents. If not specified, the latest<br>recommended version will be used at provisioning time (but won't auto-upgrade) | `string` | `null` | no |
| <a name="input_os_disk_size_gb"></a> [os\_disk\_size\_gb](#input\_os\_disk\_size\_gb) | The size of the OS Disk which should be used for each agent in the Node Pool.<br>Changing this forces a new resource to be created. | `number` | `null` | no |
| <a name="input_os_disk_type"></a> [os\_disk\_type](#input\_os\_disk\_type) | The type of disk which should be used for the Operating System.<br>Possible values are Ephemeral and Managed.<br>Changing this forces a new resource to be created. | `string` | `"Managed"` | no |
| <a name="input_outbound_type"></a> [outbound\_type](#input\_outbound\_type) | The outbound (egress) routing method which should be used for this Kubernetes<br>Cluster. Possible values are loadBalancer and userDefinedRouting. | `string` | `"loadBalancer"` | no |
| <a name="input_pod_cidr"></a> [pod\_cidr](#input\_pod\_cidr) | The CIDR to use for pod IP addresses. This field can only be set when<br>network\_plugin is set to kubenet.<br>Changing this forces a new resource to be created. | `string` | `null` | no |
| <a name="input_private_cluster_enabled"></a> [private\_cluster\_enabled](#input\_private\_cluster\_enabled) | Should this Kubernetes Cluster have its API server only exposed on internal<br>IP addresses? This provides a Private IP Address for the Kubernetes API on the<br>Virtual Network where the Kubernetes Cluster is located.<br>Changing this forces a new resource to be created. | `bool` | `false` | no |
| <a name="input_private_dns_zone_id"></a> [private\_dns\_zone\_id](#input\_private\_dns\_zone\_id) | Either the ID of Private DNS Zone which should be delegated to this Cluster,<br>or System to have AKS manage this.<br>If you use BYO DNS Zone, AKS cluster should either use a User Assigned Identity<br>or a service principal (which is deprecated) with the Private DNS Zone Contributor<br>role and access to this Private DNS Zone. If UserAssigned identity is used - to<br>prevent improper resource order destruction - cluster should depend on the role assignment | `string` | `null` | no |
| <a name="input_project"></a> [project](#input\_project) | 3 letter Abreviation to Client company or project name<br>        Example: <br>          Cliente : Coporação tecniclogica brasil<br>          tfvars value : project = ctb<br><br>          Cliente = SoftwareOne<br>          tfvars value : project = swo | `string` | `"swo"` | no |
| <a name="input_public_ssh_key"></a> [public\_ssh\_key](#input\_public\_ssh\_key) | The Public SSH Key used to access the cluster.<br>Changing this forces a new resource to be created. | `string` | `""` | no |
| <a name="input_purge_protection_enabled"></a> [purge\_protection\_enabled](#input\_purge\_protection\_enabled) | (Optional) Is Purge Protection enabled for this Key Vault? Defaults to false. | `bool` | `true` | no |
| <a name="input_rbac_aad_admin_group_object_ids"></a> [rbac\_aad\_admin\_group\_object\_ids](#input\_rbac\_aad\_admin\_group\_object\_ids) | Object ID of groups with admin access. | `list(string)` | `null` | no |
| <a name="input_rbac_aad_client_app_id"></a> [rbac\_aad\_client\_app\_id](#input\_rbac\_aad\_client\_app\_id) | The Client ID of an Azure Active Directory Application. | `string` | `null` | no |
| <a name="input_rbac_aad_managed"></a> [rbac\_aad\_managed](#input\_rbac\_aad\_managed) | Is the Azure Active Directory integration Managed, meaning that Azure will<br>create/manage the Service Principal used for integration. | `bool` | `false` | no |
| <a name="input_rbac_aad_server_app_secret"></a> [rbac\_aad\_server\_app\_secret](#input\_rbac\_aad\_server\_app\_secret) | The Server Secret of an Azure Active Directory Application. | `string` | `null` | no |
| <a name="input_resource_admin"></a> [resource\_admin](#input\_resource\_admin) | A system administrator, or sysadmin, or admin is a person who is responsible for the upkeep,<br>        configuration, and reliable operation of computer systems, especially multi-user computers, such as servers. | `string` | `"Bruce Wayne"` | no |
| <a name="input_resource_group_name"></a> [resource\_group\_name](#input\_resource\_group\_name) | (Required) Specifies the Resource Group where the Managed Kubernetes Cluster should exist. Changing this forces a new resource to be created. | `string` | `"null"` | no |
| <a name="input_retention_in_days"></a> [retention\_in\_days](#input\_retention\_in\_days) | n/a | `string` | `"30"` | no |
| <a name="input_service_cidr"></a> [service\_cidr](#input\_service\_cidr) | The Network Range used by the Kubernetes service.<br>Changing this forces a new resource to be created. | `string` | `null` | no |
| <a name="input_sku_tier"></a> [sku\_tier](#input\_sku\_tier) | The SKU Tier that should be used for this Kubernetes Cluster.<br>Possible values are Free and Paid (which includes the Uptime SLA). | `string` | `"Free"` | no |
| <a name="input_solution_version"></a> [solution\_version](#input\_solution\_version) | Version of solutions stack - example v1.1.1 or v1.0.0-beta | `string` | `"1.0.0"` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | A mapping of tags which should be assigned to Resources. | `map(string)` | `{}` | no |
| <a name="input_user_assigned_identity_id"></a> [user\_assigned\_identity\_id](#input\_user\_assigned\_identity\_id) | The ID of a user assigned identity. | `string` | `""` | no |
| <a name="input_vm_size"></a> [vm\_size](#input\_vm\_size) | The size of the Virtual Machine, such as Standard\_DS2\_v2. | `string` | `"Standard_D2s_v3"` | no |
| <a name="input_vnet_subnet_id"></a> [vnet\_subnet\_id](#input\_vnet\_subnet\_id) | The ID of a Subnet where the Kubernetes Node Pool should exist.<br>Changing this forces a new resource to be created. | `string` | `null` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_aks_cluster_id"></a> [aks\_cluster\_id](#output\_aks\_cluster\_id) | n/a |
| <a name="output_aks_cluster_kubernetes_version"></a> [aks\_cluster\_kubernetes\_version](#output\_aks\_cluster\_kubernetes\_version) | n/a |
| <a name="output_aks_cluster_name"></a> [aks\_cluster\_name](#output\_aks\_cluster\_name) | n/a |
| <a name="output_azure_ad_group_id"></a> [azure\_ad\_group\_id](#output\_azure\_ad\_group\_id) | Azure AD Group Object Id |
| <a name="output_azure_ad_group_objectid"></a> [azure\_ad\_group\_objectid](#output\_azure\_ad\_group\_objectid) | n/a |
| <a name="output_client_certificate"></a> [client\_certificate](#output\_client\_certificate) | Kubernetes Files Output |
| <a name="output_default_node_pool_rg_name"></a> [default\_node\_pool\_rg\_name](#output\_default\_node\_pool\_rg\_name) | n/a |
| <a name="output_kube_config"></a> [kube\_config](#output\_kube\_config) | n/a |
| <a name="output_latest_version"></a> [latest\_version](#output\_latest\_version) | n/a |
| <a name="output_versions"></a> [versions](#output\_versions) | Azure AKS Versions Datasource |

## Would you like to contribute?

To contribute with this repository you must install [**terraform-docs**](https://terraform-docs.io/user-guide/installation/).
Steps:
* Clone this repo;
* Create a branch;
* Prepare your changes;
* Commit and tag;
* Document your code using `make prepare-readme`;
* Push and Pull request,

<sub>Questions? let me know: carlos.oliveira@softwareone.com</sub>

<!-- END_TF_DOCS -->