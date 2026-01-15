# https://developer.hashicorp.com/terraform/language/backend#partial-configuration
terraform {
  backend "s3" {
    profile = ""
    region  = ""
    bucket  = ""
    key     = ""
  }
}
