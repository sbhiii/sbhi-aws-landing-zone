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
identifiers. The line falls at things that are *useful to an attacker but not to
a reader*.

**Published:** the full Terraform configuration, OU structure, permission sets,
guard rails, decisions and their reasoning, and the recovery runbooks.

**Not published**, kept in gitignored `terraform.tfvars`:

| Value | Why it is withheld |
| --- | --- |
| Account root email addresses | The account-recovery surface. Publishing them invites targeted phishing aimed at password reset. |
| AWS account IDs | Not secret per AWS, but useful for social engineering against support and for targeting cross-account trust policies. |
| Identity Center admin email | The MFA and password recovery path. |

Every variable is documented in `terraform.tfvars.example`, so the *shape* of the
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

## Known gaps

These are real, current weaknesses. They are listed rather than omitted, because
a security document that only describes strengths is marketing.

**No service control policies.** `SERVICE_CONTROL_POLICY` is enabled on the
organization and the OU structure exists, but no policies are attached. Nothing
is currently *enforced* at the organization level: `Suspended` does not deny,
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
one registered device. The recovery path if that device is lost is the root user.

## Reporting a problem

If you find a security issue in this configuration, please open an issue on the
repository. There is nothing here that is confidential, which is the point, so
public discussion of weaknesses is welcome and useful.
