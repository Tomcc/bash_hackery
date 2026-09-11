---
name: stale-hammerbot-binary-mimics-compile-failure
description: "A stale ~/.cargo/bin/hammerbot made robo code-build fail in 7s, looking like a C# error"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 47b9ee99-e00e-41b1-9c85-947da6e3b18b
  modified: 2026-08-27T08:48:10.075Z
---

When a `hammerbot` command fails instantly, check `ls ~/.cargo/bin/hammerbot` before debugging the
code. On 2026-08-27 a copy there from a *different checkout* (`tomatocake-dev`) predated the
Unity-CLI editor lookup, so `robo code-build` launched the `unity` CLI instead of the Editor and
died on `unknown option '-batchmode'` in ~7s with no log written.

**Why:** the bare `hammerbot` word doesn't expand to the team alias in a non-interactive tool
shell, so it silently reaches that binary. Debugging cost ~15 minutes of probes that never printed,
because the source being edited was not the source being run.

**How to apply:** invoke it as `cargo run --release -p hammerbot --features aws -- <args>`. Never
`cargo install` hammerbot to "fix" this — that recreates the footgun, and Tommo removes it on
purpose. See [[hammerbot-manual]] for the committed rules.
