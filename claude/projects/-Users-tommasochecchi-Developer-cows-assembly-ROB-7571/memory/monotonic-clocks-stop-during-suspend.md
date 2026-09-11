---
name: monotonic-clocks-stop-during-suspend
description: "Monotonic clocks (time.monotonic, tokio Instant) freeze during host suspend — use wall clock when measuring against external parties (token TTLs, human wait times). Found twice in one night of ROB-7571 trial testing."
metadata: 
  node_type: memory
  type: project
  originSessionId: d4088714-1211-4080-a846-354ba5dd7725
---

`time.monotonic()` (Python) and `std/tokio Instant` (Rust) stop ticking while the host sleeps, on
both macOS and Linux. Found 2026-08-06 during the ROB-7571 overnight trial: the proxy reported
`waited 37m` against 1h51m real, and the router's GitHub token 401'd after a suspend because its
Instant-measured age stayed under the TTL.

**Why:** suspend is invisible to monotonic clocks, but external parties (token issuers, waiting
humans) keep counting.

**How to apply:** measuring against an external party's clock (credential TTLs, "how long has a
human waited") → wall clock (`time.time()`, `DateTime<Utc>`). Measuring your own work (perf
timings) → monotonic is correct; suspend inflating a perf number would mislead. Farm relevance:
agent containers freeze/thaw (`docker stop`) and the VM can suspend, so any long-lived loop with a
TTL or age check is exposed.
