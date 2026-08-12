
# Common
variable "region" {
  description = "Region of the AWS Management account"
  type        = string
  default     = "eu-west-1"
}

variable "management_account_id" {
  description = "account ID of the Management account"
  type        = string
}


## Accounts

# sahred-services

variable "shared_services_email" {
  description = "email of the AWS shared account"
  type        = string
}

