---
name: brew-rustup-has-no-cargo-shim
description: "Homebrew's rustup formula ships only a `rustup` shim — no cargo/rustc on PATH and no ~/.cargo/env to source."
metadata: 
  node_type: memory
  type: reference
  originSessionId: 4e237cbd-1065-48bd-92a1-1b11704047ad
  modified: 2026-09-11T20:44:02.273Z
---

`brew install rustup` gives you `/opt/homebrew/bin/rustup` and nothing else. After
`rustup default stable`, `cargo` lives only at
`~/.rustup/toolchains/stable-aarch64-apple-darwin/bin/cargo`, and `~/.cargo/env` is never
created — so the usual `. "$HOME/.cargo/env"` line in `.zshenv` silently does nothing.

**How to apply:** run builds via `rustup run stable cargo ...` (bare `cargo` fails with
`could not execute process rustc -vV`), and add `export PATH="$HOME/.cargo/bin:$PATH"` by
hand so `cargo install`ed binaries are reachable.

Related: [[ssh-login-shell-hangs-on-pexp-watcher]].
