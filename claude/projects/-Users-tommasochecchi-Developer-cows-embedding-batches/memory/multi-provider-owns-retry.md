---
name: multi-provider-owns-retry
description: multi_provider::handler already retries across the provider stack — endpoint handlers must not add their own retry loops
metadata: 
  node_type: memory
  type: project
  originSessionId: 9acf4b2c-caef-45e1-984e-d39006d7b368
---

`multi_provider::handler` (cloud_api/common/src/multi_provider.rs) already owns retry and
fallthrough for every agent endpoint that runs through it (chat, plan, check3, embeddings, stt).
On a retryable error (e.g. 429) it advances to the next provider immediately; the whole request
is re-run across the stack for `MULTI_PROVIDER_MAX_RETRIES = 3` rounds, with `exponential_backoff`
between rounds. A bad-request/client error aborts without retry.

**Why:** During ROB-7131 (embedding fan-out) the plan added a per-sub-batch `embed_chunk_with_retry`
loop. It was redundant — a sub-batch's retryable error already short-circuits `run_model`, which
falls through to the next provider via this outer loop. The inner retry was speculative, untestable
(no 429 mock), and duplicated existing behavior.

**How to apply:** When writing/reviewing an endpoint handler's `run_model`, do NOT add a retry loop
for provider errors — just propagate the error and let multi_provider cycle the stack. A per-chunk
retry is only justified for a small-width provider that splits into many chunks (databricks, deferred
to ROB-6423), and even then pair it with a concurrency cap.

Gotcha found the same session: `crate::exponential_backoff(attempt)` returns a `Duration`, it does
NOT sleep — wrap it in `tokio::time::sleep(...)` if you ever need to actually wait.
