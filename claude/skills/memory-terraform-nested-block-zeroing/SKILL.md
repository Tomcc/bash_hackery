---
name: memory-terraform-nested-block-zeroing
description: Terraform gotcha — modifying any field in a nested block silently zeros all omitted numeric fields. Auto-invoke when writing or reviewing Terraform nested blocks, especially those with throttle limits or numeric settings.
---

When you add the **first** attribute to a previously-unset nested block (or modify any attribute in an existing one), Terraform sends **all** fields in that block to AWS — including ones you didn't write, which default to their zero value (`0`, `false`, `""`).

This is silent and dangerous: Terraform's plan shows `# (N unchanged attributes hidden)` for the fields you didn't touch, even though they may already be at a broken zero value in AWS.

## The incident that surfaced this

`aws_apigatewayv2_stage.default_route_settings` had:
```hcl
default_route_settings {
  detailed_metrics_enabled = false
}
```

Changing `detailed_metrics_enabled = false → true` caused Terraform to write `throttling_burst_limit = 0` and `throttling_rate_limit = 0` to AWS. This set the API Gateway throttle to zero, blocking **100% of requests** with 429 for all users. The plan showed those fields as `# (3 unchanged attributes hidden)` — completely hiding the damage.

Reverting `detailed_metrics_enabled` back to `false` did NOT fix it — the zeroed throttle values stayed at 0. The fix required **explicitly setting all fields**.

## Rule

**Always explicitly set all meaningful fields in a nested block**, especially numeric limits and rate controls. Never leave them implicit when modifying a block for the first time.

For `aws_apigatewayv2_stage.default_route_settings`, always include:
```hcl
default_route_settings {
  detailed_metrics_enabled = true
  throttling_burst_limit   = 5000   # AWS account default; tune to your traffic
  throttling_rate_limit    = 10000  # AWS account default; tune to your traffic
}
```

## How to catch this before applying

Run `terraform plan` and grep for `(N unchanged attributes hidden)` inside blocks you're modifying. If you see it, expand the full state with `terraform show` or check the provider docs for what those hidden fields are — they may be at 0.
