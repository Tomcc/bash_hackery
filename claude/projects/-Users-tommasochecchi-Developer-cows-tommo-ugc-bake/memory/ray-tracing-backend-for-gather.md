---
name: ray-tracing-backend-for-gather
description: "Why the APV probe gather uses Embree on CPU even on an NVIDIA bake server, and the Embree/OptiX/wgpu support facts behind that"
metadata: 
  node_type: memory
  type: project
  originSessionId: 8eb14fef-01a5-45a1-aeff-51d5f466b9c5
  modified: 2026-09-03T06:08:20.693Z
---

Researched 2026-09-02 for step 4 of [[ugc-apv-bake-ladder]]. Deploy target is a Linux + NVIDIA
server (Tommo's call), which is right — but for the **bake**, not the gather.

**Embree does NOT support NVIDIA GPUs.** Its GPU backend is Intel-only (Arc, Data Center GPU
Flex/Max) via SYCL, built on Intel Xe device capabilities. Codeplay's oneAPI-for-NVIDIA plugin can
target CUDA from SYCL, but that does not make Embree's GPU path a supported NVIDIA configuration —
it would be a fork/experiment. On NVIDIA, treat Embree as a **CPU library**.

**Decision: Embree on CPU for the gather anyway.** The gather is ~73M first-hit rays (142k probes x
512 directions). Embree CPU does 20-300M rays/s on a server CPU = **0.25-3.5 s**, while the Cycles
bake takes seconds. Moving the gather to OptiX (~0.1 s) optimises the half that isn't the
bottleneck. Revisit only if the gather actually becomes one; it's a narrow interface (rays in, hits
out) so swapping is contained.

Rust integration decides it too:
- `embree4-rs` — community FFI, workable (verify ABI against the exact Embree minor release)
- **OptiX has no credible Rust wrapper** — needs a hand-written C++ shim. `cust` is CUDA driver
  interaction, NOT an OptiX binding.
- Vulkan ray query via `ash` — works but is a substantial systems project

**NVIDIA still earns its keep on the bake:** Cycles gets OptiX hardware traversal, so real bake
times should beat the Metal numbers in [[blender-headless-bake-facts]].

**wgpu still has no stable hardware ray tracing** on any backend (as of 2026). That kills the
original "WGSL path tracer in the browser" plan for step 4 and is another argument for
doing this server-side.
