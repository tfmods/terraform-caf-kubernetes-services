data "azuread_group" "main" {
  display_name = "k8s-admin"
}

resource "azurerm_resource_group" "main" {
  name     = "k8s-lab-rg"
  location = "eastus"

}

resource "random_password" "password" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

module "vnet" {
  source              = "Azure/vnet/azurerm"
  version             = "~> 2.6.0"
  resource_group_name = azurerm_resource_group.main.name
  vnet_name           = "k8s-lab"
  address_space       = var.address_space
  subnet_prefixes     = var.subnet_prefixes
  subnet_names        = var.subnet_names

  tags = {
    env   = var.env
    group = var.group
    app   = var.app
  }
  depends_on = [azurerm_resource_group.main]
}


module "aks-caf" {
  source = "../.."
}

