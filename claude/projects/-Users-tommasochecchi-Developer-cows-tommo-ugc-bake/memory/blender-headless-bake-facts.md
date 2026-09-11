---
name: blender-headless-bake-facts
description: "Measured Blender 5.2.1 headless bake timings on the M3 Pro, the Cycles kernel cache location, the confirmed vertex-colour bake API, and the bpy edit-mode-hangs-in-background gotcha"
metadata: 
  node_type: memory
  type: reference
  originSessionId: 8eb14fef-01a5-45a1-aeff-51d5f466b9c5
  modified: 2026-09-03T06:37:08.256Z
---

Benchmarked 2026-09-02 for step 4 of [[ugc-apv-bake-ladder]]. Workload = the Cornell fixture
(`cornell.blend`, see [[apv-fixture-scene-facts]]) tessellated to 0.5 m edges = 148,727 verts.
Machine: Apple M3 Pro, 12 CPU cores / 18 GPU cores, Blender 5.2.1, Cycles Metal.

## Vertex-colour bake API (confirmed working headless)

```python
scene.render.bake.target = "VERTEX_COLORS"
obj.data.color_attributes.new(name="Radiance", type="FLOAT_COLOR", domain="POINT")
bpy.ops.object.bake(type="COMBINED")   # needs objects selected + one active
```
Reads back via `obj.data.color_attributes["Radiance"].data[i].color`. No UVs, no atlas packing.

**Units validated:** with `light.energy = unity_lumens` verbatim, the ceiling's peak baked value
was 1379 against a hand-computed `E*rho/pi = ((300000/4pi)/2^2)*0.72/pi = 1368`. That confirms
`energy = lumens` (NOT lumens/683) makes Cycles' linear output numerically equal Unity's nits.

## GOTCHA: multi-object edit mode silently makes per-object loops explode

Edit-mode operators DO work in `--background` (verified: `mode_set`, `mesh.subdivide`,
`uv.smart_project`, `pack_islands` all fine). The trap is that objects loaded from a .blend arrive
**already selected**, so `mode_set(mode="EDIT")` enters *multi-object* edit mode and
`bpy.ops.mesh.*` hits every selected object. A loop that means to subdivide one mesh per iteration
instead subdivides all of them every iteration — 8 objects x 8 cuts grew ~9^8 and looked like a
hang. Always `bpy.ops.object.select_all(action="DESELECT")` and select only your target, or use
`bmesh` (no operator context, inherently per-object).

Also: **always `flush=True`** your prints, or a hang looks like total silence through a pipe.

## Custom OSL camera (Blender 4.5+) — verified API, because the docs and web search were wrong

Renders many probe captures in ONE render: each tile of the image is one probe's equirectangular
view. Used for the probe gather in [[ugc-apv-bake-ladder]].

```python
camera.type = "CUSTOM"
camera.custom_mode = "INTERNAL"        # or EXTERNAL + custom_filepath
camera.custom_shader = bpy.data.texts["cam.osl"]
scene.cycles.shading_system = True     # WITHOUT THIS THE CAMERA RENDERS BLACK
scene.cycles.use_adaptive_sampling = False   # no fixed per-pixel sample count otherwise
scene.cycles.use_denoising = False           # would smear radiance across tile boundaries
scene.cycles.pixel_filter_type = "BOX"       # width 1 confines samples to their own pixel
```
- OSL outputs must be named exactly `position`, `direction`, `throughput`.
- Sensor input is `camera_shader_raster_position()`, **normalised 0..1** (not P in mm).
  `getattribute("cam:resolution", ...)` is NOT documented — inline the resolution instead.
- **Outputs are CAMERA space.** For a camera at the origin with identity rotation the world
  mapping is **`(x, y, -z)`** — measured by rendering four candidate conventions; the identity
  mapping renders pure black.
