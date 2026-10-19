module "secure_storage" {
  source = "../../modules/aws-secure-storage"

  name          = var.data_bucket_name
  force_destroy = true # dev only: lets terraform destroy clean up; keep false in prod
}
