---
name: unity-batchmode-has-no-frame-cap
description: "Unity PlayMode tests in batchmode spin the player loop at 10k+ fps, so frame-count and wall-clock assertions can't detect main-thread frame-pacing"
metadata: 
  node_type: memory
  type: feedback
  originSessionId: af2df019-7eb3-4c6f-89cd-e988957f6b58
  modified: 2026-09-11T19:38:54.869Z
---

Never pin a Unity performance bug with a frame-count or elapsed-time assertion in a PlayMode test. `hammerbot robo test` runs `-batchmode -nographics`, where the player loop has no frame cap: measured 9000 frames in 0.6s (~15k fps). A main-thread await that costs a whole frame in a real 60fps player costs ~40µs there, so a stall that lasts two minutes in game finishes in 0.3s under test.

**Why:** cost the test measures ≠ cost the player pays. Frame count reads as a real number and quietly measures nothing.

**How to apply:** assert the *cause*, not the symptom. For "this must not run on the main thread", capture `Thread.CurrentThread.ManagedThreadId` from inside the hot loop and assert the main thread's id never appears — binary and machine-independent. An injectable callback the code already has (`EmbeddingsCache`'s `utcNow`, called once per slot write) works as the probe with no test-only hook. Verified on ROB-7926, where a frame-count version of the same test reported 1760 frames and passed nothing useful.
