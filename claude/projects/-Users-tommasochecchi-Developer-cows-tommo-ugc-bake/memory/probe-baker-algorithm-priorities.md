---
name: probe-baker-algorithm-priorities
description: "What actually makes an offline SH probe baker good, and why the choice of ray-tracing backend (OptiX / WebGPU / Blender) is the less important decision"
metadata: 
  node_type: memory
  type: reference
  originSessionId: 8eb14fef-01a5-45a1-aeff-51d5f466b9c5
  modified: 2026-09-03T04:46:35.166Z
---

Researched 2026-09-02 for step 4 of [[ugc-apv-bake-ladder]] (beating Unity's noisy APV bake).

**OptiX 9.1.0 provides only:** acceleration-structure build, hardware traversal, primitive
intersections, instancing, the program/SBT model, Shader Execution Reordering, and a **2D image**
denoiser. It provides **none** of: light selection, BSDF sampling, path integration, NEE, MIS,
QMC samplers, light trees, path guiding, ReSTIR. So OptiX, three-mesh-bvh+WGSL, and Embree all
leave the integrator to us — the backend choice does not buy quality.

**What actually beats brute-force MC for a low-frequency SH target, in priority order:**
1. NEE + MIS — essential; this is the fix if the baker is "shoot rays and pray"
2. Owen-scrambled Sobol QMC (per-probe scramble keys) — big win, nearly free
3. Adaptive sampling driven by variance of the SH coefficients — often the biggest total-time win
4. Light tree (Conty Estévez & Kulla, HPG 2018) — only once emitters number in the hundreds+
5. Path guiding (Müller SD-tree; OpenPGL 0.7.1) — only for indirect-dominated interiors
6. ReSTIR / RTXDI 2.3.0 — mostly **not** worth it offline; GRIS spatial reuse is the offline
   analogue but adjacent probes straddle walls and reservoirs tuned for luminance are poor
   estimators for 9 *signed* SH moments

**Accumulate SH directly** — do not render a cubemap then project. Each path contributes to all
coefficients at once: `c_lm += L(w) * Y_lm(w) / p(w)`. Lambertian convolution afterwards, band
multipliers A0=π, A1=2π/3, A2=π/4 (Ramamoorthi & Hanrahan 2001). Unity's exact sign/normalisation
convention must be verified against `WriteToShaderCoeffsL0L1` before trusting any comparison.

**Denoising:** OIDN 2.5.1 and the OptiX denoiser are image denoisers and are the wrong tool —
SH coefficients past l=0 are signed, atlas neighbours aren't spatial neighbours, and channels
co-transform under rotation. Correct approach is a confidence- and visibility-weighted filter on
a probe *graph* (reject neighbours across walls), or filter octahedral directional bins before
projecting to SH. No turnkey library exists.

**Reusable prior art:** RTXGI-DDGI 1.3.7 for probe relocation/classification/validity and
visibility-aware interpolation (not for its estimator). RTXGI 2.3.2 is NRC/SHaRC real-time
caches, not a reference baker.

**Oracles for validation:** Mitsuba 3.9.0 (custom sensors, scriptable — better fit than Blender
for "measure radiance at N points") and Embree 4.4.1 for a CPU reference traversal.

## Surface-radiance cache + gather (Tommo's idea, 2026-09-02) — established prior art

Bake converged *outgoing radiance* on surfaces once, then each probe traces only **first-hit**
rays and looks the radiance up. Multi-bounce GI is already folded into the cache, so probe
generation needs no NEE/MIS/guiding at all. Cost goes from
`probes × dirs × path_length` to `cache_points × full_GI + probes × dirs × first_hit`, which wins
big when probes (142k here) outnumber cache points.

Prior art: Frostbite (shared solver feeds both lightmaps and irradiance volumes), Enlighten
(radiosity solution → lightmaps + SH probes), RenderMan point-based GI (radiosity point cloud →
final gather), Godot LightmapGI. Notably Unity's Progressive Lightmapper explicitly does *not*
do this — it computes texels independently, which is part of why it's slow and noisy.

**Prefer surfels / point cloud over a UV lightmap:** avoids chart seams, filtering bleed between
islands, and makes world-position lookup natural. Decisive for us — the UGC editor has no UV2 or
lightmap concept at all, and levels are *instanced* prefab/model pieces that share UVs, so a
lightmap would require inventing per-instance atlas packing. (EEVEE Next's own probe baker uses
surfels, which is a good sign for the approach.)

**The classic bug:** the cache must hold outgoing radiance `ρE/π + Le`, not irradiance. Never
apply albedo or `1/π` twice. Validate on a white Lambertian box with a known-area emitter by
comparing a full path-traced panorama against a gather-based one.

## Blender: what it can and can't do

- **It CAN bake light probes** (EEVEE Next 4.2+ "Light Probe Volume", `bpy.ops.object.
  lightprobe_cache_bake`), but it stores **L1 only** (4 coeffs/channel) where Unity wants L2 (9),
  it's baked by EEVEE's GPU surfel baker rather than Cycles, and **bpy exposes no way to read the
  coefficients back** — only to trigger the bake. Reading them needs .blend DNA parsing or a
  source patch. Not a usable data source as-is.
- **Per-probe Cycles panoramas:** ~57 ms *fixed* overhead per `bpy.ops.render.render()` once warm
  (measured, see [[blender-headless-bake-facts]]), before any path tracing. At 142k probes that's
  still >2 h of pure overhead. Viable as an oracle for a handful of probes; not as a baker.
- **Cycles bake → vertex colours** works headless and is the engine for the cache idea above; it
  sidesteps the UV problem entirely. API and photometric units both verified — see
  [[blender-headless-bake-facts]].

## Browser: nothing production-grade out of the box

`three-gpu-pathtracer` **0.0.23** is not naive — it has direct-light sampling with MIS,
environment-map importance sampling, and Owen-scrambled Sobol. But: WebGL 2 only (not WebGPU), no
light tree, **no MIS for emissive triangles**, and only a simple edge-aware spatial denoiser.
`strahl` is a WebGPU path tracer but research-grade. `oidn-web` 0.3.2 gives OIDN-style denoising
via WebGPU. There is **no maintained WASM build** of Cycles, PBRT, Mitsuba or LuxCore.
