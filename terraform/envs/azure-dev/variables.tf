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
