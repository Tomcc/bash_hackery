---
name: system-upgrade
description: Monthly system upgrade process. Auto-invoke when the user asks to upgrade, update, or maintain their system, brew packages, cargo packages, or do general system maintenance.
---

## Pre-flight check

Check which terminal we're running in:
!`echo $TERM_PROGRAM`

If the terminal is `ghostty`, STOP and tell the user to switch to Terminal.app first, since brew may upgrade Ghostty itself.

## Step 1: Brew upgrade

Run `brew update && brew upgrade --greedy`. The `--greedy` flag ensures casks marked as "auto-updating" also get upgraded, since many don't actually auto-update. This can take a long time (LLVM, Blender, Krita, etc). Run it in the background and monitor progress.

If any casks fail due to sudo prompts, collect them and tell the user to run them manually in an interactive terminal.

After the upgrade completes, ask the user how to handle any deprecation warnings that appeared (eg. deprecated casks — offer to uninstall).

## Step 2: Restart apps

After brew finishes, check if the following apps are still running and restart any that aren't:
- MacWhisper
- Alfred
- AltTab
- Ghostty

Use `pgrep -x "<name>"` to check and `open -a "<name>"` to restart.

## Step 3: Cargo global upgrades

List installed cargo packages with `cargo install --list`.

Skip any packages that are the user's own projects (installed from local paths or personal GitHub repos).

Upgrade the remaining packages using `cargo binstall -y` (always prefer binstall over cargo install).

After upgrading, clean up the cargo registry cache:
```
rm -rf ~/.cargo/registry
```

## Step 4: Brew cleanup

Run `brew cleanup` to remove old cached downloads and versions.

## Step 5: Summary

Report what was upgraded, what failed, and any manual steps the user still needs to do.
