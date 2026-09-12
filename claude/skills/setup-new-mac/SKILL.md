---
name: setup-new-mac
description: >
  Set up a Mac from scratch — a new machine, a loaner, or a temporary account on someone else's
  hardware. Invoke when asked to "set up this Mac", migrate settings between Macs, enable remote
  access (SSH / Screen Sharing / Tailscale), install a specific Unity or macOS version, wire up
  dotfiles from bash_hackery, or tear a borrowed machine back down. Every section below is a
  gotcha that cost real debugging time — read the relevant one before running commands.
---

# Setting up a Mac

House style: **repopulate fresh, never Time Machine.** Leaving old cruft behind is the point. The
only things that genuinely can't be regenerated are **paid licenses** (see MacWhisper below) — not
SSH keys, which are per-machine and disposable by design.

## sudo does not work from the agent's bash tool

There's no TTY, so `sudo` fails with *"a terminal is required to read the password"*. Hand the user
a one-liner to paste into a real terminal tab. Chain it so it's a single paste:

```bash
brew install mist-cli && sudo mist download installer "15.7.9" application --output-directory ~/Downloads
```

## Remote access

`systemsetup -setremotelogin on` **exits 0 while doing nothing** when the calling terminal lacks
Full Disk Access. It's silent, and `&&` chains happily continue past it. Verify, don't trust:

```bash
launchctl print system/com.openssh.sshd >/dev/null 2>&1 && echo ON || echo OFF
```

Use `launchctl` instead — it needs no TCC grant:

```bash
sudo launchctl enable system/com.openssh.sshd
sudo launchctl bootstrap system /System/Library/LaunchDaemons/ssh.plist
# Screen Sharing:
sudo launchctl enable system/com.apple.screensharing
sudo launchctl bootstrap system /System/Library/LaunchDaemons/com.apple.screensharing.plist
```

Scope to one user (matters on a borrowed machine — these toggles are machine-wide):
`sudo dseditgroup -o edit -a <user> -t user com.apple.access_ssh`

**Tailscale** removes all LAN/port-forwarding concerns — MagicDNS gives stable hostnames, so
`ssh user@chriss-mac-mini` just works from anywhere. But:

- **`pmset -a sleep 0` is mandatory.** A sleeping Mac is off the tailnet. `womp` (Wake on LAN)
  will *not* save you — that's LAN-only and Tailscale can't wake it. `displaysleep` is fine to leave.
- The Mac App Store build of Tailscale keeps its CLI inside the bundle:
  `/Applications/Tailscale.app/Contents/MacOS/Tailscale`. Symlink it to `/usr/local/bin/tailscale`.
- Delete stale duplicate device registrations (`host-1`, `host-2`) or MagicDNS may resolve the wrong one.

## SSH keys with Secretive

Secure Enclave keys are **non-exportable and machine-bound**. They can't be migrated and they die
with the hardware — that's the design, not a loss. Replacing one is a browser click. Git auth here
is deliberately **HTTPS + gh token** (scoped, revocable, 2FA-backed), so a missing SSH key breaks
almost nothing.

To authorize machine A → machine B, you need A's *public* key in B's `~/.ssh/authorized_keys`.
Fastest source, no access to A required:

```bash
curl -s https://github.com/<username>.keys
```

**Caveat:** `.keys` strips comments, so you cannot tell which machine each key belongs to. Secretive
keys are always `ecdsa-sha2-nistp256` (the enclave only does P-256). Identify by elimination —
compare against the local agent's key:

```bash
SSH_AUTH_SOCK=~/Library/Containers/com.maxgoedjen.Secretive.SecretAgent/Data/socket.ssh ssh-add -L
```

Perms are load-bearing: `700` on `~/.ssh`, `600` on `authorized_keys`, or sshd silently ignores it.

**Secretive prompts on every handshake.** On a Mac with no Touch ID that's a password dialog, which
will stall an agent firing off many `rsync` calls. Multiplex so you authenticate once:

```
Host <target>
  ControlMaster auto
  ControlPath ~/.ssh/cm-%r@%h:%p
  ControlPersist 10m
```

**TCC blocks sshd** from writing to `~/Desktop`, `~/Documents`, `~/Downloads` unless it has Full
Disk Access. Dotfiles are unaffected; expect permission errors (not hangs) for those three.

## Dotfiles from bash_hackery

`ZSH_PACKAGES` self-locates via `realpath`, so wiring up is one line in `~/.zshrc`:

```zsh
source ~/Developer/bash_hackery/shared.zshrc
```

**Username portability.** `shared.zshrc` has historically hardcoded `/Users/<name>/…` for
`SSH_AUTH_SOCK`. On a machine with a different short username that points at a nonexistent socket
and **silently breaks all SSH auth**. Fix upstream as `$HOME/…`; locally, re-export *after* the
source rather than patching the sourced file:

```zsh
source ~/Developer/bash_hackery/shared.zshrc
export SSH_AUTH_SOCK="$HOME/Library/Containers/com.maxgoedjen.Secretive.SecretAgent/Data/socket.ssh"
```

