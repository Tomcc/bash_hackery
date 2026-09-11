---
name: ugc-apv-bake-ladder
description: "Status of the UGC baked-GI project (APV injection spike done; next is TS format writer, fake SH, WGSL baker)"
metadata: 
  node_type: memory
  type: project
  originSessionId: d6c35c67-41b9-4006-9a3d-f4bbe7f55ce6
  modified: 2026-09-03T09:07:19.756Z
---

Goal: bake APV global illumination for UGC levels outside Unity (in ugc_editor, WebGPU/WGSL
path tracer) and inject it at runtime. Agreed ladder (from session 79de7db3, 2026-09-02):

1. ✅ Injection spike — `Robotopia/Assets/Scripts/ProbeVolumeInjection/` on branch
   `tommo/ugc-bake` (commits 41fe16a53b, a8669dc91f). asmref + partial ProbeVolumeBakingSet.
   Validated by `ProbeVolumeInjectionTests`: cells load in a foreign scene, AND the injected data
   renders identically to a native bake on the `Assets/Tests/ApvCornellBox` fixture
   (injected MAE 0.000184; zeroed-SH control 0.458877). See [[apv-fixture-scene-facts]].
2. Format writer in TS: emit the .bytes blob layout + metadata (cellDescs, chunk sizes, bounds).
3. ✅ Hand-authored SH renders in-game (commit 99bf64dcfa). `InjectedRedOnlyFieldRendersRed`
   masks L0 down to red and injects: native RGB means (0.48,0.46,0.44) -> (0.42,0.00,0.00).
   Tommo's point: parity can't rule out a cache, because equality is what a stale path gives too;
   a colour Unity would never bake is the real discriminator. The green wall going *pitch black*
   is the bonus proof — an image-space tint would have left it dark red.
4. ✅ **END TO END (commit caa1cd6f51): Blender-baked GI, encoded outside Unity, renders in-game.**
   `BlenderBakedFieldLightsSceneLikeNativeBake` injects a `CellData.bytes` written by
   `write_apv_blob.py`. The blob is **byte-identical in size** to Unity's own — a free check on
   the layout.
