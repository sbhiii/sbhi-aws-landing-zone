# CLAUDE.md

AWS landing zone built with Terraform. Start with [README.md](README.md) and the
[docs](docs/) for architecture, decisions, conventions and runbooks. This file
covers only what is not obvious from reading the code.

## Rules

**Never run `terraform apply`.** Plans and applies are run by the user. Writing
configuration, running `fmt` and `validate`, and reading state are fine.

**This repository is public.** Never commit account IDs, email addresses,
Identity Center instance ARNs or identity store IDs. They belong in gitignored
`terraform.tfvars`, with the shape documented in `terraform.tfvars.example`.

**`bootstrap/` keeps local state and is applied by hand.** This is deliberate and
settled: see [decision 1](docs/decisions.md#1-bootstrap-state-is-local-and-manual).
Do not propose migrating it to S3 or wiring it into CI. The GitHub OIDC provider
and CI deploy role belong here for the same reason.

**No em-dashes** in documentation, comments or commit messages. Use a colon, a
full stop, parentheses or a comma, whichever the sentence actually wants.

## Terraform conventions

`snake_case` for all Terraform identifiers. Account and OU naming follows
[naming-and-tagging.md](docs/naming-and-tagging.md).

Renaming a resource label changes its state address. Always pair the rename with
a `moved` block and confirm the plan reports zero destroys before it is applied.
Member accounts carry `prevent_destroy`, so a missing `moved` block is a hard
error rather than silent data loss.

Adding an account means two edits, not one: the resource in `accounts.tf`, and an
entry in `local.sso_accounts` in `identity_center.tf`. Identity Center assigns per
account, not per OU, so a new account has no access until it appears in that map.

Verify against the provider schema before claiming a resource or argument exists:

```bash
cd environments/management
terraform providers schema -json | python3 -c "..."
```

Several parts of this landing zone have no Terraform resource at all and are
applied in the console. They are listed under
[what Terraform does not manage](docs/architecture.md#what-terraform-does-not-manage).
Check that list before writing code for something that cannot be coded.

## Commands

```bash
terraform fmt -recursive
terraform validate                    # run in each root module

export AWS_PROFILE=sbhi-management    # Identity Center profile
aws sso login --sso-session sbhi      # when the session expires
```

## Current gaps

No service control policies, no detective controls, no CI. These are known and
tracked in [security.md](docs/security.md#known-gaps), not oversights. The OU
structure exists but enforces nothing yet.
