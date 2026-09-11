---
name: apv-fixture-scene-facts
description: "How APV probe placement and lighting actually behave when building a bake fixture scene (Tommo's corrections)"
metadata: 
  node_type: memory
  type: project
  originSessionId: 8eb14fef-01a5-45a1-aeff-51d5f466b9c5
  modified: 2026-09-03T03:06:08.618Z
---

Learned while building `Assets/Tests/ApvCornellBox` (2026-09-02), mostly from Tommo correcting me:

- **A ProbeVolume is a "brush", not a boundary.** It only raises probe density inside itself; APV
  still fills the whole surrounding space with progressively coarser bricks (1/3/9/27 m). Do not
  shrink the volume to "tighten" a fixture — the low-res outside fill is intended, and the UGC
  baker will have to reproduce it.
- **Ensure the waste is zeroed.** In a closed test box the exterior probes should be pitch black.
  A lit exterior means light is leaking, and it's a much better bug signal than the interior.
- Two real leaks found this way: (1) HDRP's default HDRI sky lights the outside and feeds the
  bake — kill it with a `VisualEnvironment` override, `skyType = 0`, on the scene's Volume *and*
  point `StaticLightingSky` at that profile; (2) one wall had **no static flags**, so the
  lightmapper had a hole in the box. Check `GameObjectUtility.GetStaticEditorFlags` on every
  renderer, not just Cast Shadows.
- Byte-level "% non-zero" on a `CellData` blob is a useless emptiness check: L1 is stored as
  unorm around 0.5, so black probes are not zero bytes. Render or use the probe debugger instead.
- Rendering Debugger > Probe Volumes > Display Probes (shading mode SH) draws probe radiance into
  the **game view** too, so it will pollute automated captures. Tommo uses it constantly.
- HDRP fixed exposure: **higher EV = darker**. EV8 reads mid-gray in this 30 m box with a 300,000
  lumen baked point light.
- The APV settings the maintained scenes use (IntroSewer, SampleScene, Collector Prototype):
  `simplificationLevels 3, minDistanceBetweenProbes 1, useVirtualOffset 1, enableDilation 1,
  skyOcclusion 1`. Most other scenes have dilation/sky-occlusion off and are not the reference.

Related: [[ugc-apv-bake-ladder]], [[hdrp-leaked-volume-breaks-editor]]
