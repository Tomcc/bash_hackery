---
name: temp-dir-panics-in-hammerbot-unit-tests
description: crate::temp::dir fails inside hammerbot unit tests; use tempfile::tempdir instead.
metadata: 
  node_type: memory
  type: project
  originSessionId: e4be5310-e6d1-4dbb-8933-c58f8764cfe4
  modified: 2026-09-02T09:26:55.266Z
---

`crate::temp::dir(name)` needs the run-scratch dir that `main` claims at startup, so in a unit test
it fails with "this run has no scratch dir". Use `tempfile::tempdir()` (already a dependency) for
test scratch space. Also note `cargo test -p hammerbot --lib` doesn't work — it's a bin-only crate,
so pass `--bins`.

See [[reading-a-resources-textasset-from-a-built-player]] for the tests that hit this.
