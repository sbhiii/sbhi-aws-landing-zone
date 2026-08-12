provider "aws" {
  region              = var.region
  allowed_account_ids = [var.management_account_id]

  default_tags {
    tags = {
      Owner      = "sbhi"
      ManagedBy  = "Terraform"
      Repository = "sbhi-aws-landing-zone"
    }
  }
}
