# Runbook: recovering lost bootstrap state

## When to use this

The local state file `bootstrap/terraform.tfstate` has been lost, corrupted, or
left behind on a machine you no longer have. The S3 bucket it manages still
exists.

This is a known and accepted consequence of keeping bootstrap state local. See
[Decisions](../decisions.md#1-bootstrap-state-is-local-and-manual). Recovery is
routine: no data is lost, nothing is destroyed, and the bucket keeps serving
state for the other root module throughout.

## What you are recovering

Six resources, all keyed by the bucket name:

```
aws_s3_bucket.tfstate
aws_s3_bucket_versioning.tfstate
aws_s3_bucket_server_side_encryption_configuration.tfstate
aws_s3_bucket_public_access_block.tfstate
aws_s3_bucket_ownership_controls.tfstate
aws_s3_bucket_policy.tfstate
```

`data.aws_iam_policy_document.tfstate` is a data source and needs no import.

## Before you start

Confirm the bucket still exists and you can reach it:

```bash
aws s3api head-bucket --bucket sbhi-management-tfstate
```

If this fails with a permissions error, fix credentials first. If it fails
because the bucket does not exist, this is not the runbook you need. You are
rebuilding from scratch, and `terraform apply` will create it.

## Procedure

**1. Confirm the state really is empty.**

```bash
cd bootstrap
terraform init
terraform state list
```

Empty output confirms the situation. If resources are listed, stop. The state is
not lost, and importing would duplicate entries.

**2. Write the import blocks.** Create `bootstrap/import.tf`. Every S3 sub-resource
is imported by bucket name:

```hcl
import {
  to = aws_s3_bucket.tfstate
  id = "sbhi-management-tfstate"
}

import {
  to = aws_s3_bucket_versioning.tfstate
  id = "sbhi-management-tfstate"
}

import {
  to = aws_s3_bucket_server_side_encryption_configuration.tfstate
  id = "sbhi-management-tfstate"
}

import {
  to = aws_s3_bucket_public_access_block.tfstate
  id = "sbhi-management-tfstate"
}

import {
  to = aws_s3_bucket_ownership_controls.tfstate
  id = "sbhi-management-tfstate"
}

import {
  to = aws_s3_bucket_policy.tfstate
  id = "sbhi-management-tfstate"
}
```

Substitute the real bucket name if it differs from the example above.

**3. Plan and check carefully.**

```bash
terraform plan
```

Expect **six to import, zero to add, zero to change, zero to destroy**.

Anything in the change or destroy column means the live bucket has drifted from
the configuration. Read each one before continuing. The plan is telling you the
truth about the bucket, and reconciling deliberately is better than letting an
apply overwrite settings you did not intend to change.

**4. Apply.**

```bash
terraform apply
```

**5. Verify and clean up.**

```bash
terraform state list     # expect all six resources
terraform plan           # expect no changes
```

Delete `bootstrap/import.tf` once the plan is clean. Leaving it in place is
harmless but misleading to the next reader.

## Afterwards

Back up the recovered state file, or accept that you will run this runbook again.
The file is small and contains no credentials, but it does describe your
infrastructure, so keep it somewhere private rather than in the repository.

If you find yourself running this repeatedly, that is the signal to revisit
decision 1 and migrate bootstrap state into S3 after all.