Same class of bug: `.gitignore` entries like `claude/projects/-Users-<name>` won't match elsewhere.

**Orphaned gitlinks.** `zsh-histdb` and `zsh-z` exist as tree entries with no `.gitmodules` mapping
(their entries were removed when atuin replaced histdb, but the gitlinks were left behind). Git
iterates gitlinks **alphabetically and aborts on the first unmapped one**, so
`git submodule update --init` clones *nothing at all*. Init the valid ones explicitly:

```bash
git -c url."https://github.com/".insteadOf="git@github.com:" \
  submodule update --init pexp zsh-autosuggestions zsh-syntax-highlighting
```

The `insteadOf` is needed because submodule URLs are `git@github.com:` SSH and a fresh Mac has no
GitHub-registered key. `git -c` propagates to submodule clones via `GIT_CONFIG_PARAMETERS`, so it
leaves no on-disk diff — better than `git submodule set-url`, which dirties `.gitmodules`.

On macOS `shared.zshrc` sets `USE_ANTIGEN=1`, so plugins come from antigen bundles and those
submodule dirs are never read anyway.

Expect these startup errors until the tools exist — none are fatal:

```bash
rustup default stable                                  # rustup ships with NO toolchain
cargo install --path ~/Developer/bash_hackery/pexp     # provides pexp_bin
brew install direnv thefuck
```

**`setup_mac.sh` is long broken** — its brew line reads `brew install git install zsh …`, so it tries
to install a package literally named `install`. Install by hand.

## Karabiner: mouse buttons

Works via `pointing_button` in the device's `simple_modifications`, but the device entry needs
`"ignore": false` or Karabiner won't grab it. Mission Control should be the real HID event, not a
faked Ctrl+↑ (which breaks if the shortcut is rebound):

```json
{
  "from": { "pointing_button": "button5" },
  "to": [{ "apple_vendor_keyboard_key_code": "mission_control" }]
}
```

Button numbering differs between tools — **use `Karabiner-EventViewer.app`** to see what the mouse
actually emits rather than guessing from MacMouseFix's numbering.

Karabiner replaces MacMouseFix's button remaps and `mouse_flip_vertical_wheel`, but **not** its
smooth scrolling. That capability is simply lost.

Karabiner reloads `~/.config/karabiner/karabiner.json` on external change, so edits apply live.
Validate after editing (`python3 -m json.tool`) and keep a backup.

## Unity Hub headless install

Two traps, both of which look like a silent hang:

1. **It prompts interactively for architecture** and waits forever. Always pass `--architecture`.
2. **Piping its stdout through `tail` causes `write EPIPE`.** Redirect to a file instead.

```bash
nohup "/Applications/Unity Hub.app/Contents/MacOS/Unity Hub" -- --headless install \
  --version 6000.0.31f1 --changeset a206c360e2a8 --architecture arm64 > /tmp/unity.log 2>&1 &
```

Get the changeset for a version Hub no longer lists from Unity's release API:

```bash
curl -s "https://services.api.unity.com/unity/editor/release/v1/releases?version=6000.0.31"
```

Or read it straight out of the project: `ProjectSettings/ProjectVersion.txt` →
`m_EditorVersionWithRevision: 6000.0.31f1 (a206c360e2a8)`.

Hub may install to **`~/Applications/Unity/Hub/Editor/`**, not `/Applications/...`, regardless of
what `install-path --get` reports. Confirm with `-- --headless editors -i` instead of globbing a
directory. (Corollary: a permissions failure on `/Applications/Unity/Hub/Editor` is usually a red
herring — check for the arch prompt first.)

## Installing a specific macOS version

Software Update only knows the **current major**. Clicking GET on an older macOS App Store page
delegates to Software Update, which then offers the newest release instead — this looks like the
page "switching back" on its own. Not user error.

`softwareupdate --list-full-installers` **returns an empty list** on older macOS (verified on
14.1.2, with no CatalogURL override and no MDM restriction). That escape hatch is closed.

What Apple actually still serves:

```bash
curl -s https://gdmf.apple.com/v2/pmv | python3 -c 'import json,sys; d=json.load(sys.stdin); print(sorted({a["ProductVersion"] for a in d["AssetSets"]["macOS"]}, reverse=True))'
```

Then use `mist-cli`, which pulls from Apple's CDN directly:

```bash
brew install mist-cli && sudo mist download installer "15.7.9" application --output-directory ~/Downloads
```

Version landmarks: **Liquid Glass = macOS 26 Tahoe**; the last version before it is **15 Sequoia**.
iPhone Mirroring needs 15+. Finder device sync has worked since 10.15 and is not a reason to upgrade.

**Xcode/Swift coupling:** Swift 6.0 requires Xcode 16 / CLT 16, which requires **macOS 14.5+**. A
Mac on 14.1.2 has Swift 5.10 and cannot build any package declaring
`swift-tools-version: 6.0` — including `padded-parakeet`. Upgrade macOS first.

## Big clones and LFS

