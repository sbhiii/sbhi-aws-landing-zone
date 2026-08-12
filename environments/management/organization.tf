resource "aws_organizations_organization" "organization" {
  aws_service_access_principals = ["cloudtrail.amazonaws.com", "iam.amazonaws.com"]
  enabled_policy_types          = ["SERVICE_CONTROL_POLICY"]
  feature_set                   = "ALL"
  return_organization_only      = null
}

resource "aws_iam_organizations_features" "organization-features" {
  enabled_features = [
    "RootCredentialsManagement",
    "RootSessions"
  ]

  depends_on = [aws_organizations_organization.organization]
}

