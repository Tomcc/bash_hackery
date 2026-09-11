---
name: dgemma-selfhost-verdict
description: Final verdict + ship shape of the DiffusionGemma self-hosting evaluation (Aug 2026)
metadata: 
  node_type: memory
  type: project
  originSessionId: 592dca23-2bab-4211-82d4-af0ffc2b9b09
  modified: 2026-08-22T07:36:46.744Z
---

The DiffusionGemma bench (tools/dgemma_bench, branch tommo/dgemma) concluded 2026-08-22:
self-hosting is viable. Ship shape: **H100 SXM + RedHatAI FP8-dynamic + FA4, canvas=128,
steps=16, SEQS=4, admission-control proxy (spill to serverless on busy)**. Stress-tested:
676-820ms TTLT p50 accepted, 99% parse, ~$0.04/Mtok vs pool's $0.213.

Key facts that took effort to establish (details in RESULTS.md):
- The financial lever is the 34:1 input:output ratio — self-host prefill is nearly free.
- Blind 5-arm judge: quality gap vs serverless is the *diffusion decoding*, not model size
  (26B-AR == 31B-AR in judging; diffusion ranks ~0.6 lower at any step count).
- steps=8 passes easy fixtures but fails 27% of real prompts (unterminated say() strings);
  single-fixture quality results are worthless — always use the 498 real prompts
  (regenerate via fetch_prod_data.py).
- Consumer GPUs (5090, RTX Pro 6000) cannot run FP8/bf16 fast (no FA4 — model has global
  head_dim=512; TRITON fp8-MoE fallback is 4x slow). NVFP4-only tier.
- User announced this to the team as "first model we can self-host that makes financial
  sense"; next phase is [[dgemma-next-steps]] (shadow traffic).
