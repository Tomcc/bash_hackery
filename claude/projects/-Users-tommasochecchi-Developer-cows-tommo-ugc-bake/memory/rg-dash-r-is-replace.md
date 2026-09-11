---
name: rg-dash-r-is-replace
description: "rg -r is --replace, not recursive; it silently rewrites every match in the output"
metadata: 
  node_type: memory
  type: reference
  originSessionId: cc1bf5cd-c145-467f-bcd8-7ee7bc762c8d
  modified: 2026-09-03T09:07:56.277Z
---

`rg -rn "pattern" dir` does NOT mean recursive — `-r` is `--replace`, so `-rn` replaces every
match with the literal text `n`. Output looks plausible but is corrupted (e.g. "Rendering" with
"dering" matched became "Renn"), which cost two confused reads in one session. rg is already
recursive by default; never pass `-r` unless replacing.
