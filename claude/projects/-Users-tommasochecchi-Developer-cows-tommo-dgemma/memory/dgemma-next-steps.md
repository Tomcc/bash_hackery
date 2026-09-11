---
name: dgemma-next-steps
description: "Where the DiffusionGemma project stands and what remains (post-benchmark, pre-production)"
metadata: 
  node_type: memory
  type: project
  originSessionId: 592dca23-2bab-4211-82d4-af0ffc2b9b09
  modified: 2026-08-28T01:25:48.073Z
---

Benchmarking phase COMPLETE (2026-08-28). All findings in tools/dgemma_bench/RESULTS.md on
branch tommo/dgemma (UNPUSHED — the branch was lost once to a deleted workspace and
reconstructed from the session transcript; suggest pushing or merging soon).

Final framing (user's own words): self-hosting was always the financial win (34:1 prefill
arbitrage, ~5-10x cheaper than the pool either way); **diffusion is a latency knob** — ~400-450ms
faster per plan than self-hosted AR at comparable load (676-820ms vs 1076-1481ms p50), bought
with slightly-worse phrasing (blind-judge rank 3.6 vs 2.5-2.8) and ~1% parse retries. AR sibling
self-hosted = prod-identical quality, zero spill at 32 slots, 1251 tok/s ceiling.

Remaining (user: "not a rush, I don't wanna deal with the self-hosting work"):
- Shadow traffic behind the proxy (真 cache rate, real spill behavior).
- Proxy 429/spill admission logic (stress.py validated the design client-side).
- Revisit when DiffusionGemma 2 / llama.cpp support lands — rerun is one afternoon, ~$10
  (matrix + arms + judge scripts all versioned). "This is the worst it'll be" is the bet.
- Both boxes: H100 48341020 STOPPED (caches intact); all others destroyed.

Related: [[dgemma-selfhost-verdict]], [[vastai-ops-gotchas]].
