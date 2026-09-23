---
name: open-terminal-tab
description: >
  Open a new terminal tab to ask the user to run an interactive command, workflow, or login that needs a real TTY. For spawning a new CLAUDE session (resume/fork), see
  open-ghostty-session, which builds on this.
---

# Open a terminal tab

## When to spawn a tab

Spawn a Ghostty tab when:

- The command needs a TTY: browser logins (`gcloud auth login`, `az login`), `sudo` password
  prompts, interactive REPLs/installers. In the Bash tool these fail with "cannot prompt during
  non-interactive execution" or `sudo`'s "a terminal is required to read the password".
- The user should run or approve it themselves. (At the Claude prompt they can also use `!`.)
- You need their attention — `activate` brings Ghostty to the front.
- Live output deserves its own tab: a long build, a dev server, a log tail.

Otherwise just run the command in the Bash tool; a tab pulls focus.

## Spawn it

```bash
osascript -e 'tell application "Ghostty"
    activate
    set cfg to new surface configuration
    set initial input of cfg to "your-command-here" & return
    new tab in front window with configuration cfg
end tell'
```

`initial input` is typed into the new shell; `& return` runs it.

- **Always** run this Bash call with `dangerouslyDisableSandbox: true` — the sandbox blocks
  AppleScript with `-600 "Application isn't running"` even while Ghostty runs.
- **Always** target a window: bare `new tab` fails with `-1708 "Can't continue new tab"`. With no
  window open, use `new window with configuration cfg` (takes no target).

Variations:

```applescript
-- New window instead of a tab (no target needed):
new window with configuration cfg

-- Split the focused terminal instead of a new tab:
tell application "Ghostty"
    set t to focused terminal of selected tab of front window
    split t direction down with configuration cfg
end tell
```

Other optional `surface configuration` fields: `initial working directory`, `environment
variables` (list of `KEY=VALUE` strings), `command` (runs a binary instead of the shell; pair with
`wait after command` to keep the tab open), `font size`.

## Block until the command finishes

Block only when the step gates the rest of your turn (e.g. an auth the next command needs).
Otherwise spawn fire-and-forget and ask the user to ping you.

`osascript` returns immediately. To wait for the exit code, park on a FIFO (no `sleep` loop):

```bash
FIFO="$TMPDIR/done_$$.fifo"; rm -f "$FIFO"; mkfifo "$FIFO"

# The tab writes its exit code to the FIFO when done.
osascript -e "tell application \"Ghostty\"
    activate
    set cfg to new surface configuration
    set initial input of cfg to \"<your-command>; echo \$? > $FIFO\" & return
    new tab in front window with configuration cfg
end tell" >/dev/null

RESULT=$(cat "$FIFO")   # blocks until the spawned command exits
rm -f "$FIFO"
test "$RESULT" = 0
```

- **Always** set the Bash tool `timeout` (e.g. 300000 = 5 min); the read hangs your whole turn if
  the user wanders off. On timeout the tab keeps running — re-read the FIFO or go fire-and-forget.
- Escape `$?` as `\$?` so your shell doesn't expand it; leave `$FIFO` unescaped so it does.
- Make a fresh `$$`-suffixed FIFO per spawn; each is a single read/write.
- Leave the tab open so the user sees the result; append `&& exit` only if you want it closed.
