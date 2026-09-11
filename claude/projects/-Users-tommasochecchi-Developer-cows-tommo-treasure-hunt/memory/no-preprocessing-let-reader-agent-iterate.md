---
name: no-preprocessing-let-reader-agent-iterate
description: Tommaso rejects preprocessing pipelines; the agent reading an image should crop/check itself
metadata: 
  node_type: memory
  type: feedback
  originSessionId: e1af8455-2844-48a3-940e-b2e43aad2356
  modified: 2026-09-06T10:22:07.031Z
---

For the treasure book (and image-reading tasks generally), Tommaso rejected both a global
leaf-cropping preprocessing pass and coordinate-measuring frameworks: "It's actually very good to
let the agent doing the reading also do whatever it wants to the image."

**Why:** transferring coordinates between a measuring step and a rendering step is what created the
JS remapping disaster in the fired session; skewed phone photos made it unworkable. An agent that
crops, looks at its own crop, and adjusts is self-correcting — no pipeline needed.

**How to apply:** give reading agents tiny iterate-friendly tools (clip → Read result → re-clip;
render → Read screenshot → fix) instead of upfront normalization. Eyeballed page fractions beat
measured photo pixels. Related: [[treasure-hunt-project]].

Follow-up preference (2026-09-06): agents shouldn't work as black boxes — since the corpus is
frozen, keep accumulating finished exemplars as references ("reference pages", not abstract
placeholder templates) and fold each discovered failure mode back into the spec. Also: verify
subagent self-reports against the source yourself; both Haiku and (less often) Sonnet claim
"perfect match" while wrong.
