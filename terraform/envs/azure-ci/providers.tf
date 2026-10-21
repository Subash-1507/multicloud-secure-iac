provider "azurerm" {
  features {}

  # The provider talks to Blob storage with Entra ID, never with account keys
  storage_use_azuread = true
}
