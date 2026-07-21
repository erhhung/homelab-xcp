terraform {
  required_version = ">= 1.11"

  # https://www.terraform.io/language/providers/requirements
  required_providers {
    xenorchestra = {
      source  = "vatesfr/xenorchestra"
      version = "~> 0.39.0"
    }
  }
}

# https://registry.terraform.io/providers/vatesfr/xenorchestra/latest/docs
provider "xenorchestra" {
  url      = "wss://${var.xenorchestra.host}"
  username = var.xenorchestra.username
  password = var.xenorchestra.password
}
