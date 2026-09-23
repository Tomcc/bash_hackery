---
name: system-upgrade
description: Monthly system upgrade process. Auto-invoke when the user asks to upgrade, update, or maintain their system, brew packages, cargo packages, or do general system maintenance.
---

## Pre-flight check

Check which terminal we're running in:
!`printf '%s\n' "$TERM_PROGRAM"`

- If it is `ghostty`, STOP and ask the user to switch to Terminal.app — brew may upgrade Ghostty.
- Check free space with `df -h /System/Volumes/Data`. Under ~40GB, run `brew cleanup` first: big
  casks unpack into /private/tmp and hit "No space left on device".
- Never install or reinstall the `claude` cask (Claude desktop, ~12GB VM). A missing
  `/Applications/Claude.app` is intended — leave it, even if a disk-full upgrade deleted it (its
  `unzip` reports success on a truncated write).

## Step 1: Brew upgrade

Run `brew update && brew upgrade --greedy` in the background and monitor it. `--greedy` also
upgrades "auto-updating" casks, many of which don't. Expect it to be slow (LLVM, Blender, Krita).

- Grep the log for `successfully upgraded` per cask before reporting a failure. `✘ Cask <name>`
  lines come from the parallel download/unpack stage; brew retries serially and usually succeeds.
- Verify integrity with `codesign --verify --deep <app>` (no `--quiet` flag; slow on big bundles),
  never by version number — a half-copied bundle carries the new version too.
- Collect casks that fail on sudo prompts and hand them to the user for an interactive terminal.
- Ask the user how to handle deprecation warnings (e.g. offer to uninstall deprecated casks).

## Step 2: Restart apps

Check with `pgrep -x "<name>"` and restart with `open -a "<name>"`:
- MacWhisper
- Alfred
- AltTab
- ghostty — the process name is lowercase (`pgrep -x Ghostty` misses it). Expect it down: the
  user quit it in pre-flight.

## Step 3: Cargo global upgrades

1. List packages with `cargo install --list`. Skip the user's own projects (local paths or
   personal GitHub repos).
2. Find which are behind via `https://crates.io/api/v1/crates/<name>` →
   `crate.max_stable_version`. Usually only one or two.
3. Upgrade those with `cargo binstall -y`, never `cargo install`.
4. Clean the registry cache: `rm -rf ~/.cargo/registry`.

If binstall fails with `DNS error: no records found for ...tail<digits>.ts.net`, ask the user to
turn Tailscale off and retry — its search domain trips binstall's bundled resolver.

## Step 4: Brew cleanup

Run `brew cleanup`.

## Step 5: Summary

Report what was upgraded, what failed, and any manual steps left for the user.
