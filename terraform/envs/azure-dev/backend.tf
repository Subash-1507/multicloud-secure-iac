# Partial backend config: account-specific values live in backend.hcl (git-ignored).
#   cp backend.hcl.example backend.hcl && terraform init -backend-config=backend.hcl
terraform {
  backend "azurerm" {
    key              = "azure-dev/terraform.tfstate"
    use_azuread_auth = true # Entra ID + RBAC; the storage account has shared keys disabled
  }
}
