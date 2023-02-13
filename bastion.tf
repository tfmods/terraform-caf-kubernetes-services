# # Resource-1: Create Public IP Address

# # Resource-2: Create Network Interface
# resource "azurerm_network_interface" "bastion_host_linuxvm_nic" {
#   name                = "${local.names.bastion}-bastion-nic"
#   location            = azurerm_resource_group.main.location
#   resource_group_name = azurerm_resource_group.main.name

#   ip_configuration {
#     name                          = "${local.names.bastion}-ip"
#     subnet_id                     = azurerm_subnet.bastionsubnet.id
#     private_ip_address_allocation = "Dynamic"
#     public_ip_address_id = azurerm_public_ip.bastion_host_publicip.id 
#   }
# }

# # Resource-3: Azure Linux Virtual Machine - Bastion Host
# resource "azurerm_linux_virtual_machine" "bastion_host_linuxvm" {
#   name = "${local.names.bastion}"
#   #computer_name = "bastionlinux-vm"  # Hostname of the VM (Optional)
#   resource_group_name = azurerm_resource_group.main.name
#   location = azurerm_resource_group.main.location
#   size = "Standard_DS1_v2"
#   admin_username = var.admin_username
#   network_interface_ids = [ azurerm_network_interface.bastion_host_linuxvm_nic.id ]
#   admin_ssh_key {
#     username = var.admin_username
#     public_key = tls_private_key.main[0].public_key_openssh
#   }
#   os_disk {
#     caching = "ReadWrite"
#     storage_account_type = "Standard_LRS"
#   }
#   source_image_reference {
#     publisher = "Canonical"
#     offer = "UbuntuServer"
#     sku = "22.04-LTS"
#     version = "latest"
#   }
# }



# # Azure Bastion Service - Resources
# resource "azurerm_virtual_network" "bastion" {
#   name                = "${local.names.aks}-abh-vnet"
#   resource_group_name = azurerm_resource_group.main.name
#   address_space       = var.bastion_addr_space
#   location            = azurerm_resource_group.main.location
# }

# ## Resource-1: Azure Bastion Subnet
# resource "azurerm_subnet" "bastion" {
#   name                 = "${local.names.aks}-abh-subnet"
#   resource_group_name  = azurerm_resource_group.main.name
#   virtual_network_name = azurerm_virtual_network.vnet.name
#   address_prefixes     = var.bastion_service_address_prefixes
# }

# # Resource-2: Azure Bastion Public IP
# resource "azurerm_public_ip" "bastion_service_publicip" {
#   name                = "${local.names.bastion}-pip"
#   location            = azurerm_resource_group.main.location
#   resource_group_name = azurerm_resource_group.main.name
#   allocation_method   = "Static"
#   sku                 = "Standard"
# }

# # Resource-3: Azure Bastion Service Host
# resource "azurerm_bastion_host" "bastion_host" {
#   name                = "${local.resource_name_prefix}-bastion-service"
#   location            = azurerm_resource_group.main.location
#   resource_group_name = azurerm_resource_group.main.name

#   ip_configuration {
#     name                 = "configuration"
#     subnet_id            = azurerm_subnet.bastion.id
#   #  public_ip_address_id = azurerm_public_ip.bastion_service_publicip.id
#   }
# }

# resource "azurerm_virtual_network_peering" "bta" {
#   name                      = "peer1to2"
#   resource_group_name       = data.azurerm_resource_group.main.name
#   virtual_network_name      = azurerm_virtual_network.bastion.name
#   remote_virtual_network_id = azurerm_virtual_network.main-2.id
# }

# resource "azurerm_virtual_network_peering" "atb" {
#   name                      = "peer2to1"
#   resource_group_name       = azurerm_resource_group.main.name
#   virtual_network_name      = azurerm_virtual_network.main-2.name
#   remote_virtual_network_id = azurerm_virtual_network.main-1.id
# }

