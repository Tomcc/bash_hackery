---
name: robo-build-install-needs-tag
description: "How to build and install a local Robotopia build the launcher will play, and the traps in the loop."
metadata: 
  node_type: memory
  type: project
  originSessionId: 60bc0b3e-fb85-4d38-9fd1-a393589dfd2e
  modified: 2026-08-28T20:46:37.293Z
---

Install a local build for the launcher with `hammerbot robo build -x --install`; it copies the build
to `~/Library/Application Support/Tomato Cake/launcher/` and writes `installed-build.json` as
`{"id":4294967295,"dev":true}`, which is what makes the launcher play it instead of fetching CI.

- `-x` is required (wipes `Build/` first, else "Build directory is not empty").
- The Unity Editor must be fully exited — Unity's project lock; wait for the process, not just the
  pipeline server, or `-x` fails with `os error 32`.
- Confirm the installed `Robotopia.app` mtime advanced before testing, or you test the old build.
- ~2 min per build on this Mac, so a build-per-step bisect is affordable.
- Add `--tag v1` only when you specifically want a CI-like build number; as of `c1e1632b05` an
  untagged build works (before that it threw in `ComputeVersionId` and robots went silent).
- `hammerbot extra-lints` cannot run in this worktree: "Repo root path too long, move it to
  something shorter than 50 characters" (our path is 52). Check line length by hand; CI covers it.

Full repro protocol for launcher-only bugs: staging Creator (`staging.tomatocake.dev/editor/index.html`)
→ boot the level → launcher plays the local build. See [[bisect-verify-both-ends-and-pin-the-tool]].
