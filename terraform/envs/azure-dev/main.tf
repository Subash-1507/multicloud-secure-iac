locals {
  tags = {
    project     = "multicloud-secure-iac"
    environment = "dev"
    managed_by  = "terraform"
    owner       = var.owner
  }
}

resource "azurerm_resource_group" "this" {
  name     = "rg-msi-dev"
  location = var.location
  tags     = local.tags
}
