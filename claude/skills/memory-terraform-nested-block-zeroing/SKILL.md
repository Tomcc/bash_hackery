---
name: memory-terraform-nested-block-zeroing
description: Terraform gotcha — modifying any field in a nested block silently zeros all omitted numeric fields. Auto-invoke when writing or reviewing Terraform nested blocks, especially those with throttle limits or numeric settings.
---

## Set every meaningful field when you touch a nested block

- **Always** set every numeric limit and rate control explicitly when you add or change any
  attribute in a nested block — Terraform sends the whole block, and omitted fields go out as their
  zero value (`0`, `false`, `""`).
- Expect the plan to hide this: omitted fields show as `# (N unchanged attributes hidden)`.
- Fix a zeroed field by setting it explicitly; reverting the attribute you changed leaves it at 0.

For `aws_apigatewayv2_stage.default_route_settings`, zeroed throttles return 429 on 100% of
requests. Always include:

```hcl
default_route_settings {
  detailed_metrics_enabled = true
  throttling_burst_limit   = 5000   # AWS account default; tune to your traffic
  throttling_rate_limit    = 10000  # AWS account default; tune to your traffic
}
```

## Catch it before applying

Grep `terraform plan` for `(N unchanged attributes hidden)` inside blocks you modify. If present,
check what those fields are with `terraform show` or the provider docs — they may be 0.
