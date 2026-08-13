# sbhi-aws-landing-zone

A small, fully public AWS landing zone built with Terraform: AWS Organizations,
organizational units, service control policies, account vending and baselines,
and single sign-on through IAM Identity Center.

This is a personal landing zone, built in the open so that the reasoning is as
visible as the result.

## Built in the open

Everything here is public by default: the code, the architecture, the reasoning
behind each decision, and the runbooks used to recover from failure. This follows
the "coding in the open" approach taken by the UK Ministry of Justice, whose
infrastructure code and technical guidance are published openly, and reflected in
the GOV.UK Service Standard's requirement to make new source code open.

The principle that makes this work: **security must never depend on the code
being secret.** A landing zone whose safety relies on nobody reading it is not
secure, it is merely unexamined. Publishing the configuration forces the controls
to be real ones: deny policies, guard rails, and short-lived credentials rather
than obscurity.

What that means in practice is set out in [Security](docs/security.md): what is
published, what is deliberately kept out of the repository, and why the
distinction falls where it does.

## Documentation

| Document | What it covers |
| --- | --- |
| [Architecture](docs/architecture.md) | Organization, OU layout, accounts, state management, identity |
| [Getting started](docs/getting-started.md) | Prerequisites, bootstrap ordering, applying changes, gaining access |
| [Naming and tagging](docs/naming-and-tagging.md) | Naming conventions for accounts, OUs, resources and Terraform identifiers; the tagging strategy |
| [Decisions](docs/decisions.md) | Each significant choice, the alternatives, and the reasoning |
| [Security](docs/security.md) | Security-by-design posture, threat assumptions, secret handling |
| [Runbooks](docs/runbooks/) | Recovery procedures |

## Repository layout

```
bootstrap/                  Terraform state bucket. Local state, applied by hand.
environments/
  management/               The organization: OUs, accounts, Identity Center.
modules/                    Reusable modules (empty; account module planned).
docs/                       This documentation.
```

Two root modules, applied in order. `bootstrap/` creates the S3 bucket that
holds all other state and is deliberately the only manually-applied, locally-
stated part of the repository. See
[Decisions](docs/decisions.md#1-bootstrap-state-is-local-and-manual).
`environments/management/` holds everything else.

## Current state

Built:

- AWS Organization with all features enabled, root credentials management, and root sessions
- Five top-level OUs: Security, Infrastructure, Workloads (Prod, NonProd), Sandbox, Suspended
- One member account: `sbhi-shared-services`
- IAM Identity Center with group-based access to all accounts
- Remote state in S3 with native locking

Not built yet:

- Service control policies. The OU structure exists but nothing is enforced
- Security OU accounts (log archive, security tooling)
- CI, and the GitHub OIDC role it needs
- Account vending as a reusable module

## Licence

MIT. See [LICENSE](LICENSE).
