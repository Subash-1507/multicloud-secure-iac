variable "location" {
  description = "Azure region. Limited to the regions the Azure for Students policy allows."
  type        = string
  default     = "southeastasia"

  validation {
    condition     = contains(["southeastasia", "uaenorth", "koreacentral", "malaysiawest", "austriaeast"], var.location)
    error_message = "This subscription's policy only allows southeastasia, uaenorth, koreacentral, malaysiawest or austriaeast."
  }
}

variable "owner" {
  description = "Owner tag applied to every resource."
  type        = string
}

variable "allowed_ip_cidrs" {
  description = "Public IPs in CIDR form allowed through the Key Vault and storage firewalls."
  type        = list(string)
}

variable "admin_object_id" {
  description = "Entra ID object ID of the human admin who may manage Key Vault keys."
  type        = string
}

variable "github_repository" {
  description = "GitHub repository (owner/name) whose workflows may sign in to Azure."
  type        = string
  default     = "Subash-1507/multicloud-secure-iac"
}

variable "tfstate_resource_group_name" {
  description = "Resource group of the Terraform state storage account."
  type        = string
  default     = "rg-msi-tfstate"
}

variable "tfstate_storage_account_name" {
  description = "Name of the Terraform state storage account (created during bootstrap)."
  type        = string
}
