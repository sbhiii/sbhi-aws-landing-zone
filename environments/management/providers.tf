provider "aws" {
  region = var.region

  default_tags {
    tags = {
      "Owner" : "sbhi"
      "ManagedBy" : "Terraform"
      "Repository" : "sbhi-aws-landing-zone"
    }
  }
}
