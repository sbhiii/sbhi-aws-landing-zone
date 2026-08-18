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

## 11. The account root email domain lives outside the organization

**Rule: what recovers you must not depend on what it recovers.**

The domain that receives AWS account root email is registered and resolved
outside AWS, with mailboxes at an external provider. None of it is managed here.

Root email is the recovery path when Identity Center is unavailable. Put that
domain inside the organization and a suspension or a billing failure takes out
the recovery path at the exact moment it is needed: you would have to receive the
mail in order to regain the access required to fix the mail.
`aws_route53domains_domain` can register a domain, so this is a deliberate choice
rather than a provider limitation.

The rule applies upward too. The registrar, DNS and mail accounts must not use
recovery addresses at this domain, which would reintroduce the same loop one
level up.

**Registrar and DNS are at one provider, not two.** Splitting them looks like
defence in depth and is not: either account alone is enough for a full takeover,
by repointing the nameservers or by rewriting the MX records. A split doubles the
accounts to harden and buys no resistance to compromise. The accepted cost is
that a provider-level suspension takes out registration and DNS together.

**Consequences:** those external accounts are part of this landing zone's
security boundary despite appearing nowhere in this repository, and they warrant
stronger authentication than the AWS accounts they protect. Domain expiry, a
failed card, or a lapsed mail subscription each break account recovery silently.
The procedure is in [the lost access runbook](runbooks/lost-access.md).

## 12. Automation never gets write access to mail records

**Rule: a credential that can write DNS must not be able to change where mail
goes.**

