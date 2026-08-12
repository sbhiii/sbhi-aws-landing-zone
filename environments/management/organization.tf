resource "aws_organizations_organization" "organization" {
  aws_service_access_principals = ["cloudtrail.amazonaws.com",
    "iam.amazonaws.com",
    "sso.amazonaws.com",
    "config.amazonaws.com",
    "guardduty.amazonaws.com",
    "securityhub.amazonaws.com",
    "ram.amazonaws.com",
    "member.org.stacksets.cloudformation.amazonaws.com"
  ]
  enabled_policy_types = ["SERVICE_CONTROL_POLICY"]
  feature_set          = "ALL"
}

resource "aws_iam_organizations_features" "organization_features" {
  enabled_features = [
    "RootCredentialsManagement",
    "RootSessions"
  ]

  depends_on = [aws_organizations_organization.organization]
}

