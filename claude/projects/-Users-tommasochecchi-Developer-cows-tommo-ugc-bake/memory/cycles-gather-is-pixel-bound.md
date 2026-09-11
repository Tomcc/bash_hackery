---
name: cycles-gather-is-pixel-bound
description: "The APV probe gather's cost is Cycles' per-pixel film overhead, not ray traversal — and the fix (samples instead of pixels) cut the gather 7x"
metadata: 
  node_type: memory
  type: reference
  originSessionId: 5b392b67-54a1-44e6-b018-e7af5220287e
  modified: 2026-09-03T18:59:05.142Z
---

Measured 2026-09-03 while dockerising `tools/probe_baker` for vast.ai (see
[[ugc-apv-bake-ladder]]). The headline: **OSL-on-OptiX works and does not help.**

## OSL on OptiX: confirmed working

Blender 5.2's custom camera (`camera.type = "CUSTOM"`) runs on **CPU and OptiX only** — that part of
[[blender-headless-bake-facts]] holds, and on a 3090 the whole gather ran on device: the
`texture()` probe-position lookup and `cellnoise` jitter included. L0 ratio 2.7352 vs the Mac's
2.7352. So the port itself was a non-event; `bake_lib.use_gpu` picks OptiX when it exists.

## But the trace was never the bottleneck

Per 16,384-probe batch (67M rays) on an RTX 3090, measured:

| step | seconds | device |
|---|---|---|
| OSL camera render | 6.9 | OptiX |
| EXR write | 3.7 (1.5 at fp16) | CPU + disk |
| atlas readback | 1.4 | CPU |
| numpy tile→SH projection | 5.4 | CPU, 1 thread |

Discriminating experiments, all on the same box:
- Plain equirect camera instead of OSL: 11.5 s → 9.6 s. **OSL is not the cost.**
- Same OSL render forced to CPU: 21.0 s. **The GPU is doing real work** (1.8×), just not much.
- `nvidia-smi` reads 0% util with ~2.3 GB allocated during the gather.

Both machines land at **~6.7 Mrays/s** — M3 Pro on CPU-OSL and 3090 on OptiX alike, three orders
below what a 3090 traces. The cost is **Cycles' per-pixel film bookkeeping on a 67-megapixel, 1-spp
render**, so the gather scales with *pixels*, not rays, and GPU choice barely moves it. End to end
the 3090 took 180 s where the M3 Pro takes 103 s, because a vast container is CPU-throttled (8.6
cores of a 72-core host) and every CPU-side step loses to a laptop.

Corollary: **don't benchmark GPUs for this workload until the pixel count changes** — you would be
measuring rented vCPUs. And Embree is the wrong answer on an NVIDIA box (its GPU backend is
Intel-only, per [[ray-tracing-backend-for-gather]]), which puts everything back on that vCPU.

## The fix, now measured and shipped (commit 95dbd75a46)

**Decisive experiment:** hold the resolution fixed, go 1 -> 4 samples per pixel. Four times the rays
cost **4.7% more time** (8.01 s -> 8.39 s per batch on the 3090). Solving the two terms: 7.89 s of
film bookkeeping against **0.125 s of actual tracing** — tracing is 1.6% of the render.

So buy the same 4096 directions per probe with 1/16th the pixels: `--tile-size 16
--gather-samples 16` (now the defaults). It only works because a width-1 BOX pixel filter jitters
the raster position *per sample*, so the fractional part of `camera_shader_raster_position()` is the
sampler's own stratified offset — the camera shader uses it directly. A per-pixel hash
(`cellnoise(px, py)`) would give all 16 samples of a pixel the same ray.

| gather, 145,557 probes / 597M rays | tile 64, 1 spp | tile 16, 16 spp |
|---|---|---|
| RTX 3090 (OptiX) | 70.0 s | **9.8 s** |
| M3 Pro (CPU OSL) | 51.0 s | 33.8 s |

Quality went **up**: MAE 0.0219 -> 0.0210 against Unity's bake.

The Mac gains only 1.3x because CPU OSL is ray-bound, not pixel-bound. That flips the earlier
verdict: with the pixel tax gone the 3090 wins (35 s vs 47 s end to end), because what remains is
tracing. Renting a GPU is worth it again — but pick by CPU too, since the lightmap bake (19.1 s of
the 3090's 35 s) is mostly single-threaded `smart_project`/`pack_islands`.

**Warm batches are 0.9 s; batch 0 is 2.4 s of OSL warm-up.** A single-batch measurement showed only
3.4x and made me under-predict the win — never conclude from batch 0 alone.

## Which GPU: the cheapest, and cold start dominates

A **$0.055/hr RTX 3060 ties a $0.131/hr RTX 3090** — 35.2 s vs 35 s a bake, so 2.4x cheaper per
cornell. Gather 11.0 s vs 9.8 s; everything else is shared CPU work. The GPU is no longer the
bottleneck, so buy the cheapest card with a **modern CPU** attached (`vast_bake.py --min-cpu-ghz`).
12 GB VRAM is ample — at tile 16 the atlas is tiny.

**The first bake on a fresh container is 224 s against a warm 11 s** — the OptiX/OSL kernel compile
landing in `~/.cache/cycles`, i.e. 20x the steady-state gather. That earlier "no cold-start tax on
OptiX" claim was measured on a box already warmed by previous runs; it was wrong. Production needs
long-lived workers or a pre-warmed cache (per-GPU-architecture, so it can't be baked without a GPU).

## Other facts from the same session

- **Blender's bake is not bit-reproducible**: two runs of the same binary differ by up to 0.04%.
  Compare ratios and MAE, never bytes.
- `exr_codec = "NONE"` is worth setting: compressing an 800 MB atlas that is read back one second
  later costs more than the bytes save.
- **A CUDA-12.4 host cannot run a CUDA-12.8 image**: `cuInit` fails "Unknown CUDA error value" and
  Cycles reports no OptiX device. Match the vast CUDA filter to the image, not to OptiX's floor.
- **Both "hangs" I chased were self-inflicted**, not lemon hosts: one was the 224 s cold compile on
  a 2.0 GHz Xeon, the other a dead Blender that my `accept()` waited on forever. Suspect your own
  timeout handling before blaming the host — and never run a diagnostic through `grep`, which
  buffers and leaves you blind for minutes.
