variable "bucket_name" {
  description = "S3 Bucket name for storing Terraform state (must be globally unique)"
  type        = string
}

variable "region" {
  description = "Region of the AWS Management account"
  type        = string
  default     = "eu-west-1"
}
