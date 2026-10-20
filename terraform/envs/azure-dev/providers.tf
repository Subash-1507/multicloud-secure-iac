provider "azurerm" {
  features {
    key_vault {
      # Purge protection forbids purging; keep soft-deleted items recoverable instead
      purge_soft_delete_on_destroy       = false
      purge_soft_deleted_keys_on_destroy = false
      recover_soft_deleted_key_vaults    = true
      recover_soft_deleted_keys          = true
    }
  }

  # The provider talks to Blob storage with Entra ID, never with account keys
  storage_use_azuread = true
}
