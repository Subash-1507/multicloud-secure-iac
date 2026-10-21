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

module "secure_storage" {
  source = "../../modules/azure-secure-storage"

  name                = "msidev"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  allowed_ip_cidrs    = var.allowed_ip_cidrs
  key_vault_admins = {
    subash       = var.admin_object_id
    github_apply = azurerm_user_assigned_identity.gha_apply.principal_id
  }
  tags = local.tags
}
