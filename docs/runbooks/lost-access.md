# Runbook: lost access to the organization

## When to use this

You cannot sign in through the IAM Identity Center access portal. The MFA device
is lost or broken, the user is locked out, or Identity Center itself is
unavailable.

There is no IAM user to fall back to. That was a deliberate choice, recorded in
[decision 4](../decisions.md#4-human-access-through-identity-center-not-iam-users),
so the path is Identity Center or the root user with nothing in between.

## The chain you are relying on

```
registrar  →  DNS  →  mailbox  →  account root  →  the organization
```

Root sign-in recovery needs a password reset. The reset link arrives by email,
that mail is delivered by an external provider, at a domain resolved by an
external DNS provider, registered at an external registrar. Every link has to be
working. See
[Architecture](../architecture.md#dns-and-external-dependencies) and
[decision 11](../decisions.md#11-the-account-root-email-domain-lives-outside-the-organization).

## Before you need this

Run these occasionally. Every one of them fails silently, and the failure is only
visible at the moment you can least afford it.

- **Send mail to every account root address and confirm it arrives**, including
  the management account. A forwarding rule that quietly stopped working looks
  identical to nobody having sent anything.
- **Confirm auto-renew and a valid payment method** on the domain and on the mail
  subscription. Custom domains are usually a paid mail feature, so a lapsed
  subscription stops delivery just as effectively as an expired domain.
- **Confirm the registrar, DNS and mail accounts do not use recovery addresses at
  this domain.** That loop only opens from the outside.
- **Confirm root MFA is enrolled on a device that would not be lost alongside the
  Identity Center MFA device.** If they are the same phone, this runbook has no
  happy path.
- **Confirm the phone number on the management account is current.** The
  alternative factors flow needs it, and it cannot be checked from outside.

## Procedure

**1. Rule out the ordinary case.** An expired SSO session looks like a lockout:

```bash
aws sso login --sso-session sbhi
```

**2. Sign in as root** on the management account, using the root email address
and password. If MFA is enrolled and you have the device, this is the end of it.
Sign in, repair Identity Center, sign out again. Root is not an operational
account.

**3. If the root password is unknown,** use the forgot-password flow. The reset
link is sent to the account root address. This is the step where the external
chain matters.

**4. If the root MFA device is lost,** use the alternative factors flow. It needs
both the root email address and the registered phone number, which is why the
preventive check above exists.

**5. If mail is not arriving,** work backwards along the chain rather than
retrying the reset. Confirm the domain has not expired, the nameservers still
point where you expect, the MX records are intact, and the mail subscription is
active. Any one of these breaks delivery without producing an error anywhere you
would normally look.

**6. For a member account,** root recovery is usually unnecessary. From the
management account you can assume `OrganizationAccountAccessRole` into any
account that Organizations created, which is faster and does not involve root at
all.

## Afterwards

Rotate whatever was used to recover: root password, MFA registration, or the
Identity Center user's credentials.

Then re-run the preventive checks above. Whatever broke has probably been broken
quietly for a while, and the recovery only proves the path worked once, under
attention, on the day you were looking at it.
