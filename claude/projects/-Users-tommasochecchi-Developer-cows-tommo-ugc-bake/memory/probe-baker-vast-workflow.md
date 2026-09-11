---
name: probe-baker-vast-workflow
description: "How to run the probe baker on a rented GPU: the Docker image, vast_bake.py, the dedicated SSH key, and stop-not-destroy"
metadata: 
  node_type: memory
  type: project
  originSessionId: 5b392b67-54a1-44e6-b018-e7af5220287e
  modified: 2026-09-03T18:59:22.868Z
---

Built 2026-09-03 for [[ugc-apv-bake-ladder]]. Lives in `tools/probe_baker/`, documented in its
README; this covers the operational gotchas that bit me.

- **Image:** `tomatocakeinc/probe-baker:latest` (public Docker Hub, Tommo approved; deletable later).
  `build_docker.sh` stages a temp build context because the 10 MB Unity probe reference lives in
  `$TMPDIR`, outside the repo. Base is `nvidia/cuda:12.8.1-base-ubuntu24.04`, **not `runtime`** — the
  2 GB of CUDA math libraries buy nothing and a slow pull is how vast hosts waste money.
- **No Blender at image build time.** The image is amd64 built from an arm64 Mac, so every build-time
  `RUN` goes through qemu. Blender *does* run under qemu, but the fixture is rebuilt at container
  start instead (seconds of CPU) rather than risking it.
- **`download.blender.org` serves 403 to non-browser clients** and
  `www.blender.org/download/release/...` returns an HTML landing page that `tar` then rejects. Use
  the nluug mirror (`ftp.nluug.nl/pub/graphics/blender/release/...`) and pin the hash from Blender's
  own `blender-<version>.sha256`.
- **A Secretive/Touch-ID SSH key cannot drive an unattended run** — every connection needs a touch,
  and the agent just answers "agent refused operation". Generated `~/.ssh/vast_probe_baker` and
  registered it with `create_ssh_key`; `attach_ssh` propagates to a *running* instance in ~45 s.
- **`direct_port_start` stays `-1` on perfectly reachable instances.** Read the endpoint from
  `ports["22/tcp"][0]["HostPort"]` + `public_ipaddr` instead. It being truthy at `-1` is what made
  `vast_bake.py` first print `ssh -p -1`.
- **Prefer `stop` over `destroy`.** A stopped instance keeps its disk and pulled image, which is the
  part lemon hosts fail at. I left one running through a pause and it cost ~$4.50 over 34 h at
  $0.131/hr — cheap, but the fan-out script should stop instances itself rather than rely on anyone
  remembering.
- Long remote runs: `setsid nohup ... > /work/bench.log` and poll the log over a *separate* ssh. A
  piped foreground `ssh ... | tail` loses everything if the session drops, and buffering means you
  see nothing until it finishes anyway.
