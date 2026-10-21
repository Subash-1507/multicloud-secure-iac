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

variable "github_repository" {
  description = "GitHub repository (owner/name) whose workflows may sign in to Azure."
  type        = string
  default     = "Subash-1507/multicloud-secure-iac"
}

variable "workload_resource_group_name" {
  description = "Resource group that CI deploys into (created by the azure-dev root)."
  type        = string
  default     = "rg-msi-dev"
}

variable "key_vault_name" {
  description = "Key Vault in the workload resource group whose keys CI manages."
  type        = string
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
