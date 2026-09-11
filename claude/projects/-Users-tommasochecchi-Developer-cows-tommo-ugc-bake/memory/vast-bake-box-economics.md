---
name: vast-bake-box-economics
description: The APV bake box is a $0.057/hr RTX 3060 at 35s a bake; the warm OptiX state survives stop/start but is not shippable
metadata: 
  node_type: memory
  type: project
  originSessionId: 5b392b67-54a1-44e6-b018-e7af5220287e
  modified: 2026-09-03T23:25:08.111Z
---

Production APV baking runs on a long-lived vast.ai RTX 3060 (~$0.057/hr, ~$41/month), 35.1-35.4 s a
bake with under 1% spread. It ties a $0.131/hr 3090 — the GPU stopped being the bottleneck once the
gather went to 16x16 tiles at 16 spp.

**The 224 s cold start is per fresh host, not per bake.** It is the OptiX/OSL kernel compile and it
cannot be pre-baked into the image — `~/.cache/cycles` never appears and `~/.nv/ComputeCache` stays
0 bytes, yet the tax never recurs, including across a vast `stop`/`start` (which replaces the
container but not the host driver). So the production plan is one box left **stopped** and woken on
demand (~1 min), not one running all month. Screen hosts on CPU clock, not price:
`vast_bake.py --min-cpu-ghz`, since the lightmap bake is single-threaded.

Both benchmark instances were destroyed on 2026-09-03 when this was parked, so the next bake pays a
fresh rental. Tracked in Linear as **UGC Light Baking** (ROB-7888 geometry export → ROB-7889 bake
API → ROB-7890 bake on publish, which blocks publishing by design). See [[ugc-apv-bake-ladder]].
