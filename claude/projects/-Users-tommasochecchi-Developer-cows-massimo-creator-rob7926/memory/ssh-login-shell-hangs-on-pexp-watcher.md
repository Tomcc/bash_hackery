---
name: ssh-login-shell-hangs-on-pexp-watcher
description: "ssh with an interactive zsh hangs on Tommaso's machines because pexp's background watcher inherits stdout; redirect to a file instead."
metadata: 
  node_type: memory
  type: reference
  originSessionId: 4e237cbd-1065-48bd-92a1-1b11704047ad
  modified: 2026-09-14T07:40:51.191Z
---

`shared.zshrc` sources `pexp_setup.sh`, which spawns `pexp_bin watch $$ &`. That daemon
inherits the SSH session's stdout, so `ssh host 'zsh -ilc "..."'` never returns — it looks
like a hung command, not a failure.

**How to apply:** redirect inside the remote command and read the file, e.g.
`ssh host 'zsh -ilc "..." > /tmp/out 2>/dev/null </dev/null; cat /tmp/out'`.
Non-login shells (`ssh host 'cmd'`) are unaffected since they skip `.zshrc`.

The `setup-new-mac` skill covers this and the rest of the remote-Mac gotchas in full.
