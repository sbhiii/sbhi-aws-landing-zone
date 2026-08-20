terraform {
  backend "s3" {
    bucket       = "sbhi-management-tfstate"
    key          = "shared-services/terraform.tfstate"
    region       = "eu-west-1"
    encrypt      = true
    use_lockfile = true

    # This repository keeps all of its state in the management account, whichever
    # account a root module targets. The bucket policy grants nothing to
    # sbhi-shared-services, so the backend has to authenticate as the management
    # account while the provider above authenticates as shared services. Without
    # this the backend would try to read the bucket with shared services
    # credentials and fail on init.
    profile = "sbhi-management"
  }
}
