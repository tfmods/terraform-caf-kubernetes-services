module "bastion" {
  source = "git@ssh.dev.azure.com:v3/swonelab/Modulos_Terraform/terraform-azurerm-bastion" # preferably using git@ssh.dev.azure.com:v3/swonelab/Modulos_Terraform/terraform-azurerm-bastion?ref=<tag>

  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  tags                = azurerm_resource_group.main.tags

  azure_bastion_subnet_id = module.aks_vnet.vnet_subnet_ids["AzureBastionSubnet"]

  depends_on = [
    module.aks_vnet
  ]
}

resource "azurerm_network_interface" "ubuntu" {
  name                = "ubuntu-nic"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = module.aks_vnet.vnet_subnet_ids["linux"]
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.ubuntu.id
  }
}

resource "azurerm_linux_virtual_machine" "ubuntu" {
  name                = "ubuntu-machine"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  size                = "Standard_ds1_v2"
  admin_username      = "adminuser"
  network_interface_ids = [
    azurerm_network_interface.ubuntu.id,
  ]

  admin_ssh_key {
    username   = "adminuser"
    public_key = file("~/.ssh/id_rsa.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts"
    version   = "latest"
  }

}

resource "azurerm_public_ip" "ubuntu" {
  name                = "ubuntu0001publicip1"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  allocation_method   = "Dynamic"

  tags = {
    environment = "Production"
  }
}

resource "azurerm_network_security_group" "ubuntu" {
  name                = "ubuntu-security-group1"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  security_rule {
    name                       = "ssh"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = {
    environment = "Production"
  }
}
resource "azurerm_network_interface_security_group_association" "ubuntu" {
  network_interface_id      = azurerm_network_interface.ubuntu.id
  network_security_group_id = azurerm_network_security_group.ubuntu.id
}