5. ✅ **Artifact hunt done (commit 75dcfaf3c2, 2026-09-03): MAE 0.073 -> 0.022, Tommo judges the
   render "significantly better than Unity" (less noise).** All findings written up in
   `tools/probe_baker/README.md` — read that before trusting older notes here. Headlines:
   - Black box artifact = `cellDesc.probeCount` UNDERCOUNTS; chunk tails hold ~21k real probes.
     Reference v3 exports every slot of every chunk, with virtual offsets applied to positions.
     (The earlier "ruled out virtual offset, only 0.011 units" note was wrong twice over: walls
     sit exactly ON probe planes, so 0.011 decides which side of the wall a probe sees.)
   - Wall spots = coherent aliasing: all probes shared one fixed 16x16 direction grid. Now
     jittered per texel (hash in the OSL camera) and 64x64 by default. Fixed grids have LOWER
     RMS at equal rays but coherent error renders as visible patterns; incoherent noise doesn't.
   - Unity postprocesses its bake: direct L1 x0.922066, dering to |L1| <= L0 (found via
     `ProbePostProcessing.compute` in the editor app + decompiling UnityEditor.CoreModule).
     The gather replicates both.
   - Invalid probes (validity >= 0.25) are provably never rendered — a production gather can
     skip them (Tommo wants this; real scenes are full of them).
   - Open: the ~2.77 scale (refits 2.77-2.80). Next rung: TS format writer.
   Approach — **Blender/Cycles bakes outgoing radiance to a LIGHTMAP atlas,
   then a first-hit gather turns it into probe SH.** `tools/probe_baker/` (commits 33f1142032,
   c18a23a0a6). Lightmap beat vertex colours (~2.4us/texel vs ~10us/vert) and, decisively,
   decouples lighting resolution from topology so uploaded assets need no remeshing. See
   [[blender-headless-bake-facts]].
   - **Unity's SH convention, verified not guessed:** the shader reduces to
     `irradiance(N) = L0 + dot(L1, N)` (`SHEvalLinearL1` is a plain dot product), so estimating
     over uniform directions makes all basis constants cancel: **`L0 = pi*mean(L)`,
     `L1 = 2*pi*mean(L*d)`**. Checked analytically on a uniform hemisphere.
   - Storage is L0-relative and CLAMPED: `CompressSH`/`DecompressSH` in `ProbeGIBaking.cs` do
     `enc = v/(l0*4) + 0.5` then `Clamp01`, so strong directional light saturates L1.
   - Confirmed by comparison against Unity's own bake: L1 direction cosine 0.997 (95% aligned),
     L0 correlation 0.994. **Open problem: Unity's L0 is a consistent ~2.71x ours**, systematic
     (128 -> 512 directions barely changed the spread), cause unknown.
   - Two things a lightmap cannot supply: punctual lights have no geometry so their direct term
     needs an analytic delta projection (`L0 += F/4`, `L1 += F*w/2`) with a shadow ray; and probes
     inside solid geometry or outside the enclosure must be rejected (Unity dilates there).
   - **The gather is TWO CYCLES RENDERS, no tracer of our own** (Tommo's idea, commit 7372e99c54,
     `osl_probe_gather.py`). Render 1: bake the lightmap normally. Render 2: swap every material for
     `Emission(lightmap)`, set `max_bounces = 0`, and render a custom OSL camera where each tile is
     one probe's equirect capture — so a camera ray returns its first hit's baked texel and stops.
     Noise-free, so `samples = 1`. **0.114 us/ray**, 4.1 s for the full 36.4M-ray job vs an 11 s
     bake. See [[blender-headless-bake-facts]] for the verified OSL camera API.
     - **Batch renders MUST use a unique EXR path per batch.** Blender/OIIO caches images by
       filepath, so reusing one name silently fed batch 0's probe positions to all nine batches —
       the L0 ratio "regressed" 0.36 -> 0.12 with no error anywhere. Print a per-batch metric when
       fanning out like this; that is what makes such a bug visible at all.
     - Keeping the lightmap matters: `bpy.ops.object.bake` is Cycles' well-trodden path, and
       letting the OSL camera path-trace instead would discard the surface-radiance cache entirely.
     - Cross-validated against an independent numpy Moller-Trumbore gather: L0 ratio vs Unity
       0.3626 vs 0.3688, L1 cosine 0.9971 vs 0.9976. Two implementations agreeing means the
       ~2.76x Unity factor is real, and that the bespoke plane-bake ground truth
       (`probe_ground_truth.py`, which said we're 4/pi too bright) is the likely outlier.
   - Python per-ray was 2.8 ms/ray; vectorised numpy got 2.9 us/ray; Cycles gets 0.187 us/ray.
     No Rust/Embree needed for now — see [[ray-tracing-backend-for-gather]].
   - **Always restrict comparisons to interior probes.** Most of the 142k are waste: outside the
     enclosure rays escape to black while Unity's value is a dilated neighbour, and inside walls
     both are meaningless. Forgetting this made 66% of atlas tiles black and the numbers garbage.

Superseded plan (kept for context): WGSL path tracer + ported APV placement.
   Candidate raytracing backbone: three-mesh-bvh (zeux recommends; GPU raycast, JS only builds BVH).
   Placement reference: SIGGRAPH 2022 Advances course, "Probe-based lighting ... in Unity's
   Enemies" (F. Cifariello Ciardi) — advances.realtimerendering.com/s2022.

Key runtime facts: injected sets need disk streaming force-disabled; runtime TextAssets can't
hold binary (why the TextAsset plan was dropped); blob layout = dense per-cell slices in
cellDescs order.

CellData layout per cell (verified against `ProbeGIBaking.Serialization.cs`
`WriteToShaderCoeffsL0L1`), in `cellDescs` order:
- `L0ChunkSize * shChunkCount` bytes — half4 per probe: `(L0.r, L0.g, L0.b, L1_R.x)`,
  format `R16G16B16A16_SFloat`
- `L1ChunkSize * shChunkCount` bytes — byte4 per probe: `(L1_G.x, L1_G.y, L1_G.z, L1_R.y)`
- `L1ChunkSize * shChunkCount` bytes — byte4 per probe: `(L1_B.x, L1_B.y, L1_B.z, L1_R.z)`

L1/L2 are stored **normalised by L0 per channel**: `DecodeSH(l0,l1) = (l1-0.5)*2*2.0*l0`
(`DecodeSH.hlsl`, `APV_L1_ENCODING_SCALE 2.0`). So zeroing an L0 channel kills that channel's
L1 and L2 too — no half-float codec needed to mask a colour out.
