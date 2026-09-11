---
name: unity-open-resolves-hub-registry-first
description: "`unity open <name>` matches the Hub registry before local paths, so in a multi-cow checkout it silently opens the wrong working copy"
metadata: 
  node_type: memory
  type: reference
  originSessionId: 83fb11f8-306a-4ed0-b774-01d68c630c2c
  modified: 2026-09-02T03:27:32.668Z
---

`unity open Robotopia` from inside a cow does **not** open `./Robotopia`. The name is matched against
the Hub project registry first, which resolves `Robotopia` to whichever copy is registered (here
`~/Developer/tomatocake-dev/Robotopia`). It exits 0, prints nothing, and you are now testing a
different working copy with its own uncommitted state.

**How to apply:** always pass an absolute path — `unity open /full/path/to/cow/Robotopia`. It warns
`"..." was not found in the Hub project registry, opening as a file path`, which is the *success*
signal here, not a problem. Verify with
`pgrep -fl 'Unity.app/Contents/MacOS/Unity'` and check `-projectpath`; `unity status` can report an
empty table even while an Editor is running, so it is not a reliable check.

Related: [[driving-unity-editor-for-editor-code]], [[unity-temporary-cache-path-is-tmpdir]].
