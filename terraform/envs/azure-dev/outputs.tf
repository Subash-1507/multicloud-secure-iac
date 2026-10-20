output "resource_group" {
  description = "Resource group that holds the dev workload."
  value       = azurerm_resource_group.this.name
}
