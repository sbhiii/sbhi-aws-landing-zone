terraform {
  backend "s3" {
    bucket       = "sbhi-management-tfstate"
    key          = "management/terraform.tfstate"
    region       = "eu-west-1"
    encrypt      = true
    use_lockfile = true
  }
}
