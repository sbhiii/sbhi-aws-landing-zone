# Decisions

Each significant choice, the alternatives considered, and the reasoning. Recorded
so that a future reader, including a future version of the author, can tell the
difference between a deliberate decision and an accident.

## 1. Bootstrap state is local and manual

`bootstrap/` creates the S3 bucket that holds all other Terraform state. Its own
state file is local and it is applied by hand. It will not be wired into CI.

**Alternative considered:** migrating bootstrap's state into the bucket it
creates, using `terraform init -migrate-state` after the first apply.

**Why local:** the module manages six resources, all keyed by the bucket name. If
the state file is lost, recovery is six `import` blocks and one apply. See
[the recovery runbook](runbooks/bootstrap-state-recovery.md). No data is at risk
and there is no downtime. Weighed against that, the migration buys little.

**Consequences:** bootstrap defines the boundary of "things that must exist
before automation can exist." The GitHub OIDC provider and CI deploy role belong
here for the same reason: CI cannot create the credential it needs in order to
authenticate. The cost is that this state has no locking and no backup, which is
acceptable for a single operator and would not be for a team.

## 2. S3 native locking, not DynamoDB

The management backend uses `use_lockfile = true`.

**Why:** S3 conditional writes provide state locking directly, removing the
DynamoDB table that older Terraform setups required. One less resource to create,
pay for, and protect.

**Consequences:** requires Terraform 1.10 or later. The repository pins
`~> 1.15`, so this is not a constraint in practice.

## 3. Member accounts are protected from destruction

Every `aws_organizations_account` sets `close_on_deletion = false` and
`lifecycle { prevent_destroy = true }`.

**Why:** AWS accounts are effectively irreplaceable. Closure begins a 90-day
suspension, closures are rate-limited, and the root email cannot be reused
afterwards. `prevent_destroy` turns an accidental removal into a hard error;
`close_on_deletion = false` ensures that if the resource is removed anyway, the
account is merely orphaned in the organization and can be re-imported.

**Consequences:** any refactor that changes a resource address requires a `moved`
block, because Terraform would otherwise plan a replacement and fail on
`prevent_destroy`. That error is the control working, not a nuisance.

**Exception:** ephemeral sandbox accounts vended and reaped by automation should
set `close_on_deletion = true`, since orphaned accounts accumulate cost. This
should be a per-account setting, never a global default.

## 4. Human access through Identity Center, not IAM users

There are no IAM users. Humans authenticate through the IAM Identity Center
access portal with MFA and receive short-lived role sessions.

**Alternative considered:** keeping the original `iamadmin` IAM user, which had
MFA enabled and no access keys, so it was not the usual static-credential risk.

**Why replace it anyway:** an IAM user is scoped to one account. Reaching any
other account means manually assuming `OrganizationAccountAccessRole`, and that
problem grows with every account vended. Identity Center solves access across the
whole organization, which is the actual requirement.

**Consequences:** enabling Identity Center, setting the initial password, and
configuring MFA policy are all manual console steps. The provider has no
resources for them. See
[Architecture](architecture.md#what-terraform-does-not-manage).

## 5. Applications use IAM roles, not users

Applications never get an Identity Center user or an IAM user. They get an IAM
role appropriate to where they run: instance profile, task role, execution role,
Pod Identity, or OIDC federation for workloads outside AWS.

**Why:** Identity Center users are for interactive human sign-in and have no
non-interactive authentication path. IAM users mean long-lived access keys, which
do not rotate and end up in environment files.

**Consequences:** application roles are created in the workload account, not the
management account. An IAM user remains acceptable only for a third party that
supports neither OIDC nor cross-account role assumption, and should be recorded
as a documented exception.

## 6. Access is assigned to groups, not users

Account assignments target the `Administrators` group. The user is a member of
that group.

**Why:** with one administrator this is arguably one resource more than needed.
It buys the ability to change who has access (a second admin, a handover, a
break-glass identity) by editing one membership rather than deleting and
recreating an assignment in every account.

## 7. Every provider declares allowed_account_ids

Both root modules pin `allowed_account_ids` to the management account.

**Why:** this repository can create, move and close AWS accounts. Applying it
against the wrong account with valid credentials is among the worst outcomes
available, and one line of configuration turns it into an immediate failure.

## 8. Single region: eu-west-1

All resources, the state bucket, and the Identity Center instance are in
`eu-west-1`, which is also configured as single-region.

**Why:** there is no availability requirement that justifies multi-region
complexity. Region should be a decision made per workload when a workload needs
it, not a default paid for everywhere.

**Consequences:** the Identity Center instance's primary region cannot be changed
casually. A future region restriction SCP should permit `eu-west-1` plus global
services.

## 9. Service control policies are not yet written

`SERVICE_CONTROL_POLICY` is enabled and the OU structure exists, but no policies
are attached.

**Why this is recorded as a decision:** it is a known gap, not an oversight. The
OU structure was built first so that policies have somewhere to attach. Until
they are written, the OUs are organization without enforcement. In particular,
`Suspended` does not deny anything.

**Planned first policies:** deny-all on `Suspended`; deny leaving the
organization, deleting CloudTrail, and disabling GuardDuty across all OUs; region
restriction to `eu-west-1`; deny `iam:CreateUser` and `iam:CreateAccessKey` on
`Workloads`, which turns decision 5 into an enforced property rather than a
habit. Resource control policies are worth enabling at the same time.

## 10. The repository is public

The code, architecture, decisions and runbooks are published.

**Why:** security that depends on the configuration being secret cannot be
verified and fails silently. Publishing forces controls to be real. This follows
the UK Ministry of Justice's practice of building in the open.

**Consequences:** account IDs, root emails and the admin email stay in gitignored
`terraform.tfvars`, with shapes documented in `terraform.tfvars.example`. State is
never committed. See [Security](security.md#what-is-published-and-what-is-not).
