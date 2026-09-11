---
name: verify-gating-before-flagging
description: Check the full gating chain (parent container + JS) before claiming a UI feature is exposed to players
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 0f0db024-ee75-44b5-801d-fd1b03a1b686
---

When claiming a UI feature is or isn't visible to players, trace the whole gating chain before
raising the alarm: the parent container's `hidden` attribute and the JS that toggles it, not just
the button markup and its click handler.

**Why:** during the 2309 release I told the user the launcher's "Create level" button was ungated
and would leak the unannounced level editor. The user said Massimo had gated it; checking the tag
showed `ugcSection().hidden = !isDevUser` in `launcher/src/main.ts` plus a `hidden` attribute on
`#ugc-section`. I had only read the button element and its handler, so the warning was wrong and
cost a round trip.

**How to apply:** applies to any "is this exposed?" question about launcher/UI code. Grep for the
container id, not just the control id, and read the state machine that sets visibility. Verifying
against the release tag (`git show <tag>:<path>`) rather than the working tree also matters, since
the working tree may be ahead.
