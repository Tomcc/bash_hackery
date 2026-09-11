---
name: open-unity-in-cow-workspace
description: How to open a Robotopia CoW/throwaway workspace in Unity without adding it to Unity Hub — launch the editor binary directly with -projectPath
metadata: 
  node_type: memory
  type: reference
  originSessionId: 9acf4b2c-caef-45e1-984e-d39006d7b368
---

`open SomeScene.unity` (or opening via Finder) routes through **Unity Hub**, which pops a license
dialog and won't open a project that isn't registered in the Hub. In throwaway CoW workspaces
(e.g. `~/Developer/cows/<name>/`) the project isn't in the Hub, so `open` just shows the license
popup and does nothing — adding each clone to the Hub every time is annoying.

**Fix: launch the editor binary directly, bypassing the Hub.**

1. Read the project's Unity version: `Robotopia/ProjectSettings/ProjectVersion.txt`
   (`m_EditorVersion:`, e.g. `6000.0.31f1`). Editors live in
   `/Applications/Unity/Hub/Editor/<version>/Unity.app/Contents/MacOS/Unity`.
2. Confirm no editor already holds this project: check `Robotopia/Temp/UnityLockfile` exists = locked.
3. Launch detached:
   ```sh
   BIN="/Applications/Unity/Hub/Editor/6000.0.31f1/Unity.app/Contents/MacOS/Unity"
   nohup "$BIN" -projectPath "/abs/path/to/<workspace>/Robotopia" > /tmp/unity.log 2>&1 &
   ```
   No license popup; the lockfile appears within ~30s as it boots. Pass `-projectPath` (the project
   dir), NOT a scene path — Unity opens the last-open scene, and the project opens regardless of
   scene, which is all that's needed to trigger asset (re)imports.

Multiple editor instances on ONE machine are fine as long as they're DIFFERENT projects (Unity 6).
A second CoW clone and the original `tomatocake-dev` can both be open at once. One editor per
project though — the lockfile enforces that.

Note the CLAUDE.md hint to "`open` SampleScene.unity" is the thing that DOESN'T work for CoW clones
— it goes through Hub. Also: the real project scene is
`Robotopia/Assets/Scenes/SampleScene/SampleScene.unity` (an HDRP-sample `*SampleScene.unity` also
matches a naive `fd SampleScene` — don't open that one).

Related: [[embeddings-v2-provider-quirks]] (local server + Unity is how ROB-6424's lore re-bake was
tested against unmerged server code — Unity auto-detects `just local` on port 9000, so imports hit
branch code without a prod deploy).
