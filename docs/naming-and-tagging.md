# Naming and tagging

## Principles

Names are chosen so that the identifier tells you what a thing is and where it
sits, without needing to look it up. Where AWS imposes a convention, the AWS
convention wins; where Terraform has an idiom, the Terraform idiom wins.

## AWS accounts

Format: `sbhi-<purpose>`

| Example | Notes |
| --- | --- |
| `sbhi-management` | The organization management account. |
| `sbhi-shared-services` | Shared infrastructure. |
| `sbhi-log-archive` | Planned. |
| `sbhi-security-tooling` | Planned. |

Lowercase, hyphen-separated, prefixed with the organization short name so an
account is identifiable in a list that spans organizations. The account switcher
and billing console both show bare names.

Account root emails follow `sbhi-<purpose>@<domain>` on an aliasing domain, one
unique address per account. AWS requires uniqueness across all accounts
everywhere, and the address cannot be changed without replacing the account, so
use an alias you control rather than a personal mailbox.

## Organizational units

Format: `PascalCase`, singular where it reads naturally.

`Security`, `Infrastructure`, `Workloads`, `Prod`, `NonProd`, `Sandbox`,
`Suspended`

OU names appear in the console and in policy documents, where PascalCase is the
AWS house style. They deliberately differ in case from account names so that a
bare identifier is unambiguous about which kind of thing it refers to.

## Terraform identifiers

**`snake_case` for everything**: resource labels, variables, locals, outputs.
HCL permits hyphens in identifiers, but `snake_case` is the community idiom and
mixing the two is the kind of inconsistency that spreads.

```hcl
resource "aws_organizations_account" "sbhi_shared_services" { ... }
variable "shared_services_email" { ... }
```

Note that the Terraform label uses underscores while the `name` argument uses the
account naming convention:

```hcl
resource "aws_organizations_account" "sbhi_shared_services" {
  name = "sbhi-shared-services"
}
```

Renaming a Terraform label changes its state address. Always pair a rename with a
`moved` block so Terraform rewrites the address instead of destroying and
recreating the resource:

```hcl
moved {
  from = aws_organizations_account.sbhi-shared-services
  to   = aws_organizations_account.sbhi_shared_services
}
```

The `moved` block can be deleted once the change has been applied everywhere the
state is used.

## Files

One concern per file, named for the concern:

```
organization.tf           The organization itself and its features
organizational_units.tf   OU hierarchy
accounts.tf               Member accounts
identity_center.tf        SSO instance lookup, permission sets, groups, assignments
providers.tf              Provider configuration and default tags
variables.tf              Input variables
versions.tf               Terraform and provider version constraints
backend.tf                Remote state configuration
```

This keeps each file small enough to hold in your head, and makes a diff's
subject obvious from the filename alone.

## Identity Center

| Thing | Convention | Example |
| --- | --- | --- |
| Permission sets | Match the AWS managed policy they wrap, where they wrap one | `AdministratorAccess` |
| Groups | Plural role name | `Administrators` |
| Users | Lowercase first name or `firstname.lastname` | `samy` |

Permission sets that do not correspond to a managed policy should be named for
the job rather than the permissions: `BillingReadOnly`, not `PolicyBundle3`.

## Tagging

Three tags are applied automatically to every taggable resource, via
`default_tags` on the provider:

| Tag | Value | Purpose |
| --- | --- | --- |
| `Owner` | `sbhi` | Who is accountable for the resource. |
| `ManagedBy` | `Terraform` | Signals that manual changes will be reverted. |
| `Repository` | `sbhi-aws-landing-zone` | Where the defining code lives. |

`Repository` is the most valuable of the three. When you find an unfamiliar
resource in the console two years from now, it tells you which repository to open.

Because these come from `default_tags`, they do not need to be repeated on
individual resources. Adding a tag to the provider applies it to everything on
the next apply.

### Resource-level tags

Organizational units additionally carry an `Environment` tag matching their name.

**Known gap:** this is applied uniformly, which makes it meaningless on the OUs
that are not environments. `Environment = Security` on the Security OU conveys
nothing, whereas `Environment = Prod` on the Prod OU is genuinely useful. The tag
should either be narrowed to `Prod` and `NonProd`, or replaced with a `Purpose`
tag that is meaningful everywhere. It is documented here rather than quietly
tidied because the fix changes existing infrastructure.

### Tags to add as the estate grows

| Tag | When it becomes worth it |
| --- | --- |
| `CostCentre` or `Project` | As soon as more than one project shares an account. |
| `DataClassification` | Once anything holds personal or sensitive data. |
| `Environment` on workload resources | Once workload accounts exist. |

A tag policy (`TAG_POLICY` in `enabled_policy_types`) can enforce these once they
are agreed. Enforcing a convention that is still changing is premature; enforcing
one that has settled is cheap.
