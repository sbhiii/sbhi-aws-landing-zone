resource "aws_organizations_account" "sbhi-shared-services" {
  name                       = "sbhi-shared-services"
  email                      = var.shared-services-email
  parent_id                  = aws_organizations_organizational_unit.infrastructure.id
  iam_user_access_to_billing = "ALLOW"
}
