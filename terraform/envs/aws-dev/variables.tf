variable "region" {
  description = "AWS region for this environment."
  type        = string
  default     = "ap-south-1"
}

variable "owner" {
  description = "Owner tag applied to every resource."
  type        = string
}

variable "data_bucket_name" {
  description = "Globally unique name for the encrypted data bucket."
  type        = string
}
