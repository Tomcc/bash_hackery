---
name: extralint-tests-dirty-the-working-tree
description: "hammerbot's extralint tests mutate real repo source files, and leave them mutated when they fail"
metadata: 
  node_type: memory
  type: project
  originSessionId: 83fb11f8-306a-4ed0-b774-01d68c630c2c
  modified: 2026-09-02T04:20:04.088Z
---

`cargo test -p hammerbot --bins` runs `extralint::tests`, which inject violations into **real
tracked source files** to check the linter catches them. A failed or interrupted run leaves the
mutation behind — I found `public async void TestBadMethod() {}` wedged into the top of
`Robotopia/Assets/Scripts/ActivityGroupActivator.cs`, after `#nullable enable`.

**Why it matters:** the leftover mutation makes the *next* run of `lint_unity_pool` and
`lint_merge_markers` fail, which reads as "my change broke two tests". It also silently stages a
junk line into any `git add -A`.

**How to apply:** always `git status` after running hammerbot's test suite, and `git checkout --`
any Unity source file it touched. When a hammerbot test failure looks unrelated to your change,
check the tree before believing it — baseline by stashing and re-running, as in
[[stale-hammerbot-binary-mimics-compile-failure]].

Unity player builds also `chmod +x` `vendor/getsentry-unity/.../sentry-cli-Darwin-universal`, a
mode-only change that is likewise never yours to commit.
