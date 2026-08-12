resource "aws_organizations_account" "sbhi_shared_services" {
  name                       = "sbhi-shared-services"
  email                      = var.shared_services_email
  parent_id                  = aws_organizations_organizational_unit.infrastructure.id
  iam_user_access_to_billing = "ALLOW"
  close_on_deletion          = false

  lifecycle {
    prevent_destroy = true
  }
}
