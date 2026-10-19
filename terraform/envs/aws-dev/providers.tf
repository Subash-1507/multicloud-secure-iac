provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Project     = "multicloud-secure-iac"
      Environment = "dev"
      ManagedBy   = "terraform"
      Owner       = var.owner
    }
  }
}
