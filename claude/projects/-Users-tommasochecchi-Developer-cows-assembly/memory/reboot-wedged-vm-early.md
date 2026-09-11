---
name: reboot-wedged-vm-early
description: "When a freshly-installed VM behaves systemically weird, power-cycle it before theorizing."
metadata: 
  node_type: memory
  type: feedback
  originSessionId: a2b01b5f-0a04-4671-9df2-c0913e149626
---

A fresh Hyper-V Ubuntu VM went systemically slow — console wouldn't accept typed
input, SSH hung for minutes, `systemctl` reported "Transport endpoint is not
connected", all at 0% CPU and 0 disk queue. I chased Defender/memory/DNS theories
for a while. Root cause: a non-TTY `systemctl` call during setup wedged systemd
into "preparing for shutdown". A hard power-cycle (`Stop-VM -TurnOff -Force;
Start-VM`) fixed everything in <1s.

**Why:** "Can't even type into it" was the early smell of a whole-VM stall, not a
Hyper-V input quirk — I mis-scoped it as many separate problems.

**How to apply:** For a fresh/disposable VM showing broad unresponsiveness, reboot
first, diagnose only if the reboot doesn't fix it. Reserve deep diagnosis for
machines with state worth preserving. Related: [[assembly-vm-facts]].
