variable "name" {
  description = "Globally unique name for the data bucket. The access-log bucket gets the suffix -access-logs."
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9-]{1,49}[a-z0-9]$", var.name))
    error_message = "Use 3-51 lowercase letters, digits or hyphens (51 leaves room for the -access-logs suffix)."
  }
}

variable "noncurrent_version_expiration_days" {
  description = "Days to keep previous object versions before they are deleted."
  type        = number
  default     = 30

  validation {
    condition     = var.noncurrent_version_expiration_days >= 1
    error_message = "Must be at least 1 day."
  }
}

variable "access_log_retention_days" {
  description = "Days to keep S3 server access logs."
  type        = number
  default     = 90
}

variable "kms_deletion_window_days" {
  description = "Waiting period before a scheduled KMS key deletion completes."
  type        = number
  default     = 30

  validation {
    condition     = var.kms_deletion_window_days >= 7 && var.kms_deletion_window_days <= 30
    error_message = "AWS allows 7 to 30 days."
  }
}

variable "force_destroy" {
  description = "Let terraform destroy delete non-empty buckets. Only for throwaway dev environments."
  type        = bool
  default     = false
}

variable "tags" {
  description = "Extra tags for every resource (provider default_tags are applied too)."
  type        = map(string)
  default     = {}
}
