---
name: open-ghostty-session
description: >
  Start a new Claude Code SESSION in a fresh terminal tab — a parallel agent, or resuming/forking a
  past session. Invoke when asked to "open a new session", "start claude in a new tab", spawn a
  parallel agent, or resume/fork a session by UUID. For the terminal-spawning mechanism itself
  (osascript, blocking, gotchas) see the open-terminal-tab skill, which this builds on.
---

# Start a Claude session in a new tab

This is the Claude-session layer on top of **open-terminal-tab** — read that skill for the
`osascript` spawn mechanics, the sandbox/`new tab` gotchas, and the blocking-with-FIFO pattern. The
command you put in `initial input` is just `claude` (with flags):

```bash
# (run the open-terminal-tab osascript with…)
set initial input of cfg to "claude" & return            # fresh session
set initial input of cfg to "claude -r <uuid>" & return  # resume a session
```

A forked/resumed Claude session is interactive and never exits, so spawn it **fire-and-forget** —
do NOT use the blocking FIFO pattern on it (it would hang your whole turn).

## Finding the session UUID

Use **session-lookup-search** (rg over `~/.claude/projects/...`) to find a past session, and
**find-active-sessions** to see which are live right now.

## Three rules that each cost real debugging time

- **Set the tab's working directory to the session's PROJECT ROOT.** `--resume`/`-r` looks the
  session up under the project keyed by cwd, so launching from a subdirectory (e.g.
  `tools/hammerbot` when the session began at the repo root) silently fails to find it. Set
  `initial working directory of cfg` to the root the session started in.
- **Check the session is NOT already running before resuming.** `claude -r <uuid>` on a session
  already open in another tab conflicts. `find-active-sessions` shows live PIDs; a session whose
  transcript was written seconds ago is almost certainly live.
- **Forking yourself:** your own session id is in `$CLAUDE_CODE_SESSION_ID`.
  `claude --fork-session --resume <id>` branches a copy with a NEW id that runs independently — it
  does NOT see your subsequent turns and you don't see its. Divide work explicitly so the two
  branches don't race the same files.

## Resume vs. reference

- Session is **dead** → resume it directly: `initial input` = `"claude -r <uuid>"`.
- Session is **live** (or you want its context, not its history) → start a *fresh* session that
  references the old one by UUID: `initial input` = `"claude"`, then a first prompt like
  `Look at session <uuid> for context.` This is how ROB-699x issues were spun up off the parent
  model-database session.
