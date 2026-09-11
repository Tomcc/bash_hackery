---
name: diagnose-before-fixing
description: Tommaso pulls me back when I latch onto a plausible fix before the actual failure is diagnosed
metadata: 
  node_type: memory
  type: feedback
  originSessionId: e94164d8-1b49-4e8a-9fb6-c45140edee9a
---

On ROB-7205 I found a real, plausible issue (qwen3-embedding-0.6b not public:true) and
started implementing a fix for it before I'd actually explained the CI failure. Tommaso
corrected two things in quick succession: (1) my assumption that CI is non-dev was wrong (CI
uses a GitHub PAT → dev scope), which invalidated the public-flag theory as the CAUSE; and
(2) "don't let me distract you — the public access is a secondary thing, the original goal is
still undiagnosed."

**Why:** A plausible-but-wrong fix wastes effort and can mask the real bug. The decisive clue
here (ci/2235 had ZERO embedding errors yet the IDENTICAL 130+80 Odin errors) was sitting in
the data the whole time and pointed straight at cached stale artifacts — a totally different
mechanism than the public flag.

**How to apply:** Before committing to a fix, state the failure mechanism end-to-end and check
it against ALL the evidence (esp. the before/after CI builds). Separate "latent bug I happened
to find" from "the thing that actually caused this ticket's symptom." Don't let a secondary
finding pull focus until the primary is diagnosed. Verify load-bearing assumptions (like who
authenticates as dev) instead of asserting them. See [[embedding-failed-import-cached-empty]].
