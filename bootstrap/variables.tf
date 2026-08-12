variable "bucket_name" {
  description = "S3 Bucket name for storing Terraform state (must be globally unique)"
  type        = string
}

variable "region" {
  description = "Region of the AWS Management account"
  type        = string
  default     = "eu-west-1"
}

variable "management_account_id" {
  description = "account ID of the Management account"
  type        = string
}
