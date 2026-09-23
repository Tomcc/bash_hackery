---
name: open-ghostty-session
description: >
  Start a new Claude Code SESSION in a fresh terminal tab — a parallel agent, or resuming/forking a
  past session. Invoke when asked to "open a new session", "start claude in a new tab", spawn a
  parallel agent, or resume/fork a session by UUID. For the terminal-spawning mechanism itself
  (osascript, blocking, gotchas) see the open-terminal-tab skill, which this builds on.
---

# Start a Claude session in a new tab

Spawn the tab with **open-terminal-tab** (osascript, sandbox, `new tab` target). Put `claude` in
`initial input`:

```bash
set initial input of cfg to "claude" & return            # fresh session
set initial input of cfg to "claude -r <uuid>" & return  # resume a session
```

- **Always** spawn fire-and-forget — a Claude session never exits, so the blocking FIFO pattern
  would hang your turn.
- Find past session UUIDs with **session-lookup-search**; see live ones with
  **find-active-sessions**.

## Resume a session

- **Always** set `initial working directory of cfg` to the project root the session started in —
  `-r` looks sessions up by cwd, so a subdirectory (e.g. `tools/hammerbot`) silently finds nothing.
- Resume only dead sessions: `claude -r <uuid>` conflicts with a session open in another tab. A
  transcript written seconds ago is almost certainly live.
- For a live session, or to borrow its context, start a fresh `claude` with a first prompt like
  `Look at session <uuid> for context.`

## Fork yourself

`claude --fork-session --resume $CLAUDE_CODE_SESSION_ID` branches a copy with a new id. Neither side
sees the other's later turns, so divide work explicitly and keep the two off the same files.
