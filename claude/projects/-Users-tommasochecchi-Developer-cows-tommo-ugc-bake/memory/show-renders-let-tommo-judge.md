---
name: show-renders-let-tommo-judge
description: "Open render/screenshot comparisons with `open` and let Tommo judge; Claude's vision misses unstructured artifacts and aggregate metrics saturate"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: cc1bf5cd-c145-467f-bcd8-7ee7bc762c8d
  modified: 2026-09-03T09:07:42.578Z
---

When evaluating rendered images (lighting, artifacts, noise), `open <files>` so Tommo sees them,
and let him be the judge. Do not declare visual verdicts like "barely improves".

**Why:** (his words) Claude's vision encoder only registers trained features — it basically can't
see unstructured defects like faint light spots on a wall or noise character. He caught two calls
I got wrong in one session: a "barely improves" render he rated *better than Unity native*, and
jittered-32 renders that "look super bad" (quilted discontinuities) despite decent RMS numbers.
Aggregate metrics saturate too: MAE vs a noisy reference penalizes being *smoother* than it.

**How to apply:**
- After each render experiment, `open` the new image plus the baseline(s) side by side.
- Report the numbers, describe only structural facts, and ask him to judge quality.
- Coherent (patterned) error is far more visible than incoherent noise of larger RMS — reason in
  those terms, not in RMS alone. See [[ugc-apv-bake-ladder]].
