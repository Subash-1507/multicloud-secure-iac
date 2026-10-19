output "bucket_id" {
  description = "Name of the data bucket."
  value       = aws_s3_bucket.data.id
}

output "bucket_arn" {
  description = "ARN of the data bucket."
  value       = aws_s3_bucket.data.arn
}

output "kms_key_arn" {
  description = "ARN of the customer-managed KMS key that encrypts the data bucket."
  value       = aws_kms_key.this.arn
}

output "log_bucket_id" {
  description = "Name of the server access log bucket."
  value       = aws_s3_bucket.logs.id
}
