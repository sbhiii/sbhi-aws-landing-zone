
# Common
variable "region" {
  description = "Region of the AWS Management account"
  type        = string
  default     = "eu-west-1"
}


## Accounts

# sahred-services

variable "shared-services-email" {
  description = "email of the AWS shared account"
  type        = string
}

