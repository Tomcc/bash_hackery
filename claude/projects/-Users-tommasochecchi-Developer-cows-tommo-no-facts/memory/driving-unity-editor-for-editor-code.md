---
name: driving-unity-editor-for-editor-code
description: "How to compile and exercise new Editor C# through a live Unity via unity-cli"
metadata: 
  node_type: memory
  type: reference
  originSessionId: 47b9ee99-e00e-41b1-9c85-947da6e3b18b
  modified: 2026-08-27T10:11:39.330Z
---

Loop for testing new editor-only C# against a live Editor (verified 2026-08-27, CLI 1.0.0-beta.5):

1. `unity command eval --code 'UnityEditor.AssetDatabase.Refresh(...ForceUpdate); ...RequestScriptCompilation(); return "go";'`
   — **a new file needs `AssetDatabase.Refresh` before `RequestScriptCompilation`**, or the compile
   silently doesn't include it and the type stays missing.
2. Wait ~40s. `EditorApplication.isCompiling` reads `idle` immediately and is useless as a signal.
3. Confirm the type exists before trusting a run: `System.Type.GetType("X, GameCode.Editor")`.

Gotchas that cost time:
- **Our assemblies are `GameCode` / `GameCode.Editor`, not `Assembly-CSharp`.** `GetType("X,
  Assembly-CSharp-Editor")` returns null and looks like a compile failure.
- `eval_file` runs *statements*, not a compilation unit: `using` directives fail to parse. Fully
  qualify, or rely on the game's own usings.
- Escaped `\"` inside `$"..."` in an eval file fails to parse; use string concatenation.
- **`hammerbot robo code-build` cannot run while the Editor is open** — it waits on the project lock
  and fails after 1 min. Use the Editor to compile, or close it.
- An un-awaited `UniTask` returned via reflection swallows exceptions, so a guard looks like it
  didn't fire. Await through `TaskUtil.BlockOn` to see the real throw.

**`AssetDatabase` is main-thread only, and `TaskUtil.BlockOn` runs on the thread pool.** Collect
asset data before the hop and pass it in; same for `EditorUtility` progress bars, which throw off
the main thread. This bug only appeared on a live run — it compiles fine. See
[[embeddings-store-immutable-open]] for the related store work.