**Do not diagnose an in-progress clone as corrupt.** Mid-checkout you will see thousands of `D`
(deleted) entries and `git lfs fsck` reporting missing objects. That is LFS smudging files one at a
time, not damage. Removing `.git/index.lock` or running `git reset --hard` against a live clone is
how you actually break it.

Verify a clone is finished by checking the *process*, and get the pattern right:

```bash
pgrep -fl 'git clone'          # NOT "git clone\|git-lfs" — \| is a literal pipe in pgrep's ERE
pgrep -fil karabiner           # pgrep is case-sensitive; the app is "Karabiner-Elements"
```

Both of those cost a wrong conclusion in practice. When in doubt, one pattern per `pgrep` call.

**Backgrounded work dies when a turn is interrupted.** A long clone launched via the tool's
background mode was killed (exit 144 = SIGTERM) by an unrelated interrupt. Detach it properly:

```bash
nohup git clone <url> > /tmp/clone.log 2>&1 & disown
```

Confirm success with `git status --porcelain | wc -l` reaching 0, not by directory size.

## Borrowed machine: hygiene and teardown

Check the real state before worrying:

```bash
diskutil apfs list | grep -i FileVault     # "No (Encrypted at rest)" on Apple Silicon
system_profiler SPNVMeDataType | grep TRIM
```

Apple Silicon hardware-encrypts the internal SSD **regardless of FileVault**, and with TRIM on,
deleted blocks aren't practically recoverable. So deleting the account *is* sufficient — skip
secure-erase tools (macOS removed them for SSDs; wear levelling defeats them). Enabling FileVault
is not worth it: it wouldn't stop the machine's owner, who has admin anyway.

The real risks are **live**, not forensic:

- The owner's admin account can `sudo` into your home dir while it exists.
- Signing in your Apple ID pulls iCloud Keychain, Photos, Mail, Notes, Contacts and Desktop sync
  onto hardware you don't control. **Turn off the dataclasses you don't need immediately**, not at
  the end — Photos and Mail backfill quietly.

Teardown:

```bash
rm ~/.pexprc                                        # plaintext keys
gh auth logout
rm -rf ~/.aws ~/.ssh ~/.claude ~/.claude.json ~/.config
```

Then sign out of Apple ID (removing local copies), sign out of Slack/Discord/Signal/Chrome, delete
the account choosing **Delete the home folder**, revert any `chown` you did under `/Applications`,
turn off Remote Login + Screen Sharing, and restore `pmset` (default was `sleep 60 displaysleep 60`).

## Secrets

`pexp` (`~/.pexprc`) persists global exports and live-refreshes open sessions — a capability nothing
else replicates. The tradeoff is plaintext on disk and *global* scope, which leaks into every
subprocess including every agent.

Preferred replacement, no new dependencies:

```zsh
security add-generic-password -a "$USER" -s <name> -w      # store (prompts, stays out of history)
keyfrom() { security find-generic-password -s "$1" -w 2>/dev/null }
```

`security add-generic-password` creates a **non-synchronizable** item, so it stays local and won't
ride iCloud Keychain to other devices. Scope per project with `direnv` (`.envrc` is already
gitignored) rather than exporting globally. Costs ~10–30ms per lookup, so fetch lazily in `.envrc`,
never at shell startup. You lose pexp's cross-session refresh — `direnv reload` instead.

## App-specific notes

**MacWhisper** — license `524A16AB-1FC2446E-994D2247-E2CD340B` (also in Notes).
Prefs at `~/Library/Preferences/com.goodsnooze.MacWhisper.plist` carry `isPro` and settings, but
**license and provider API keys live in the Keychain**, so copying the plist does not carry the
license (`HasMigratedFromOldKeychainWrapper` is the tell). Enter it in the UI.

The brew cask is the direct/Gumroad build, not the App Store one — check
`/Applications/MacWhisper.app/Contents/_MASReceipt` to tell which a machine has, since MAS purchases
have no key at all. Purchase receipts come from **Gumroad**, not "MacWhisper" — search email
accordingly.

Custom server (padded-parakeet) settings that live in prefs:

```
customOpenAIWhisperProviderBaseURL = http://127.0.0.1:8737
customOpenAIWhisperProviderModel   = aaaaaaa
selectedRunnerConfig               = {"engine":{"customOpenaiCloud":{}}}
dictationRunnerConfig              = {"engine":{"customOpenaiCloud":{}}}
```

The **API Key field must be set to `none`** in the UI for the local server. It's Keychain-backed, so
it can't be set with `defaults write` — and it's easy to forget when migrating, producing a silent
auth failure.

**padded-parakeet** — `main` is Swift-only; the Rust server was removed. The Apple SpeechTranscriber
engine needs the macOS 26 SDK and lives on the `speech-transcriber` branch. Build and register the
launchd agent with `swift/install.sh`, which requires `OPENROUTER_API_KEY` in the environment
(launchd can't source shell files, so the script bakes it into the plist) and installs to `~/bin`.
Needs Swift 6.0 → macOS 14.5+.

**Rectangle** is the window manager (drag-to-top vertical extend). **MacMouseFix is deliberately
retired** in favour of Karabiner.