MX records decide who receives mail. On the domain carrying AWS account root
addresses that is the recovery path from
[decision 11](#11-the-account-root-email-domain-lives-outside-the-organization);
on a product domain it is customer and transactional mail. Either way, anything
that writes DNS unattended (cert-manager solving ACME challenges, external-dns
reconciling services, ACM validating a certificate) must be unable to touch them.

There are two ways to enforce this, and which is available depends on the
provider.

**Zone separation.** Delegate a subdomain to its own hosted zone and scope the
credential to that zone. The zone holds no mail records, so the credential cannot
reach them however it is misused. This is the only option where the provider
scopes credentials per zone rather than per record, which is the case for the
external provider holding the apex: a token able to write challenge records under
a subdomain can also rewrite the apex MX.

**Record-level IAM conditions.** Route 53 supports
`route53:ChangeResourceRecordSetsNormalizedRecordNames`,
`ChangeResourceRecordSetsRecordTypes` and `ChangeResourceRecordSetsActions`. A
role can be allowed to UPSERT TXT records named `_acme-challenge.*` and nothing
else, in a zone that also holds MX. Mail and automation can share a zone safely.

**Which applies where.** Zone separation is structural: a separate zone cannot be
re-opened by a typo. Record-level conditions are a policy control, and a policy
widened during debugging removes the protection with nothing to announce it.

So the choice follows the blast radius. The domain carrying AWS account recovery
mail gets zone separation, because the downside is losing the organization. A
product domain gets record-level conditions, because the downside is losing
product mail and the operational gain is real: the whole zone can live in Route
53, with apex ALIAS records to CloudFront and load balancers and certificate
validation in the same apply.

**The rule that follows for the hand-managed apex zone:** no API token is ever
issued for it. Wanting to automate it is the signal to revisit this decision, not
to mint the token.

**Consequences:** a certificate for a name in that apex zone needs its validation
record added by hand. That is one record per name rather than an ongoing chore,
since ACM reuses the same record across renewals. Apex ALIAS records are not
available there either, and the provider's CNAME flattening covers the same need.

**Not built yet:** when AWS workload accounts need DNS under the personal domain,
a single subdomain is delegated to a hub zone in `sbhi-shared-services` which
re-delegates per account, so that adding an account stays a Terraform change
rather than a manual edit at the provider. One delegation does not justify the
extra zone and the extra resolution hop. Workloads that run outside AWS take a
top-level delegation instead and do not sit under that hub.

## 13. Domains are registered where they outlive what they serve

**Rule: registration belongs to the longest-lived thing, not to the workload it
currently points at.**

The domain carrying account root email is registered at an external registrar,
outside the organization, for the reasons in
[decision 11](#11-the-account-root-email-domain-lives-outside-the-organization).
Every other domain is registered in Route 53 in `sbhi-shared-services`.

**Not the workload account.** A domain is a business asset that outlives the
infrastructure serving it: products get rebuilt and accounts get closed, but the
name persists through both. Closing an AWS account begins a 90-day suspension, so
a registration held there is not merely awkward to recover. The workload account
is also the most exposed one, since it runs the code and holds the deploy role,
and a compromise there must not be able to transfer the domain away.

**Not the management account,** for the usual reason: service control policies do
not apply to it, so nothing placed there can ever be constrained.

**Not the external registrar,** despite decision 11 putting the root email domain
there. That registrar requires a domain's DNS to be on its own platform, and
product domains want their zone in Route 53 so that apex ALIAS records and
in-apply certificate validation work, per
[decision 12](#12-automation-never-gets-write-access-to-mail-records). Registering
at yet another registrar would re-add a party that was deliberately removed.

**Consequences:** registration and hosted zone deliberately live in different
accounts. Registration is a durable, organization-level asset; the hosted zone is
an operational resource belonging to the product, so it sits in the workload
account alongside the records it serves. The registered domain's nameservers
point at that zone. If the workload account is closed or rebuilt, the
registration survives and the nameservers are repointed at the new zone.

`aws_route53domains_domain` spends money on `apply` and a registration cannot be
reversed on a whim, so it carries `prevent_destroy` for the same reasons as
[decision 3](#3-member-accounts-are-protected-from-destruction).
`aws_route53domains_registered_domain` is the resource for a domain registered
elsewhere, and its `name_server` block is what points registration at the zone.

Route 53 registration costs a few dollars a year more than an at-cost registrar.
That is the price of not adding a party, and it is not worth optimising.

## 14. The landing zone owns what outlives the workload

**Rule: a resource whose destruction requires a manual edit outside AWS belongs
to this repository. Everything that follows the workload's own lifecycle belongs
to the workload's repository.**

**Not built yet:** the arrangement below is decided and not deployed. It is
recorded now because it constrains how `environments/shared-services/` is
written. See
[Architecture](architecture.md#dns-and-external-dependencies).

The homelab cluster's AWS footprint belongs in `sbhi-shared-services`, with only
the hosted zone defined here. The OIDC provider, the role, the discovery
documents and the records pointing at the cluster are defined in the cluster's
own repository.

**Why the split falls there.** The zone anchors a delegation edited by hand at
the external DNS provider, per
[decision 12](#12-automation-never-gets-write-access-to-mail-records). Destroy it
and the replacement gets a new zone ID, so recovery is a manual edit at the
provider rather than an apply. Everything else is derived from the cluster's
signing key or points at its current address, so it is recreated whenever the
cluster is. A node rebuild must not require an apply in this repository.

**Why not a dedicated workload account.** The cluster only writes DNS. It holds
no data and runs no AWS compute, so an account would add a boundary with nothing
on either side of it, plus a state backend, a profile and an assignment to
maintain. It also takes a top-level delegation rather than sitting under the hub
zone in [decision 12](#12-automation-never-gets-write-access-to-mail-records),
since that hub exists to save manual edits when vending AWS accounts and a
workload outside AWS is not vended. Revisit when the cluster starts consuming AWS
services rather than only writing DNS.

**How the boundary is crossed.** The workload repository reads the zone with a
`data "aws_route53_zone"` lookup by name, not `terraform_remote_state`. A name is
a stable contract; a state file is an implementation detail, and sharing one
would let a failed apply in either repository block the other. Both repositories
write into the same account, which is what the `Repository` tag in
[naming and tagging](naming-and-tagging.md#tagging) exists to disambiguate.
