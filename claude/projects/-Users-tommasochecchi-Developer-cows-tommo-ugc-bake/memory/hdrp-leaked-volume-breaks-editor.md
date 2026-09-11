---
name: hdrp-leaked-volume-breaks-editor
description: A leaked/unsaved HDRP VolumeProfile poisons the static VolumeManager and breaks rendering for the whole editor session (domain reload is off)
metadata: 
  node_type: memory
  type: feedback
  originSessionId: 8eb14fef-01a5-45a1-aeff-51d5f466b9c5
  modified: 2026-09-03T03:05:52.243Z
---

A `VolumeProfile` built at runtime with `CreateInstance` + `Add<Exposure>()` leaves a
**destroyed-object reference** in HDRP's static `VolumeManager` unless you either destroy it in
teardown or write the component into the asset with `AssetDatabase.AddObjectToAsset`.

**Why:** Robotopia has domain reload disabled, so `VolumeManager`'s statics survive play mode,
scene loads, everything. The symptom is a `MissingReferenceException: object of type 'Exposure'
has been destroyed` once per frame, and rendering breaks project-wide: production scenes go pure
white or opaque geometry stops drawing while sky and gizmos still render. It looks exactly like
"my scene is broken" and sent me down a multi-hour hunt through materials, static flags, culling
layers and frame settings. Only a full editor restart clears it.

**How to apply:**
- Put test object cleanup in `[TearDown]`, never at the end of the test body — a failed assert
  skips the tail and leaks. See `ProbeVolumeInjectionTests` (`Track()` + reverse-order teardown).
- Prefer using a *scene's own* Volume/camera over authoring render settings from a test.
- When "geometry doesn't render" / "everything is white" appears globally, restart the editor and
  re-check before debugging the scene. Confirm scope first by opening a known-good scene.
- `Add<T>()` on a persistent profile does NOT add the sub-asset; call `AddObjectToAsset` +
  `SaveAssets`, or the asset reloads with `components: [{fileID: 0}]`.

Related: [[ugc-apv-bake-ladder]]
