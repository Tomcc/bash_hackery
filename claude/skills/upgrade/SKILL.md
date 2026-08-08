---
name: system-upgrade
description: Monthly system upgrade process. Auto-invoke when the user asks to upgrade, update, or maintain their system, brew packages, cargo packages, or do general system maintenance.
---

## Pre-flight check

Check which terminal we're running in:
!`printf '%s\n' "$TERM_PROGRAM"`

If the terminal is `ghostty`, STOP and tell the user to switch to Terminal.app first, since brew may upgrade Ghostty itself.

Check free disk space with `df -h /System/Volumes/Data`. Under ~40GB free, run `brew cleanup`
BEFORE upgrading: big casks unpack into /private/tmp and hit "No space left on device".

Those `✘ Cask <name>` lines are the parallel download/unpack stage, NOT the install. Brew retries
serially and usually succeeds. Grep the log for `successfully upgraded` per cask before reporting
anything as failed — comparing version numbers proves nothing, since a half-copied bundle carries
the new version too. `codesign --verify --deep <app>` is the real integrity check (no `--quiet`
flag exists; it is slow on big bundles).

Never install or reinstall the `claude` cask (Claude desktop). It ships a ~12GB VM and the user
removed it deliberately. If `/Applications/Claude.app` is missing, that is intended — leave it.
Note it uses `unzip`, which reports success on a truncated write, so a disk-full upgrade really can
delete the old app with nothing to replace it. Still do not reinstall.

## Step 1: Brew upgrade

Run `brew update && brew upgrade --greedy`. The `--greedy` flag ensures casks marked as "auto-updating" also get upgraded, since many don't actually auto-update. This can take a long time (LLVM, Blender, Krita, etc). Run it in the background and monitor progress.

If any casks fail due to sudo prompts, collect them and tell the user to run them manually in an interactive terminal.

After the upgrade completes, ask the user how to handle any deprecation warnings that appeared (eg. deprecated casks — offer to uninstall).

## Step 2: Restart apps

After brew finishes, check if the following apps are still running and restart any that aren't:
- MacWhisper
- Alfred
- AltTab
- ghostty — check with `pgrep -x ghostty`; the process name is lowercase, so `pgrep -x Ghostty`
  reports stopped even while it runs. Expect it down anyway: pre-flight told the user to quit it.

Use `pgrep -x "<name>"` to check and `open -a "<name>"` to restart.

## Step 3: Cargo global upgrades

List installed cargo packages with `cargo install --list`.

Skip any packages that are the user's own projects (installed from local paths or personal GitHub repos).

Check which are actually behind first — hit `https://crates.io/api/v1/crates/<name>` and read
`crate.max_stable_version`. Usually only one or two need anything.

Upgrade the remaining packages using `cargo binstall -y` (always prefer binstall over cargo install).

If binstall dies with `DNS error: no records found for ...tail<digits>.ts.net`, Tailscale's
resolver is appending its search domain — binstall's bundled resolver trips on this even though
curl and `dscacheutil` resolve fine. Ask the user to turn Tailscale off, then retry.

After upgrading, clean up the cargo registry cache:
```
rm -rf ~/.cargo/registry
```

## Step 4: Brew cleanup

Run `brew cleanup` to remove old cached downloads and versions.

## Step 5: Summary

Report what was upgraded, what failed, and any manual steps the user still needs to do.
