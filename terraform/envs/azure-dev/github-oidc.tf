# GitHub Actions authenticates to Azure with OIDC: no client secrets or keys exist anywhere.
data "azurerm_client_config" "current" {}

locals {
  github_oidc_issuer   = "https://token.actions.githubusercontent.com"
  github_oidc_audience = ["api://AzureADTokenExchange"]
  # State container ID is built as a string, so CI needs no read access to the state resource group
  tfstate_container_id = "/subscriptions/${data.azurerm_client_config.current.subscription_id}/resourceGroups/${var.tfstate_resource_group_name}/providers/Microsoft.Storage/storageAccounts/${var.tfstate_storage_account_name}/blobServices/default/containers/tfstate"
}

# ---------------------------------------------------------------- plan (pull requests)
# Anyone can open a PR on a public repo, so PRs only ever get read access.
resource "azurerm_user_assigned_identity" "gha_plan" {
  name                = "id-msi-gha-plan"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  tags                = local.tags
}

resource "azurerm_federated_identity_credential" "gha_plan_pr" {
  name                      = "github-pull-request"
  user_assigned_identity_id = azurerm_user_assigned_identity.gha_plan.id
  issuer                    = local.github_oidc_issuer
  audience                  = local.github_oidc_audience
  subject                   = "repo:${var.github_repository}:pull_request"
}

resource "azurerm_role_assignment" "gha_plan_reader" {
  scope                = azurerm_resource_group.this.id
  role_definition_name = "Reader"
  principal_id         = azurerm_user_assigned_identity.gha_plan.principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_role_assignment" "gha_plan_state" {
  scope                = local.tfstate_container_id
  role_definition_name = "Storage Blob Data Contributor" # plan reads state and takes a lock (blob lease)
  principal_id         = azurerm_user_assigned_identity.gha_plan.principal_id
  principal_type       = "ServicePrincipal"
}

# ---------------------------------------------------------------- apply (azure-dev environment)
# Only usable from the azure-dev GitHub environment, which requires a human approval.
resource "azurerm_user_assigned_identity" "gha_apply" {
  name                = "id-msi-gha-apply"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  tags                = local.tags
}

resource "azurerm_federated_identity_credential" "gha_apply_env" {
  name                      = "github-env-azure-dev"
  user_assigned_identity_id = azurerm_user_assigned_identity.gha_apply.id
  issuer                    = local.github_oidc_issuer
  audience                  = local.github_oidc_audience
  subject                   = "repo:${var.github_repository}:environment:azure-dev"
}

resource "azurerm_role_assignment" "gha_apply_contributor" {
  scope                = azurerm_resource_group.this.id
  role_definition_name = "Contributor"
  principal_id         = azurerm_user_assigned_identity.gha_apply.principal_id
  principal_type       = "ServicePrincipal"
}

# Terraform manages the Key Vault role assignments inside this resource group.
# ABAC condition: this identity may only grant or remove the roles below, so it can never escalate itself to Owner.
data "azurerm_role_definition" "delegable" {
  for_each = toset(["Key Vault Crypto Officer", "Key Vault Crypto Service Encryption User"])
  name     = each.value
}

locals {
  delegable_role_ids = join(", ", [for r in data.azurerm_role_definition.delegable : r.role_definition_id])
}

resource "azurerm_role_assignment" "gha_apply_rbac_admin" {
  scope                = azurerm_resource_group.this.id
  role_definition_name = "Role Based Access Control Administrator"
  principal_id         = azurerm_user_assigned_identity.gha_apply.principal_id
  principal_type       = "ServicePrincipal"
  condition_version    = "2.0"
  condition            = <<-EOT
    (
      (
        !(ActionMatches{'Microsoft.Authorization/roleAssignments/write'})
      )
      OR
      (
        @Request[Microsoft.Authorization/roleAssignments:RoleDefinitionId] ForAnyOfAnyValues:GuidEquals {${local.delegable_role_ids}}
      )
    )
    AND
    (
      (
        !(ActionMatches{'Microsoft.Authorization/roleAssignments/delete'})
      )
      OR
      (
        @Resource[Microsoft.Authorization/roleAssignments:RoleDefinitionId] ForAnyOfAnyValues:GuidEquals {${local.delegable_role_ids}}
      )
    )
  EOT
}

resource "azurerm_role_assignment" "gha_apply_state" {
  scope                = local.tfstate_container_id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_user_assigned_identity.gha_apply.principal_id
  principal_type       = "ServicePrincipal"
}
