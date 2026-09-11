---
name: open-terminal-tab
description: >
  Open a new terminal tab to ask the user to run an interactive command, workflow, or login that needs a real TTY. For spawning a new CLAUDE session (resume/fork), see
  open-ghostty-session, which builds on this.
---

# Open a terminal tab (to run something, or to hand it to the user)

Your Bash tool is non-interactive and sandboxed. Some things just can't run inside it — they need a
real terminal the user can see and type into. A new Ghostty tab is one `osascript` call away.

## When to spawn a terminal (vs just using the Bash tool)

Spawn a tab when:

- **The command needs interactivity the Bash tool can't give.** Browser-popup logins (`gcloud auth
  login`, `az login`), `sudo` password prompts, interactive REPLs/installers, anything that reads
  from a TTY. These die in a Claude session ("cannot prompt during non-interactive execution").
- **You want the USER to run / approve it themselves.** Output lands in their own shell, and they
  make the judgment call. (Inside a Claude prompt the user can also use the `!` prefix; spawn a tab
  when you want a dedicated visible terminal, or they're not sitting at the Claude prompt.)
- **You need their attention.** `activate` pulls Ghostty to the front — use it to bring the user
  back when the next step is theirs.
- **There's live output worth watching in its own tab** — a long build, a dev server, a log tail.

Do NOT spawn a tab when the Bash tool can simply run the command (non-interactive, no TTY): just
run it. A tab is overhead and pulls focus.

## The command

```bash
osascript -e 'tell application "Ghostty"
    activate
    set cfg to new surface configuration
    set initial input of cfg to "your-command-here" & return
    new tab in front window with configuration cfg
end tell'
```

`initial input` is typed into the new tab's shell after launch; the trailing `& return` runs it.

## Gotchas (both cost real debugging time)

- **`new tab` REQUIRES an explicit target window.** A bare `new tab` fails with
  `-1708 "Can't continue new tab"`. Use `new tab in front window`. If no window exists, use
  `new window with configuration cfg` instead (that one takes no target).
- **From inside a Claude session, AppleScript to Ghostty is sandbox-blocked** (`-600 "Application
  isn't running"`, despite Ghostty running). Run the Bash tool with `dangerouslyDisableSandbox:
  true`. A plain user shell outside the sandbox has no issue.

## Variations

```applescript
-- New window instead of a tab (no target needed):
new window with configuration cfg

-- Split the focused terminal instead of a new tab:
tell application "Ghostty"
    set t to focused terminal of selected tab of front window
    split t direction down with configuration cfg
end tell
```

Other useful `surface configuration` fields (all optional): `initial working directory`,
`environment variables` (a list of `KEY=VALUE` strings), `command` (runs a binary *instead of* the
shell — pair with `wait after command` to keep the tab open after exit), `font size`.

## Waiting for the spawned command (blocking + exit code)

The `osascript` call returns immediately — the tab's shell is independent, so you normally can't
tell when its command finished or whether it succeeded. To BLOCK your turn until it does, use a
named pipe (FIFO): the reader parks until the writer writes — a clean kernel-level rendezvous, no
`sleep` loop (forbidden by CLAUDE.md and a wasted turn), no race on a sentinel file.

```bash
FIFO="$TMPDIR/done_$$.fifo"; rm -f "$FIFO"; mkfifo "$FIFO"

# Append `; echo $? > $FIFO` so the tab reports its exit code when it finishes.
osascript -e "tell application \"Ghostty\"
    activate
    set cfg to new surface configuration
    set initial input of cfg to \"<your-command>; echo \$? > $FIFO\" & return
    new tab in front window with configuration cfg
end tell" >/dev/null

RESULT=$(cat "$FIFO")   # BLOCKS here until the spawned command exits
rm -f "$FIFO"
test "$RESULT" = 0      # now you actually know if it succeeded
```

- **Always set the Bash tool `timeout`** (e.g. 300000 = 5 min). A blocking read hangs your ENTIRE
  turn until the command exits — if the user wanders off mid-login it hangs forever. On timeout the
  tab keeps running; re-read the FIFO or fall back to fire-and-forget.
- **Escape `$?` as `\$?`** inside the double-quoted `-e "..."` so YOUR shell doesn't expand it
  before the tab sees it. `$FIFO` (the path) is NOT escaped — you want your shell to substitute the
  real path in.
- **One-shot.** A FIFO is one read↔write rendezvous; make a fresh `$$`-suffixed FIFO per spawn.
- **The tab stays open after the command** unless you append `&& exit` — keeping it open lets the
  user SEE success/failure, usually preferable for interactive logins.

### Block, or fire-and-forget?

BLOCK when the spawned step gates the rest of your turn (e.g. an auth the next command needs), so
you can continue the moment it succeeds. Otherwise DON'T block — spawn fire-and-forget and ask the
user to ping you when done, freeing your turn for other work.
