data "aws_ssoadmin_instances" "this" {}

locals {
  sso_instance_arn  = tolist(data.aws_ssoadmin_instances.this.arns)[0]
  identity_store_id = tolist(data.aws_ssoadmin_instances.this.identity_store_ids)[0]

  sso_accounts = {
    management      = var.management_account_id
    shared_services = aws_organizations_account.sbhi_shared_services.id
  }
}

resource "aws_ssoadmin_permission_set" "administrator" {
  name             = "AdministratorAccess"
  description      = "Full access. Human break-glass and day-to-day admin."
  instance_arn     = local.sso_instance_arn
  session_duration = "PT4H"
}

resource "aws_ssoadmin_managed_policy_attachment" "administrator" {
  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.administrator.arn
  managed_policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

resource "aws_identitystore_group" "administrators" {
  identity_store_id = local.identity_store_id
  display_name      = "Administrators"
  description       = "Full access to all accounts"
}

resource "aws_identitystore_user" "samy" {
  identity_store_id = local.identity_store_id
  user_name         = "samy"
  display_name      = "Samy"

  name {
    given_name  = "Samy"
    family_name = "Bahi"
  }

  emails {
    value   = var.admin_email
    primary = true
  }
}

resource "aws_identitystore_group_membership" "samy_admin" {
  identity_store_id = local.identity_store_id
  group_id          = aws_identitystore_group.administrators.group_id
  member_id         = aws_identitystore_user.samy.user_id
}

resource "aws_ssoadmin_account_assignment" "admin" {
  for_each = local.sso_accounts

  instance_arn       = local.sso_instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.administrator.arn
  principal_id       = aws_identitystore_group.administrators.group_id
  principal_type     = "GROUP"
  target_id          = each.value
  target_type        = "AWS_ACCOUNT"
}
