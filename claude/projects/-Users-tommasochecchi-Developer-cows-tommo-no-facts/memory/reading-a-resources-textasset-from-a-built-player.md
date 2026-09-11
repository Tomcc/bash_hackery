---
name: reading-a-resources-textasset-from-a-built-player
description: "How to read a Unity Resources TextAsset (e.g. build_info.txt) back out of a built player, without Unity."
metadata: 
  node_type: memory
  type: reference
  originSessionId: e4be5310-e6d1-4dbb-8933-c58f8764cfe4
  modified: 2026-09-02T09:26:49.588Z
---

Unity bakes `Assets/Resources/*.txt` into `<player>/…/resources.assets` as a TextAsset, laid out as
`<u32 LE length><name bytes><pad to 4><u32 LE length><text bytes>`. File-absolute 4-byte alignment
holds, so searching for the length-prefixed *name* (not the bare name — it also appears as plain
text elsewhere) and then reading the next aligned u32 + bytes gets the content. Verified on real mac
and against `hammerbot robo build -n <tag>` output; `build_info_in_player` in `hammerbot.rs`.

resources.assets is where the *Resources* folder lands specifically — `levelN`/`sharedassetsN` hold
scene assets. Player data dirs: `Contents/Resources/Data` (mac .app), `Robotopia_Data` (Windows).

Handy for asserting a built player really carries something, without launching Unity.
