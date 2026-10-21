# CI identities for GitHub Actions, kept apart from the workload they deploy.
# Only a human applies this root: CI has no role on rg-msi-ci, so a pipeline can never change its own access.
# GitHub Actions authenticates with OIDC: no client secrets or keys exist anywhere.
data "azurerm_client_config" "current" {}

data "azurerm_resource_group" "workload" {
  name = var.workload_resource_group_name
}

data "azurerm_key_vault" "workload" {
  name                = var.key_vault_name
  resource_group_name = data.azurerm_resource_group.workload.name
}

locals {
  tags = {
    project     = "multicloud-secure-iac"
    environment = "ci"
    managed_by  = "terraform"
    owner       = var.owner
  }

  github_oidc_issuer   = "https://token.actions.githubusercontent.com"
  github_oidc_audience = ["api://AzureADTokenExchange"]
  # State container ID is built as a string, so CI needs no read access to the state resource group
  tfstate_container_id = "/subscriptions/${data.azurerm_client_config.current.subscription_id}/resourceGroups/${var.tfstate_resource_group_name}/providers/Microsoft.Storage/storageAccounts/${var.tfstate_storage_account_name}/blobServices/default/containers/tfstate"
}

resource "azurerm_resource_group" "ci" {
  name     = "rg-msi-ci"
  location = var.location
  tags     = local.tags
}

# ---------------------------------------------------------------- plan (pull requests)
# Anyone can open a PR on a public repo, so PRs only ever get read access.
resource "azurerm_user_assigned_identity" "gha_plan" {
  name                = "id-msi-gha-plan"
  location            = azurerm_resource_group.ci.location
  resource_group_name = azurerm_resource_group.ci.name
  tags                = local.tags
}

resource "azurerm_federated_identity_credential" "gha_plan_pr" {
  name                      = "github-pull-request"
  user_assigned_identity_id = azurerm_user_assigned_identity.gha_plan.id
  issuer                    = local.github_oidc_issuer
  audience                  = local.github_oidc_audience
  subject                   = "${var.github_oidc_subject_prefix}:pull_request"
}

resource "azurerm_role_assignment" "gha_plan_reader" {
  scope                = data.azurerm_resource_group.workload.id
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
# Only usable from the azure-dev GitHub environment, which requires a human approval and runs only from main.
resource "azurerm_user_assigned_identity" "gha_apply" {
  name                = "id-msi-gha-apply"
  location            = azurerm_resource_group.ci.location
  resource_group_name = azurerm_resource_group.ci.name
  tags                = local.tags
}

resource "azurerm_federated_identity_credential" "gha_apply_env" {
  name                      = "github-env-azure-dev"
  user_assigned_identity_id = azurerm_user_assigned_identity.gha_apply.id
  issuer                    = local.github_oidc_issuer
  audience                  = local.github_oidc_audience
  subject                   = "${var.github_oidc_subject_prefix}:environment:azure-dev"
}

resource "azurerm_role_assignment" "gha_apply_contributor" {
  scope                = data.azurerm_resource_group.workload.id
  role_definition_name = "Contributor" # NOSONAR(terraform:S6381): one RG, approval-gated azure-dev env only; Contributor cannot grant roles and RBAC Admin is ABAC-limited to the Key Vault roles
  principal_id         = azurerm_user_assigned_identity.gha_apply.principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_role_assignment" "gha_apply_state" {
  scope                = local.tfstate_container_id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_user_assigned_identity.gha_apply.principal_id
  principal_type       = "ServicePrincipal"
}

# Data plane: Terraform reads and rotates the customer-managed key.
resource "azurerm_role_assignment" "gha_apply_crypto_officer" {
  scope                = data.azurerm_key_vault.workload.id
  role_definition_name = "Key Vault Crypto Officer"
  principal_id         = azurerm_user_assigned_identity.gha_apply.principal_id
  principal_type       = "ServicePrincipal"
}

# Terraform manages the Key Vault role assignments inside the workload resource group.
# ABAC condition: this identity may only grant or remove the roles below, so it can never escalate itself to Owner.
data "azurerm_role_definition" "delegable" {
  for_each = toset(["Key Vault Crypto Officer", "Key Vault Crypto Service Encryption User"])
  name     = each.value
}

locals {
  delegable_role_ids = join(", ", [for r in data.azurerm_role_definition.delegable : r.role_definition_id])
}

resource "azurerm_role_assignment" "gha_apply_rbac_admin" {
  scope                = data.azurerm_resource_group.workload.id
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
