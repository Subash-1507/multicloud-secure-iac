output "gha_plan_client_id" {
  description = "Client ID for the GitHub Actions plan identity (stored as the AZURE_CLIENT_ID_PLAN secret)."
  value       = azurerm_user_assigned_identity.gha_plan.client_id
}

output "gha_apply_client_id" {
  description = "Client ID for the GitHub Actions apply identity (stored as the AZURE_CLIENT_ID_APPLY secret)."
  value       = azurerm_user_assigned_identity.gha_apply.client_id
}
