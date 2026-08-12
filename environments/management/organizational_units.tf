# Security
resource "aws_organizations_organizational_unit" "security" {
  name      = "Security"
  parent_id = aws_organizations_organization.organization.roots[0].id
  tags = {
    "Environment" : "Security"
  }
}


# Infrastructure (shared services)
resource "aws_organizations_organizational_unit" "infrastructure" {
  name      = "Infrastructure"
  parent_id = aws_organizations_organization.organization.roots[0].id
  tags = {
    "Environment" : "Infrastructure"
  }
}


# Workloads
resource "aws_organizations_organizational_unit" "workloads" {
  name      = "Workloads"
  parent_id = aws_organizations_organization.organization.roots[0].id
  tags = {
    "Environment" : "Workloads"
  }
}

resource "aws_organizations_organizational_unit" "prod" {
  name      = "Prod"
  parent_id = aws_organizations_organizational_unit.workloads.id
  tags = {
    "Environment" : "Prod"
  }
}

resource "aws_organizations_organizational_unit" "nonprod" {
  name      = "NonProd"
  parent_id = aws_organizations_organizational_unit.workloads.id
  tags = {
    "Environment" : "NonProd"
  }
}


# Sandbox
resource "aws_organizations_organizational_unit" "sandbox" {
  name      = "Sandbox"
  parent_id = aws_organizations_organization.organization.roots[0].id
  tags = {
    "Environment" : "Sandbox"
  }
}
