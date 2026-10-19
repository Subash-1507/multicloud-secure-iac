# Partial backend config: account-specific values live in backend.hcl (git-ignored).
#   cp backend.hcl.example backend.hcl && terraform init -backend-config=backend.hcl
terraform {
  backend "s3" {
    key          = "aws-dev/terraform.tfstate"
    encrypt      = true
    use_lockfile = true # S3-native locking, no DynamoDB table needed
  }
}
