---
name: no-todowrite-tool-in-this-env
description: This environment exposes no TodoWrite tool; keep a session TODO file instead
metadata: 
  node_type: memory
  type: project
  originSessionId: 5c9cfda9-f868-492f-98f0-f4616ce3e788
  modified: 2026-09-06T23:04:44.627Z
---

There is no TodoWrite tool available in this Claude Code setup (checked 2026-09-06 via
ToolSearch — no match). The user noticed and asked why Claudes stopped making todo lists; the
answer is that the tool simply is not exposed here, not a behaviour change.

Workaround that worked: keep the queue in `/tmp/treasure-session-todo.md` and echo it back when
it changes. The user fires off many "TODO: ..." messages mid-turn while I work, and needs them
parked somewhere visible without derailing the current task.

Open question worth chasing: whether the tool can be re-enabled through settings. See
[[handoff-from-monorepo-session]] for how this project tracks pending work durably (QUESTIONS.md
is the real work queue; the tmp file is only for a single session).
