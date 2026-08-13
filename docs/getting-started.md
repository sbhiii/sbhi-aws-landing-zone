# Getting started

## Prerequisites

- Terraform `~> 1.15`
- AWS CLI v2
- An AWS account to act as the organization management account
- A domain capable of receiving mail at a unique address per AWS account

## Order of operations

The two root modules must be applied in order, because the second stores its
state in a bucket the first creates.

```
1. bootstrap/                 → creates the state bucket   (local state, manual)
2. environments/management/   → the organization           (S3 backend)
```

### 1. Bootstrap

```bash
cd bootstrap
cp terraform.tfvars.example terraform.tfvars   # then fill it in
terraform init
terraform plan
terraform apply
```

State stays local, by design. See
[Decisions](decisions.md#1-bootstrap-state-is-local-and-manual). The state file
is gitignored and lives only on the machine that applied it. If it is lost,
follow [the recovery runbook](runbooks/bootstrap-state-recovery.md).

### 2. Management

```bash
cd environments/management
cp terraform.tfvars.example terraform.tfvars   # then fill it in
terraform init
terraform plan
terraform apply
```

`backend.tf` references the bucket created in step 1 by name. If you change
`bucket_name` in bootstrap, change it here too.

## Manual steps

Some parts of the landing zone have no Terraform resource. They are listed in
[Architecture](architecture.md#what-terraform-does-not-manage); these are the
ones you hit during first setup.

**Enable IAM Identity Center** in the console before applying
`identity_center.tf`. The provider can only look up an existing instance, not
create one. Choose the same region as the rest of the landing zone.

**Set the portal subdomain** under Identity Center → Settings → AWS access portal
URL. This can only be changed **once**, ever, so choose deliberately. You get
`https://<subdomain>.awsapps.com/start`, a subdomain only, not a custom domain.

**Send the initial password invitation.** A user created through the API has no
password and receives no email automatically. After applying, go to Identity
Center → Users → select the user → *Reset password*, and either mail a link or
generate a one-time password. Until this is done the user exists and cannot sign
in.

If the invitation does not arrive, use the one-time password option rather than
debugging mail. That address is also the MFA recovery path, so confirm it
genuinely delivers before relying on it.

**Name the management account.** Accounts created at sign-up default to the
account holder's personal name, which then appears in the access portal:

```bash
aws account put-account-name --account-name "sbhi-management"
```

Omitting `--account-id` targets the calling account, which is the only way to
rename the management account.

## Daily use

Configure a profile once:

```bash
aws configure sso
```

| Prompt | Value |
| --- | --- |
| SSO session name | `sbhi` |
| SSO start URL | `https://sbhi.awsapps.com/start` |
| SSO region | `eu-west-1` |
| Registration scopes | `sso:account:access` |

Then:

```bash
export AWS_PROFILE=sbhi-management
aws sts get-caller-identity     # expect an AWSReservedSSO_... ARN
terraform plan
```

When the session expires:

```bash
aws sso login --sso-session sbhi
```

Prefer `AWS_PROFILE` in your environment over a `profile` argument in
`providers.tf`. A hardcoded profile is a machine-specific detail that would have
to be removed the moment anything else runs this code.

## Adding an account

1. Add an `aws_organizations_account` resource in `accounts.tf`, with a unique
   root email and the correct `parent_id`.
2. Add it to `local.sso_accounts` in `identity_center.tf`. Identity Center
   assigns per account, so a new account gets no access until it appears here.
3. Plan and apply. Verify the account appears in the access portal.

## Renaming a Terraform resource

Renaming a resource label changes its state address, which Terraform reads as
"destroy the old thing, create a new one." On an account resource, `prevent_destroy`
turns that into a hard error.

Always pair the rename with a `moved` block, as described in
[Naming and tagging](naming-and-tagging.md#terraform-identifiers). Confirm the
plan reports `0 to add, 0 to change, 0 to destroy` before applying, then delete
the `moved` block once applied.

## Verifying access changes

After any change to Identity Center, sign in to the portal and confirm you can
assume the expected role in **every** account, not just the one you use most. An
account assignment that silently failed to apply looks identical to one that was
never written until you try to use it.
