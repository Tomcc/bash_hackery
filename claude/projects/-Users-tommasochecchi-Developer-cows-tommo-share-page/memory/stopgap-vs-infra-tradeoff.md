---
name: stopgap-vs-infra-tradeoff
description: "Tommaso weighs a feature's expected lifespan against infra cost; propose the low-friction option for short-lived work, and say so even if it reverses your own earlier recommendation."
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 6205ac33-2d3b-4768-b0a1-7ea2418f1e13
  modified: 2026-09-04T20:16:44.185Z
---

When a feature has a known short lifespan, Tommaso wants the option with the least new
infrastructure — not the architecturally cleanest one. On ROB-7662 (share page, ~2 months until
mod.io replaced it) he rejected a Lambda origin and CloudFront invalidation code in favour of a
baked-file + regeneration-command approach, saying "we can make it more complicated if we get more
traffic."

He also responded well to me reversing my own earlier recommendation once "ASAP for a 2-month
lifespan" was on the table: "you're absolutely right, I'm following here."

**Why:** cost of ownership dominates, and infra you'll delete in two months is pure cost. He'd
rather revisit later than pay up front for a hypothetical.

**How to apply:** ask or infer expected lifespan before proposing new infra. State the tradeoff
explicitly with the concrete cost ("a day of terraform fiddling and a prod apply, for something
you're deleting in two months"). If new information flips your recommendation, say so directly and
give the reason — don't hedge or stick with the earlier answer for consistency.
