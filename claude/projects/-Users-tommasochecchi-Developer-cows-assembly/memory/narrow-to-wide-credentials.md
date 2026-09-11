---
name: narrow-to-wide-credentials
description: "On shared/team machines, add credentials only when a task needs them — never provision broadly and claw back."
metadata: 
  node_type: memory
  type: feedback
  originSessionId: a2b01b5f-0a04-4671-9df2-c0913e149626
---

Setting up the team-accessible assembly VM, I proposed provisioning it with the
full `assembly/shared` credential set up front. Tommo pushed back: that's
wide-to-narrow (remove privileges later), which is much harder than narrow-to-wide
(add as needed). Also: personal `gh auth login` / PATs make every action attributed
to *you* — wrong on a shared box.

**Why:** Removing access after the fact means proving nothing depends on it; adding
access is a clean, auditable, single-purpose step. Each credential added should have
a concrete triggering need.

**How to apply:** On shared/long-lived machines, start with the minimum and add each
credential when a task actually demands it (e.g. AWS creds were added only when
durable git auth + Bedrock concretely needed to read Secrets Manager). Prefer machine
identity (GitHub App installation tokens via a credential helper) over personal auth.
Related: [[assembly-vm-facts]].
