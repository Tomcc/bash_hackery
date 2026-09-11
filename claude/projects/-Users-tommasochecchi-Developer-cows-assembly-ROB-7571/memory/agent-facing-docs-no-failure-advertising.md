---
name: agent-facing-docs-no-failure-advertising
description: "Tommaso's rule for farm-agent-facing docs — never advertise failure/fallback paths in the happy-path skill; fallback skills must lead with cost economics."
metadata: 
  node_type: memory
  type: feedback
  originSessionId: d4088714-1211-4080-a846-354ba5dd7725
---

When writing docs/skills that Assembly farm agents read: do NOT mention failure handling or
fallbacks in the main workflow skill (e.g. "the tool never fails, so never poll with Bash" was
vetoed from assembly-agent SKILL.md). Fallback guidance lives in a separate skill whose
description triggers at the moment of failure, and it must lead with the wake/cache-write
economics, since $300-weekend runaway polling is the real failure mode.

**Why:** "Agents will get weird ideas because they love doing stuff" — naming a failure path
invites agents to exercise it; being blocked means not doing stuff, which agents avoid.

**How to apply:** happy-path skills describe only the happy path; recovery skills are
self-triggering, economics-first, and explicitly tell the agent when the situation is NOT an
emergency.
