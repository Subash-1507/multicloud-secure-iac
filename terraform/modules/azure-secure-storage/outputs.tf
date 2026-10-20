output "key_vault_name" {
  description = "Name of the Key Vault holding the customer-managed key."
  value       = azurerm_key_vault.this.name
}

output "cmk_versionless_id" {
  description = "Versionless key ID: services using it pick up rotated key versions automatically."
  value       = azurerm_key_vault_key.cmk.versionless_id
}

output "storage_account_name" {
  description = "Storage account encrypted with the customer-managed key."
  value       = azurerm_storage_account.data.name
}
