output "data_bucket" {
  description = "Encrypted data bucket name."
  value       = module.secure_storage.bucket_id
}

output "kms_key_arn" {
  description = "Customer-managed KMS key protecting the data bucket."
  value       = module.secure_storage.kms_key_arn
}
