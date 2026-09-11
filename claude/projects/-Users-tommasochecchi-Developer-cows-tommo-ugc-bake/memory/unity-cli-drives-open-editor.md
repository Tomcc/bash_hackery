---
name: unity-cli-drives-open-editor
description: "Run Unity play-mode tests without closing Tommo's editor, via unity command run_tests; includes the recompile step and the test_status polling gotcha"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 8eb14fef-01a5-45a1-aeff-51d5f466b9c5
  modified: 2026-09-03T07:26:40.116Z
---

`hammerbot robo test` needs the project lock, so it fails while Tommo has Unity open ("Please close
the Unity project", then gives up after 1m). Don't ask him to close it — the `unity` CLI drives the
live editor instead (see the `unity-cli` skill).

```sh
unity command recompile            # then poll recompile_status until "completed"
unity command run_tests --mode PlayMode --filter <TestName> --async_tests true --timeout 900
unity command test_status          # poll
```

**Why:** a play-mode test run takes ~5 s this way versus a full batch-mode boot, and it doesn't
interrupt what he's doing.

**How to apply:**
- **New test methods need `unity command recompile` first.** `run_tests` happily reports
  `total: 0` for a filter that matches nothing — it does not warn that the method doesn't exist.
  Confirm with `unity command eval` reflecting over the fixture type's methods.
- `test_status` returns **pretty-printed** JSON, so poll for `"status": "completed"` *with the
  space*. Matching `"result":"completed"` never fires and the loop burns its whole timeout — that
  cost 8 minutes of nothing.
- `Debug.Log` output is not in the tool result; read it from `~/Library/Logs/Unity/Editor.log`.
- `unity command eval` cannot see package internals, so code needing them must live in the
  asmref'd project assembly. See [[ugc-apv-bake-ladder]].
