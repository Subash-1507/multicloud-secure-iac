output "resource_group" {
  description = "Resource group that holds the dev workload."
  value       = azurerm_resource_group.this.name
}

output "key_vault_name" {
  description = "Key Vault holding the customer-managed key."
  value       = module.secure_storage.key_vault_name
}

output "storage_account_name" {
  description = "Storage account encrypted with the customer-managed key."
  value       = module.secure_storage.storage_account_name
}

output "gha_plan_client_id" {
  description = "Client ID for the GitHub Actions plan identity (not a secret)."
  value       = azurerm_user_assigned_identity.gha_plan.client_id
}

output "gha_apply_client_id" {
  description = "Client ID for the GitHub Actions apply identity (not a secret)."
  value       = azurerm_user_assigned_identity.gha_apply.client_id
}
