output "resource_group" {
  description = "Resource group that holds the dev workload."
  value       = azurerm_resource_group.this.name
}

output "key_vault_name" {
  description = "Key Vault holding the customer-managed key."
  value       = module.secure_storage.key_vault_name
}
