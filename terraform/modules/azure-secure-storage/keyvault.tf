data "azurerm_client_config" "current" {}

locals {
  # Deterministic 6-character suffix keeps globally unique names stable per subscription
  suffix = substr(sha1(data.azurerm_client_config.current.subscription_id), 0, 6)
}

resource "azurerm_key_vault" "this" {
  # checkov:skip=CKV_AZURE_189: Public endpoint kept so Terraform can reach it from Codespaces; the firewall denies everything except listed IPs
  # checkov:skip=CKV2_AZURE_32: No private endpoint in dev (no VNet-connected runner); production would use one
  name                       = "kv-${var.name}-${local.suffix}"
  location                   = var.location
  resource_group_name        = var.resource_group_name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  rbac_authorization_enabled = true
  purge_protection_enabled   = true
  soft_delete_retention_days = 7

  network_acls {
    default_action = "Deny"
    bypass         = "AzureServices" # lets the storage account (a trusted service) reach its key
    ip_rules       = var.allowed_ip_cidrs
  }

  tags = var.tags

  lifecycle {
    prevent_destroy = true # deleting the vault would destroy the key that protects our data
  }
}

# Data-plane role: lets the identity running Terraform create and rotate keys in this vault only
resource "azurerm_role_assignment" "terraform_crypto_officer" {
  scope                = azurerm_key_vault.this.id
  role_definition_name = "Key Vault Crypto Officer"
  principal_id         = data.azurerm_client_config.current.object_id
}

resource "azurerm_key_vault_key" "cmk" {
  # checkov:skip=CKV_AZURE_112: Software-protected key on the Standard tier; HSM-backed keys need Premium and cost per key per month
  name            = "cmk-storage"
  key_vault_id    = azurerm_key_vault.this.id
  key_type        = "RSA"
  key_size        = 3072
  key_opts        = ["wrapKey", "unwrapKey"]
  expiration_date = timeadd(timestamp(), "8760h") # 1 year; the rotation policy renews the key before it expires

  rotation_policy {
    expire_after         = "P1Y"
    notify_before_expiry = "P30D"

    automatic {
      time_before_expiry = "P30D"
    }
  }

  lifecycle {
    prevent_destroy = true              # data encrypted with this key would become unreadable
    ignore_changes  = [expiration_date] # timestamp() changes on every run; rotation manages expiry from here on
  }

  depends_on = [azurerm_role_assignment.terraform_crypto_officer]
}
