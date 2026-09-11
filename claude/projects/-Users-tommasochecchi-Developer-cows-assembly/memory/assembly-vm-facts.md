---
name: assembly-vm-facts
description: "Key facts about the Assembly farm VM — where it lives, how to reach it, what's installed."
metadata: 
  node_type: memory
  type: project
  originSessionId: a2b01b5f-0a04-4671-9df2-c0913e149626
---

The Assembly farm VM (`assembly`) was stood up 2026-07-12/13 on the hammerbot
Windows PC as a Hyper-V Gen2 Ubuntu 24.04 guest.

- **Storage:** 2TB NVMe formatted NTFS (drive E:), two fixed VHDXs — 128G OS +
  400G data. ZFS pool `tank` on the data disk, mounted `/tank`. 64G swap.
- **Access:** on the tailnet as `assembly` at `100.126.240.97`; `ssh agents@100.126.240.97`
  from the Mac, key-only. The Mac→host→VM ProxyJump double-hop is unreliable — Tailscale
  direct is the path.
- **Installed:** Docker, ZFS, Rust 1.91.0, Claude Code (Bedrock via `AWS_BEARER_TOKEN_BEDROCK`
  in gitignored `/tank/main-repo/.envrc.local`, loaded by direnv), AWS CLI (identity
  `user/assembly-pod`).
- **Repo:** `/tank/main-repo`, full LFS. Durable git auth via
  `tools/assembly/git-credential-assembly.sh` (mints GitHub App tokens on demand from
  `assembly/shared`); remote URL carries no token.
- **Proven:** hammerbot builds clean (`cargo build --release -p hammerbot --features aws`,
  ~8min) and runs.
- **Blocked:** Unity (license seat) — gates the full `hammerbot ci --dry-run` warmup only.
- **Next:** `tools/assembly/warmup.sh` for non-Unity cache warming (Rust release done;
  add debug + npm/vite + launcher). Full bring-up documented in the `setup-assembly-vm`
  skill. See also [[reboot-wedged-vm-early]], [[narrow-to-wide-credentials]].
