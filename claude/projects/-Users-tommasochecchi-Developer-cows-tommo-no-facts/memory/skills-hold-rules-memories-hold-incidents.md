---
name: skills-hold-rules-memories-hold-incidents
description: "Tommo wants incident/debugging knowledge in memories, not added to team skills"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 47b9ee99-e00e-41b1-9c85-947da6e3b18b
  modified: 2026-08-27T08:50:22.057Z
---

Put what a session taught you in a memory, not in a skill. Tommo pushed back twice on notes added
to `hammerbot-manual`: first "that belongs more in a memory than the skill", then "No just don't add
anything to the skill! Only memories please!"

**Why:** skills are team-facing reference loaded into every relevant session, so a paragraph about
one machine's stale binary is context cost for everyone and buries the commands people came for.
Memories are per-developer and not shared with the team.

**How to apply:** default to a memory for anything discovered while debugging. Only edit a skill
when the user asks, or when the command reference itself is factually wrong (a flag changed, a
documented command no longer exists). When editing one anyway, follow `create-skill`: rules not
stories, one imperative per bullet, no session anecdotes. See
[[stale-hammerbot-binary-mimics-compile-failure]] for the incident that prompted this.
