variable "name" {
  description = "Short workload name used in resource names (3-10 lowercase letters or digits)."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]{3,10}$", var.name))
    error_message = "Use 3-10 lowercase letters or digits."
  }
}

variable "location" {
  description = "Azure region for every resource in this module."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group that holds the vault and storage."
  type        = string
}

variable "allowed_ip_cidrs" {
  description = "Public IPs in CIDR form allowed through the firewalls, e.g. your current Codespaces IP as x.x.x.x/32."
  type        = list(string)

  validation {
    condition     = length(var.allowed_ip_cidrs) > 0 && alltrue([for c in var.allowed_ip_cidrs : can(cidrhost(c, 0)) && !startswith(c, "0.0.0.0")])
    error_message = "Give at least one valid CIDR, and never 0.0.0.0/0."
  }
}

variable "tags" {
  description = "Tags applied to every resource."
  type        = map(string)
  default     = {}
}

variable "key_vault_admins" {
  description = "Identities allowed to create and rotate keys: map of a stable name to an Entra ID object ID."
  type        = map(string)

  validation {
    condition     = length(var.key_vault_admins) > 0
    error_message = "Give at least one Key Vault admin."
  }
}
