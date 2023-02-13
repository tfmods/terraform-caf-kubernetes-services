locals {

  # Resource type	An abbreviation that represents the type of Azure resource or asset. This component is often used as a prefix or suffix in the name. For more information, see Recommended abbreviations for Azure resource types.
  # Examples: rg, vm

  # Business unit	Top-level division of your company that owns the subscription or workload the resource belongs to. In smaller organizations, this component might represent a single corporate top-level organizational element.
  # Examples: fin, mktg, product, it, corp

  # Application or service name	Name of the application, workload, or service that the resource is a part of.
  # Examples: navigator, emissions, sharepoint, hadoop

  # Subscription purpose	Summary description of the purpose of the subscription that contains the resource. Often broken down by environment or specific workloads.
  # Examples: prod, shared, client

  # Environment	The stage of the development lifecycle for the workload that the resource supports.
  # Examples: prod, dev, qa, stage, test

  # Region	The Azure region where the resource is deployed.
  # Examples: westus, eastus2, westeu, usva, ustx

  naming          = "${var.project}-${var.environment}-${var.location}"
  aad_group_admin = toset(concat(["var.aad_aks_group_ownners", "data.azuread_client_config.main.object_id"]))
  names = {
    aks = "${var.aks_name}${var.project}${var.environment}${var.location}"
    alw = "${var.alw_name}-${local.naming}"
    acr = "${var.aks_name}${var.project}${var.environment}${var.location}acr"
    # aad          = "${var.aad_group_name}-${local.naming}"
    #external_aad = "${var.current_aad_group_name}-${local.naming}"
  }

}

locals {
  kv_id = {
    id = azurerm_key_vault.main[0].id
  }
}

locals {
  default_tags = {
    Environment          = var.environment
    ManagedBy            = "Terraform"
    SolutionName         = "Azure Caf AKS Module"
    Version              = var.solution_version
    DevOpsTeam           = "SoftwareOne DevOps Team"
    SolutionDevelopers   = "Rosthan.silva@softwareone.com"
    Location             = var.location
    SolutionRepo         = "tf-caf-az-k8s-mod"
    Departament          = var.departament
    DepartamentPrincipal = var.departament_principal
    CostCentre           = var.costcentre
    Administrator        = var.resource_admin
  }
}