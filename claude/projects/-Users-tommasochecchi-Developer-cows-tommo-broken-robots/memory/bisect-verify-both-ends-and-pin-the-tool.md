---
name: bisect-verify-both-ends-and-pin-the-tool
description: "Before bisecting Robotopia, reproduce the symptom at the bad end in the layer that actually fails, and pin one hammerbot binary for all steps."
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 60bc0b3e-fb85-4d38-9fd1-a393589dfd2e
  modified: 2026-08-28T20:46:26.023Z
---

Measure the reported-bad commit yourself before starting a `git bisect`, in the same layer the
report came from (Editor Play mode and an installed launcher build exercise different code), and
build every step with one hammerbot binary copied out of the tree (`cp target/release/hammerbot
/tmp/hammerbot-pinned`).

**Why:** on 2026-08-28 a "robots aren't talking" bisect returned four false `good` verdicts and then
blamed a launcher-only commit. Two separate causes: the symptom was launcher-only while I tested the
Editor, and my own untagged `robo build` was broken at every commit, so the result was constant.
A bisect trusts that the bad end is bad — when it isn't, git still names a commit that looks
authoritative. Older commits also build with older hammerbot, so the tool varies with the game
(pre-08-24 hammerbot resolves `unity` via PATH and dies on `unknown option '-batchmode'`).

**How to apply:** reproduce at the bad end first; if the user says code that worked recently is now
broken *unchanged*, stop bisecting — the variable is outside git (local state, backend, build flags).
Check the culprit's diff can physically reach the symptom before reporting it. Read
`~/Library/Logs/Tomato Cake/robotopia/Player.log` for the fatal line before building anything; it
named the cause here in one grep. See [[robo-build-install-needs-tag]].
