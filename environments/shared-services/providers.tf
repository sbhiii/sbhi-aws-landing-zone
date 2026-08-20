provider "aws" {
  region              = var.region
  allowed_account_ids = [var.shared_services_account_id]

  default_tags {
    tags = {
      Owner      = "sbhi"
      ManagedBy  = "Terraform"
      Repository = "sbhi-aws-landing-zone"
    }
  }
}
