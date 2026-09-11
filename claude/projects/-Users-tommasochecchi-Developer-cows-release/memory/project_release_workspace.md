---
name: release-workspace-branch
description: The cows/release checkout is a throwaway copy-on-write workspace; its tommo/release branch must never be merged to main
metadata: 
  node_type: memory
  type: project
  originSessionId: 0f0db024-ee75-44b5-801d-fd1b03a1b686
---

`/Users/tommasochecchi/Developer/cows/release` is a throwaway copy-on-write workspace, and its
`tommo/release` branch is not meant to be merged into `main`. Commits made here (e.g. skill or
tooling tweaks during a release) must be cherry-picked onto `tommo/dev` at the end of the session.

**Why:** the workspace exists only to give a release its own checkout, so `ci-mac` can check out
tags without disturbing the user's real working tree. The branch is scratch space, not a feature
branch.

**How to apply:** before finishing any session in this directory, check
`git log --oneline tommo/dev..tommo/release` for commits that need porting, and cherry-pick them
to `tommo/dev`. Do not propose `hammerbot gg merge-main` from this branch.
