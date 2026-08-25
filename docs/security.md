# Security

## Security by design, in public

This repository is public. The configuration of the organization, the guard
rails, the account structure and the recovery procedures are all readable by
anyone.

That is a deliberate constraint rather than an accepted risk. If publishing the
configuration would compromise the landing zone, the landing zone is relying on
obscurity, and obscurity fails silently: you cannot tell whether it is still
working. Building in the open forces every control to be a real one: a deny
policy, a permission boundary, a short-lived credential, an enforced condition.

This follows the approach taken by the UK Ministry of Justice, which publishes
its infrastructure code and technical guidance openly, and the GOV.UK Service
Standard's requirement to make new source code open.

## What is published, and what is not

Being open about architecture is not the same as being careless with
identifiers. The line falls at things that are _useful to an attacker but not to
a reader_.

**Published:** the full Terraform configuration, OU structure, permission sets,
guard rails, decisions and their reasoning, and the recovery runbooks.

**Not published**, kept in gitignored `terraform.tfvars`:

| Value                                                                      | Why it is withheld                                                                                                                                                                                                                                                                                         |
| -------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Account root email addresses | Not handed over, but see below: they are derivable, so this is hygiene rather than a control. |
| AWS account IDs | Not secret per AWS, but useful for social engineering against support and for targeting cross-account trust policies. Withheld **here**, where the management account ID would be exposed; see below. |
| Identity Center admin email | Same as the row above. Withheld, and derivable by the same route. |

### Withholding account IDs is scoped to this repository

Workload repositories in this estate commit role ARNs, account ID included. That
is deliberate and it is the industry norm: AWS does not classify account IDs as
secret, and a role is protected by the conditions on its trust policy, not by the
obscurity of its ARN.

The rule holds here because this repository manages the organization, so an
account ID committed here is the management account's. That one is worth
withholding: service control policies do not apply to it, and it can create and
close accounts.

Enforcing it outside that boundary has a measured cost. Doing so in
`sre-homelab-gitops` required an unscopeable `route53:ListHostedZonesByName` on
the cert-manager role, and a manual step after every cluster rebuild, to conceal
a member account ID. Both were reverted.

The root email domain is not withheld. It fronts a public site, and `dig NS` and
`dig MX` name its providers to anyone who knows it.

Root addresses are therefore derivable: the aliasing subdomain is confirmed by
`dig MX`, and [naming and tagging](naming-and-tagging.md#aws-accounts) publishes
the convention `sbhi-<purpose>@<domain>`. They are kept out of this repository
anyway, but the protection is MFA on the mailbox and on Identity Center, plus
`RootCredentialsManagement`, not secrecy.

[Decision 11](decisions.md#11-the-account-root-email-domain-lives-outside-the-organization)
is unaffected. Its protection is structural, not informational.

**Not built yet:** root email on a domain unrelated to the public one would make
the addresses underivable. That is a change to live accounts.

Every variable is documented in `terraform.tfvars.example`, so the _shape_ of the
required input is public even where the values are not. A reader can reproduce
the landing zone without learning anything that helps them attack this one.

Terraform state is never committed. It is stored in S3 with versioning,
encryption, and a public access block, and it frequently contains resource
attributes that should not be public even when the configuration is.

## Controls in place

**No long-lived credentials for humans.** Access is through IAM Identity Center
with MFA. There are no IAM users and no access keys. Role sessions are capped at
four hours, after which re-authentication is required.

**No long-lived credentials for machines.** Applications use IAM roles obtained
from their runtime (instance profiles, task roles, execution roles, Pod
Identity), or OIDC federation when running outside AWS. Static access keys are
treated as a documented exception, not a default.

**Root is protected and reserved.** The organization has
`RootCredentialsManagement` and `RootSessions` enabled. Root is the break-glass
path of last resort, not an operational account.

**Wrong-account protection.** Every provider declares `allowed_account_ids`, so
applying against an unintended account fails immediately rather than making
changes. In a repository where one root module can create and delete AWS
accounts, this is cheap insurance.

**Destruction protection.** The state bucket and member accounts carry
`prevent_destroy`. Member accounts additionally set `close_on_deletion = false`
so that removal from state never closes a real account.

**Transport security.** The state bucket policy denies every `s3:*` action when
`aws:SecureTransport` is false.

**Least blast radius.** The management account holds only organization
management, Identity Center, and Terraform state. Workloads live in member
accounts.

**DNS write access cannot reach mail records.** Automation that writes DNS is
either scoped to a hosted zone containing no mail records, or restricted by Route
53 record-level IAM conditions to the exact names and types it needs. The apex
zone carrying account recovery mail holds no automation credential at all and is
edited by hand. See
[decision 12](decisions.md#12-automation-never-gets-write-access-to-mail-records).

## Known gaps

These are real, current weaknesses. They are listed rather than omitted, because
a security document that only describes strengths is marketing.

**No service control policies.** `SERVICE_CONTROL_POLICY` is enabled on the
organization and the OU structure exists, but no policies are attached. Nothing
is currently _enforced_ at the organization level: `Suspended` does not deny,
`Sandbox` does not restrict, and no policy prevents leaving the organization,
disabling CloudTrail, or creating IAM users. This is the highest-priority gap.

**No detective controls.** CloudTrail, Config, GuardDuty and Security Hub have
trusted access enabled at the organization level but are not configured. There is
no organization trail and no log archive account, so there is currently no
tamper-resistant audit record.

**No CI, so no automated review.** Changes are applied from a laptop. There is no
pipeline running `fmt`, `validate`, or policy scanning on pull requests, and no
enforced plan-before-merge.

**Single administrator, single MFA device.** One human, one Identity Center user,
one registered device. The recovery path if that device is lost is the root user,
and there is no IAM user fallback in between: the original one was deliberately
removed. Root recovery in turn depends on email delivered through an external
registrar, DNS provider and mail provider, none of which are managed by this
repository. Compromise of any of those three accounts is equivalent to compromise
of the organization, and a lapse in any of them breaks recovery silently. The
chain is set out in
[Architecture](architecture.md#dns-and-external-dependencies) and the procedure in
[the lost access runbook](runbooks/lost-access.md).

## Reporting a problem

If you find a security issue in this configuration, please open an issue on the
repository. There is nothing here that is confidential, which is the point, so
public discussion of weaknesses is welcome and useful.
