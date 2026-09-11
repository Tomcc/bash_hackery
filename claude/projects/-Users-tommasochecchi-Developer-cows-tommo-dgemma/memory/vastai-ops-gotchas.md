---
name: vastai-ops-gotchas
description: Hard-won vast.ai + vLLM operational gotchas from the dgemma bench sessions
metadata: 
  node_type: memory
  type: reference
  originSessionId: 592dca23-2bab-4211-82d4-af0ffc2b9b09
  modified: 2026-08-22T07:37:04.752Z
---

vast.ai/vLLM ops lessons (dgemma bench, Aug 2026):
- **Stop, don't destroy** boxes mid-project (user rule; weights/caches survive, billing drops
  to storage). Stopped boxes can lose their GPU to other renters — restart retries with
  `resources_unavailable` until the GPU frees; ~17min in one case. ssh host/port CAN change.
- **VRAM zombies**: vLLM EngineCore renames itself `VLLM::EngineCor`, dodging pkill by name;
  inside vast containers nvidia-smi shows HOST pids (unkillable). Only reliable kill: scan
  /proc/*/fd for open nvidia devices (see tools/dgemma_bench/gpu_kill.sh). Verify by
  memory.used==0, not by pid.
- **scp to multiple boxes**: verify with md5sum on both ends — a silent scp failure cost a
  full 9-cell matrix rerun.
- **matrix.py talks to a local tunnel** (`--url localhost:8100`), not the box; forgetting to
  retunnel after box restart = every cell "ALL REQUESTS FAILED ConnectError".
- vLLM `gpu_memory_utilization` does NOT include the diffusion sampler buffers (~268MB/slot
  float32) or CUDA graphs; 32 slots on 80GB needs util<=0.68. OOM appears only after graph
  capture.
- vast "from $X/h" tile prices are floors across all configs; real qualifying single-GPU
  offers run 2-3x that. Search with vastai_sdk: `gpu_ram>90` is in GB here, not MB.
- Prefixed AWS Mantle model names (`google.gemma-*`) only exist on the `/openai/v1` route;
  tier is the `service_tier` field, NOT a different URL path.