- `bpy.types.Camera` has no `custom_shader` in `hasattr()` on the *type* — RNA properties don't
  show up that way. Introspect `cam.bl_rna.properties` instead.
- **OSL runs on CPU and NVIDIA OptiX ONLY — never Metal, HIP or oneAPI.** See
  [[ray-tracing-backend-for-gather]].
- `texture()` inside a camera shader is undocumented and unverified — that's the open risk for
  feeding 142k arbitrary probe positions.

## Cycles kernel cache

Lives at `$(getconf DARWIN_USER_CACHE_DIR)org.blenderfoundation.blender` on macOS — NOT in
`~/Library/Caches/Blender` or `~/.cache/cycles`. ~50 MB after one bake+render.

## Timings

| mode | render 64spp 512² | bake 148k verts |
|---|---|---|
| **first ever on the machine** | **113 s** | — |
| cold (cache cleared, reproducible) | 10.8 s | 14.1 s |
| warm, fresh process | 1.0 s | 4.7 s |
| warm, 2nd+ in same process | 0.94 s (0.57 s with `use_persistent_data`) | 4.2 s |
| CPU (12 cores) | 4.45 s | 6.9 s |

- Bare `blender --background` startup: **0.56 s** warm, 1.06 s cold.
- `bpy.ops.wm.open_mainfile`: **6–10 ms**. Reopening a .blend does NOT drop warm kernels.
- Fixed per-render overhead inside a warm process (samples=1): **57 ms** — much better than the
  "50–500 ms" I'd previously assumed.
- `scene.render.use_persistent_data = True` saves ~0.37 s/render of scene re-sync.
- Tessellation to 0.5 m: 0.26 s for 148k verts.

**The 113 s is one-time per install**, not per cache-clear: Apple builds a monolithic Metal PCM
and ~129 MB of it persists in a system location outside Blender's own cache dir.

## Tessellation density: BVH is fine, bake has a fixed floor

Swept 8 m → 0.25 m edges on the fixture (728 → 596,314 verts, 819× geometry), one warm process:

| edge | verts | render 512²/64spp | bake | µs/vert |
|---|---|---|---|---|
| 8 m | 728 | 1.17 s | 3.23 s | 4430 |
| 2 m | 9.3k | 1.07 s | 3.26 s | 351 |
| 1 m | 37k | 1.12 s | 3.49 s | 94 |
| 0.5 m | 149k | 1.29 s | 4.44 s | 30 |
| 0.25 m | 596k | 1.63 s | 9.17 s | 15 |

- **Render (fixed pixel work) grew only 1.6× for 819× the geometry** — Cycles' BVH scales fine,
  so tessellating hard is cheap for traversal.
- **Bake ≈ 3.2 s fixed + ~10 µs/vert.** Density is nearly free below ~100k verts: 728 verts costs
  the same as 37k. Extrapolates to ~13 s at 1M verts, ~53 s at 5M.
- The floor is **not** tracing: samples=1 and samples=64 both take ~3.0 s at 728 verts, and it does
  not amortise across repeated bakes in one process. `prefs.kernel_optimization_level = "OFF"`
  (Metal only) cuts it to 2.4 s but costs ~3% throughput at 596k verts — keep the `FULL` default.
  The remaining ~2.4 s is unattributed per-bake overhead; ignorable at production scale.

## What this means for a bake server

Daemon mode saves only ~1.4 s/job when warm (0.56 s startup + 0.44 s device init + sync). The
real argument for it is **cold containers**: a fresh instance pays 10–14 s, and a fresh *image*
pays up to 113 s. So **pre-warm the kernel cache into the container image** and keep workers alive;
the daemon loop itself is trivial (`open_mainfile` per job in one long-lived process).

GPU was only 1.6× CPU on the bake — this scene is far too small to saturate the GPU, so that
ratio is not predictive. And Metal kernel-compile numbers do **not** transfer to an OptiX/Linux
box; only the cold/warm/persistent *pattern* does.
