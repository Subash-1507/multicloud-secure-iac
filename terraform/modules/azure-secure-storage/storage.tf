# Identity the storage account uses to reach its key: no password or secret to manage
resource "azurerm_user_assigned_identity" "storage" {
  name                = "id-${var.name}-storage"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

# Least privilege: this identity may only wrap/unwrap with this one key
resource "azurerm_role_assignment" "storage_key_user" {
  scope                = azurerm_key_vault_key.cmk.resource_versionless_id
  role_definition_name = "Key Vault Crypto Service Encryption User"
  principal_id         = azurerm_user_assigned_identity.storage.principal_id
}

resource "azurerm_storage_account" "data" {
  # checkov:skip=CKV_AZURE_59: Public endpoint kept so Terraform can reach it from Codespaces; firewall default Deny allows only listed IPs, and Entra ID auth is required
  # checkov:skip=CKV2_AZURE_33: No private endpoint in dev (no VNet-connected runner); production would use one
  # checkov:skip=CKV_AZURE_33: Not applicable: this account stores blobs only, the Queue service is unused
  # checkov:skip=CKV_AZURE_206: Accepted for dev: ZRS (3 zones) chosen over geo-replication; no cross-region DR requirement and data stays in Southeast Asia. Production would use GZRS
  # checkov:skip=CKV_AZURE_43: False positive: Checkov cannot resolve the interpolated name; it renders as st<name><6 hex>, lowercase alphanumeric and under 24 chars
  name                              = "st${var.name}${local.suffix}"
  resource_group_name               = var.resource_group_name
  location                          = var.location
  account_kind                      = "StorageV2"
  account_tier                      = "Standard"
  account_replication_type          = "ZRS" # 3 copies across availability zones in the region
  min_tls_version                   = "TLS1_2"
  https_traffic_only_enabled        = true
  shared_access_key_enabled         = false # no account keys and no key-signed SAS: Entra ID + RBAC only
  default_to_oauth_authentication   = true  # the portal uses Entra ID by default too
  allow_nested_items_to_be_public   = false
  cross_tenant_replication_enabled  = false
  local_user_enabled                = false
  infrastructure_encryption_enabled = true # second encryption layer at the infrastructure level

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.storage.id]
  }

  # Envelope encryption: the storage data key is wrapped with OUR key. Versionless ID = follows auto-rotation.
  customer_managed_key {
    key_vault_key_id          = azurerm_key_vault_key.cmk.versionless_id
    user_assigned_identity_id = azurerm_user_assigned_identity.storage.id
  }

  blob_properties {
    versioning_enabled = true

    delete_retention_policy {
      days = 14
    }

    container_delete_retention_policy {
      days = 14
    }
  }

  network_rules {
    default_action = "Deny"
    bypass         = ["AzureServices"]
    ip_rules       = [for c in var.allowed_ip_cidrs : trimsuffix(c, "/32")] # storage rejects /32; it wants a bare IP
  }

  sas_policy {
    expiration_period = "00.01:00:00" # any SAS must expire within 1 hour
  }

  tags = var.tags

  lifecycle {
    prevent_destroy = true # holds data; deleting it must be a deliberate code change
  }

  depends_on = [azurerm_role_assignment.storage_key_user]
}
