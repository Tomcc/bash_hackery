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

## Driving the machine over SSH as an agent

**A login shell over SSH never returns** once `shared.zshrc` is wired up. `pexp_setup.sh` spawns
`pexp_bin watch $$ &`, which inherits the SSH session's stdout and holds it open forever. That looks
like a hung command, not an error. Redirect inside the remote command:

```bash
ssh host 'zsh -ilc "…" > /tmp/out 2>/dev/null </dev/null; cat /tmp/out'
```

Non-login shells (`ssh host 'cmd'`) skip `.zshrc` and are unaffected — but then `PATH` has no
`/opt/homebrew/bin`, so call `brew` by absolute path or export it first.

**That watcher can abort and take your session with it.** `kill(pid, SIGUSR2).expect(…)` at
`pexp/src/main.rs:140` panics with `ESRCH` once the parent shell is gone — and it panics inside
notify's fsevents callback, which is called from C, so since Rust 1.81 that's an immediate `abort()`
that kills the process group. Every closed terminal leaves an orphan watcher armed to do this on the
next `.pexprc` write. Older binaries predate the change and unwind harmlessly, so this only shows up
on a freshly built `pexp_bin`.

**TCC-blocked directories are still discoverable via Spotlight.** sshd has no Full Disk Access, so
`ls ~/Downloads` returns *Operation not permitted*. `mdfind` reads the index rather than the files:

```bash
mdfind -name "Install macOS"          # finds it
mdls -name kMDItemVersion "…app"      # metadata works; kMDItemFSSize is null for bundles
```

**Casks whose artifact is a `.pkg` need `sudo`**, so an agent cannot install them at all. Do the slow
half and hand over a paste that finishes instantly:

```bash
brew fetch --cask zoom onedrive       # no sudo, lands in brew's cache
# user then pastes: brew install --cask zoom onedrive
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

## API keys live in the Keychain, not in a file

`keychain_env.zsh` (sourced on macOS via `USE_KEYCHAIN_ENV`) exports every key at shell start from
Keychain items named `shell_env.<VARNAME>`. `save_key NAME value` adds one, `list_keys` enumerates,
`delete_key NAME` removes — so adding a key never edits a dotfile. A fresh Mac starts with **no keys**;
they are not in the repo. Copy them from another machine's Keychain, or re-issue them.

macOS is the only platform with this. Linux still uses pexp (`USE_PEXP`), which keeps them in
plaintext `~/.pexprc` and spawns the stdout-inheriting watcher that hangs `ssh host 'zsh -ilc ...'`.

Four `security` behaviours this works around, all found the hard way:

- **`-w` reading from stdin truncates at 128 characters, silently.** Long tokens come back cut with no
  error at all. The value has to go through argv, brief `ps` exposure and all.
- **`-U -A` on an *existing* item prompts for your login password** ("wants to change access
  permissions"), once per item. Delete-then-add instead; `-A` on a *new* item is silent.
- **`-w` hex-encodes any value containing a newline**, with no reliable way to tell that apart from a
  value that merely looks like hex. `save_key` rejects newlines rather than guess.
- **`dump-keychain` prints the service name twice per item** — once as `svce`, once as the default
  label `0x00000007`. Count only `svce` lines or every item looks duplicated.

Reads are batched into a single `security -i` process: one spawn per key costs ~900ms of shell
startup, batched it is ~75ms.

## Baseline packages

Homebrew first (it is not preinstalled); on Apple Silicon it lands in `/opt/homebrew`, which is not on
`PATH` until you run its `shellenv` line:

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

```bash
brew install git zsh atuin direnv fzf zoxide diff-so-fancy thefuck rustup nvm
brew install --cask alfred alt-tab iterm2 ghostty karabiner-elements secretive stats vlc
```

`nvm` is the brew build on purpose: `nvm_hook.zsh` sources `$(brew --prefix nvm)/nvm.sh`, not the
install-script location. It also needs `mkdir -p ~/.nvm`, or every shell start errors on `$NVM_DIR`.

`rustup` needs `rustup default stable` (it ships with no toolchain) plus the `PATH` fix below.

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

**`~/.claude` is a symlink into the repo** (`ln -s ~/Developer/bash_hackery/claude ~/.claude`), so
Claude's own memory writes are repo changes. If only `~/.claude/skills` is symlinked instead, anything
`settings.json` points at by absolute path — e.g. `statusline-command.sh` — has to be linked
separately or it silently won't exist on that machine.

The ignore rules under `claude/` are a **whitelist, and it has to stay inverted**. Naming artifacts to
exclude leaks every new type Claude Code invents (this already happened with `workflows/` and
`auto-mode-classifier-error.txt`), and it's also why a new file like `statusline-command.sh` needs an
explicit `!` line or it never gets committed:

```
claude/projects/*/*
!claude/projects/*/memory/
```

**Orphaned gitlinks.** `zsh-histdb` and `zsh-z` exist as tree entries with no `.gitmodules` mapping
(their entries were removed when atuin replaced histdb, but the gitlinks were left behind). Git
iterates gitlinks **alphabetically and aborts on the first unmapped one**, so
`git submodule update --init` clones *nothing at all*. Init the valid ones explicitly:

```bash
git -c url."https://github.com/".insteadOf="git@github.com:" \
  submodule update --init pexp zsh-autosuggestions zsh-syntax-highlighting
```

The `-c url…insteadOf` is needed because submodule URLs are `git@github.com:` SSH and a fresh Mac has
no GitHub-registered key; `git -c` propagates to submodule clones via `GIT_CONFIG_PARAMETERS`, so it
leaves no on-disk diff — better than `git submodule set-url`, which dirties `.gitmodules`. Better
still, set the rewrite **globally once** (see the git config section) and drop the `-c` entirely.

On macOS `shared.zshrc` sets `USE_ANTIGEN=1`, so plugins come from antigen bundles and those
submodule dirs are never read anyway.

Expect these startup errors until the tools exist — none are fatal:

```bash
rustup default stable                                  # rustup ships with NO toolchain
cargo install --path ~/Developer/bash_hackery/pexp     # provides pexp_bin
brew install direnv thefuck
```

### `cargo: command not found` even though rustup works

Homebrew's `rustup` is **keg-only** — it conflicts with the `rust` formula, so brew refuses to
symlink its binaries. Only `rustup` itself lands in `/opt/homebrew/bin`; `cargo`, `rustc`,
`clippy-driver`, `rustfmt` and `rust-analyzer` all sit unlinked in the keg. The formula also
**no longer provides `rustup-init`**, which is what used to create the `~/.cargo/bin` shims.

So `rustup show` reports a healthy active toolchain while `which cargo` finds nothing. Nothing is
broken — there's just no path to it. Add the keg's bin to `~/.zshenv`:

```zsh
# use opt/ not Cellar/ so it survives version bumps
export PATH="/opt/homebrew/opt/rustup/bin:$PATH"
```

Keep the separate `$HOME/.cargo/bin` entry too — that one is for binaries produced by
`cargo install` (e.g. `pexp_bin`), which is a different directory from the toolchain shims.
Verify with `rustup which cargo`, which should resolve into `~/.rustup/toolchains/...`.

**Do NOT "fix" this by running `brew install rust`.** It's the tempting move when `cargo` isn't
found, and it silently breaks two things:

- `main-repo/rust-toolchain.toml` pins `channel = "1.97.1"`. The `rust` formula ships one fixed
  version (1.98.1 at time of writing) and has no concept of that file, so it would build the game
  with the wrong compiler and never say so. rustup switches per-directory — verify with
  `rustup show active-toolchain`, which reports `overridden by '…/rust-toolchain.toml'` inside the
  repo and `default` outside it.
- `main-repo` uses **cargo-lambda** (`.cargolambdaignore`, plus the `cloud_api/*` workspace
  members), which cross-compiles to Linux. That needs `rustup target add`; the `rust` formula
  can't add targets at all.

The two formulae conflict, which is *why* rustup is keg-only. The `rust` formula is not new —
the packaging change was on the rustup side.

Toolchains cost ~1.3–1.4 GB each. If disk gets tight, `rustup toolchain uninstall stable` is safe
when every repo you touch pins its own channel.

**There is no `setup_mac.sh`** — it was deleted. It had rotted unnoticed (its brew line read
`brew install git install zsh …`, installing a package literally named `install`) precisely because a
straight script can't check its own work. Install by hand, following this skill.

### git config: base.gitconfig is not wired up by anything on macOS

`setup_linux.sh:33` does `git config --global include.path "$(pwd)/base.gitconfig"`. Nothing does this
on a Mac, so on a fresh one none of it is active — no `pull.rebase`, no `push.autoSetupRemote`,
no `rebase.autostash`, no vscode mergetool, and no `[user] name`.

`base.gitconfig` deliberately sets **name but not email**, so both the include and the email are
needed:

```bash
git config --global include.path ~/Developer/bash_hackery/base.gitconfig
git config --global user.name "Tommaso Checchi"          # explicit: survives ~/Developer being wiped
git config --global user.email "tommaso.checchi1@gmail.com"
git config --global url."https://github.com/".insteadOf "git@github.com:"
brew install diff-so-fancy                               # base.gitconfig sets it as core.pager

# absolute path, NOT the short name "osxkeychain" — see below
git config --global credential.helper \
  /Library/Developer/CommandLineTools/usr/libexec/git-core/git-credential-osxkeychain
```

**Why the absolute path.** Apple's git sets `credential.helper = osxkeychain` in its own *system*
gitconfig (`/Library/Developer/CommandLineTools/usr/share/git-core/gitconfig`), so the CLI works with
nothing in `~/.gitconfig` at all — and that hides the problem. GUI clients ship their own git: Fork's
is 2.50.1, and its system config path is `/usr/local/git/etc/gitconfig`, which doesn't exist. It
therefore sees **no helper**, falls through to its `GIT_ASKPASS` dialog, and reuses whatever stale
password it once stored — GitHub answers `Password authentication is not supported`.

Setting the plain name `osxkeychain` globally is **not enough**. Git resolves it to
`git-credential-osxkeychain` via its exec-path and `PATH`; Fork keeps that binary in `bin/` rather than
`libexec/git-core/`, and a GUI app inherits a minimal `PATH`, so you get
`git: 'credential-osxkeychain' is not a git command` on every push. The absolute path can't miss.

The path belongs to Xcode Command Line Tools — going full-Homebrew-git and removing CLT brings the
error back.

Verify the way that actually proves it, with askpass disabled so only the helper can answer:

```bash
GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/usr/bin/false git ls-remote origin HEAD
```

That `insteadOf` line is not optional once the include is active. `base.gitconfig` sets
`submodule.recurse = true`, so **every `git fetch` recurses into submodules** — and those are
`git@github.com:` URLs. On a machine with no GitHub-registered SSH key (the norm here, since git auth
is HTTPS + gh token) each fetch spews `Host key verification failed` three times. The rewrite sends
them over HTTPS instead, needs no key, and no host key in `known_hosts`.

Three traps here:

- **Without an identity, git does not error — it invents one** from the hostname, e.g.
  `Tommaso <tommaso@Chriss-Mac-mini.local>`. Commits succeed and look fine locally but never
  attribute to your GitHub account, and you can't fix it after the fact without rewriting history.
  Set identity *before* the first commit on a new machine.
- **`git config --global --list` does not expand includes**, so the settings look absent even when
  they're working. Verify with `git config --get pull.rebase` instead.
- **`core.pager = diff-so-fancy | less …` breaks silently if diff-so-fancy is missing.** Scripted git
  calls piped into `head` skip the pager entirely, so it only fails once you use git interactively.

## Karabiner: mouse buttons

Works via `pointing_button` in the device's `simple_modifications`, but the device entry needs
`"ignore": false` or Karabiner won't grab it. Prefer the real HID event over a faked keystroke — e.g.
`apple_vendor_keyboard_key_code: mission_control` rather than Ctrl+↑, which breaks if that shortcut
gets rebound:

```json
{
  "from": { "pointing_button": "button4" },
  "to": [{ "apple_vendor_top_case_key_code": "keyboard_fn" }]
}
```

Button numbering differs between tools — **use `Karabiner-EventViewer.app`** to see what the mouse
actually emits rather than guessing from Mac Mouse Fix's numbering.

**Karabiner and Mac Mouse Fix split the mouse — don't let them overlap.** Karabiner grabs the
device (`"ignore": false`) and forwards anything it doesn't map, so any button MMF needs must have
**no** Karabiner binding at all, or Karabiner intercepts it first and MMF never sees the event.

Current division of labour on the Logitech (`vendor_id 1133`):

| Button | Owner | Action |
|---|---|---|
| `button4` | Karabiner | → `keyboard_fn` |
| `button5` | **Mac Mouse Fix** | Click & Drag to switch between screens/spaces — leave unbound in Karabiner |
| `button6` | Karabiner | → `return_or_enter` |

Karabiner cannot do Click & Drag gestures (it maps discrete events, not drags), and it has no
equivalent of MMF's smooth scrolling. That's why MMF is installed alongside it rather than replaced.

Watch for a scroll-direction conflict: Karabiner sets `mouse_flip_vertical_wheel: true` and MMF has
its own scroll handling. If scrolling feels inverted or doubly-inverted, turn one of them off.

Karabiner reloads `~/.config/karabiner/karabiner.json` on external change, so edits apply live.
Validate after editing (`python3 -m json.tool`) and keep a backup.

### Fn / 🌐 also opens the emoji panel

MacWhisper dictation is bound to `fn` (`dictationKeyboardButton = "fn"`). macOS *also* claims that
key — unset, it defaults to Show Emoji & Symbols, so every dictation trigger pops the emoji pane too.

```bash
defaults write com.apple.HIToolbox AppleFnUsageType -int 0
#  0 = Do Nothing   1 = Change Input Source   2 = Show Emoji & Symbols   3 = Start Dictation
```

GUI equivalent: System Settings → Keyboard → "Press 🌐 key to" → Do Nothing.

Takes effect immediately — **no logout needed** (verified on macOS 15.7.9). If it ever doesn't,
switch it to another value and back in Settings to force a reload, since the pane will already
display the value written by `defaults`.

## Migrating prefs to another Mac

`scp`-ing a plist **loses silently**: `cfprefsd` caches the domain, and a running app rewrites it on
quit. Quit the app first, then go through `defaults`, which writes via `cfprefsd` so the value is live:

```bash
defaults export <domain> /tmp/x.plist        # on the source
defaults export <domain> /tmp/backup.plist   # on the target, FIRST
defaults import <domain> /tmp/x.plist        # on the target
```

**`defaults export` writes a *binary* plist, so grepping it finds nothing** — including when you're
checking for hardcoded `/Users/<name>` paths before copying. Worse, `grep -c` on a binary file prints
an empty string rather than `0`, so a shell test on it reads as "clean". Convert first:

```bash
plutil -convert xml1 -o - x.plist | grep -oE "/Users/[^<\"]*"
```

**Keychain-backed values do not travel** in a plist — licenses and provider API keys stay behind (see
MacWhisper). A plist carries the *setting*, never the *secret*.

**Karabiner: strip hardware-specific device blocks before copying `karabiner.json`.** A device entry
whose identifiers are only `{"is_keyboard": true}` matches **every** keyboard, so a workaround for one
machine's broken hardware follows you onto machines that don't need it. The MBP's dead-spacebar remap
(`spacebar` → `vk_none`, `right_option` → `spacebar`) disables space on the target the moment
Karabiner is enabled there:

```bash
python3 - <<'EOF'
import json
p = "/Users/<you>/.config/karabiner/karabiner.json"
d = json.load(open(p)); prof = d["profiles"][0]
prof["devices"] = [v for v in prof["devices"]
                   if not any(m["from"].get("key_code") == "spacebar"
                              for m in v.get("simple_modifications", []))]
json.dump(d, open(p, "w"), indent=4)
EOF
```

Profile-level `simple_modifications` are hardware-agnostic and safe to carry as-is.

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

**Apps gate on the *minor* version and report it misleadingly.** OneDrive needs 14.4+; on 14.1.2 its
installer prints `Cannot install on volume / because it is disabled` next to the version requirement,
which reads like a disk or volume fault rather than a version one. Check the version line first.

**Xcode/Swift coupling:** Swift 6.0 requires Xcode 16 / CLT 16, which requires **macOS 14.5+**. A
Mac on 14.1.2 has Swift 5.10 and cannot build any package declaring
`swift-tools-version: 6.0` — including `padded-parakeet`. Upgrade macOS first.

**A macOS upgrade does NOT update the Command Line Tools.** Verified: after going 14.1.2 → 15.7.9,
`swift --version` still reported 5.10 and the SDK was still 14.4. Install CLT separately:

```bash
softwareupdate --list                                             # look for "Command Line Tools for Xcode-16.4"
sudo softwareupdate --install "Command Line Tools for Xcode-16.4" # ~862 MB → Swift 6.1.2, SDK 15.5
```

Don't trust `pkgutil --pkg-info=com.apple.pkg.CLTools_Executables` afterwards — its receipt still
read `15.3.0` while `swift --version` correctly reported 6.1.2. Check `swift --version`.

### After a major macOS upgrade

What survived a 14 → 15 upgrade, so you don't waste time re-doing it: `pmset` sleep settings, Remote
Login, Screen Sharing, and **Karabiner** (its DriverKit extension came back `[activated enabled]`
with no re-approval — the commonly-repeated advice that it needs re-granting was wrong here).

What broke:

- **Tailscale was stopped** and had to be relaunched (`open -a Tailscale`). On a machine you reach
  remotely this is the one that locks you out, so check it first.
- CLT, as above.

Also: once you're on 15, Software Update will list **macOS Tahoe 26 marked `Recommended: YES`**.
If 15 was a deliberate choice, that's a one-click mistake waiting to happen.

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

## Measuring disk space (this is where I got things wrong twice)

**`du` cannot account for a whole macOS disk.** Firmlinks make `/Users`, `/Library`, `/Applications`
appear under `/` while physically living on the data volume, and `du -x` does not reliably detect the
boundary. Symptom: `/System` reports 81 GB while every one of its children reports 0 B, and the
totals don't reconcile with `df`. Don't build a theory on it — I concluded "108 GB of unexplained
cruft" that didn't exist.

Ground truth is **per-filesystem `df`**:

```bash
df -H / /System/Volumes/Data /System/Volumes/Update
```

**`sudo du` still fails without Full Disk Access.** TCC blocks protected paths even for root, so you
get a wall of "Operation not permitted". Either grant your terminal FDA (System Settings → Privacy &
Security → Full Disk Access) or — easier — read **System Settings → General → Storage**, which is
Apple's own accounting and needs no permissions.

**APFS reclaims asynchronously.** Deleting 15 GB and immediately re-running `df` can show almost no
change. Wait and re-measure before concluding the delete failed.

Two things that legitimately hold space after an upgrade:

```bash
# OS-update snapshot; check for "Purgeable: No" and "limits the minimum size of APFS Container"
diskutil apfs listSnapshots /
sudo tmutil deletelocalsnapshots <com.apple.os.update-…>

# the installer itself, ~15 GB — root-owned if mist ran under sudo, so this needs sudo
sudo rm -rf ~/Downloads/Install\ macOS\ *.app
```

Sizing reality on a 256 GB machine (`APPLE SSD AP0256Q` → 245 GB APFS container): macOS + apps +
`/Library` take ~38 GB, leaving ~207 GB. A 20 GB game repo, an 8.6 GB Unity editor, a Sequoia
installer and two concurrent builds will genuinely run it out — free space dropped from 53 GB to
32 GB in one evening. Watch out for Unity's `Library/` cache on first project open (plausibly
10–40 GB for a repo with thousands of LFS art files) and Rust `target/` dirs.

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
engine needs the macOS 26 SDK and lives on the `speech-transcriber` branch. Needs Swift 6.0, so
macOS 14.5+ and CLT 16.

```bash
source ~/.pexprc                                   # install.sh hard-requires OPENROUTER_API_KEY
cd ~/Developer/padded-parakeet/swift && ./install.sh
tail -f ~/Library/Logs/PaddedParakeet.log
```

`install.sh` builds release (~390 s cold, most of it fetching WhisperKit/hummingbird/swift-nio),
copies the binary **and its resource bundle** to `~/bin`, writes the LaunchAgent with the API key
baked in (launchd can't source shell files), and bootstraps it. It listens on **`127.0.0.1:8737`**,
which must match MacWhisper's `customOpenAIWhisperProviderBaseURL`. Override with `ADDR=host:port`.
`App.swift`'s own default is `:8000` — too contended on a dev machine, which is why the plist passes
`--addr` explicitly.

Then grant **Accessibility** to `~/bin/PaddedParakeet` (System Settings → Privacy & Security →
Accessibility), or the log warns "edit mode will not read selected text" and edit mode silently
won't work.

**Never sync a compiled Swift binary between Macs.** `Bundle.module` checks next to the executable
and then falls back to the absolute `.build` path baked in at compile time. A binary carried over
from another machine resolves that fallback into the *other* machine's home, dies at startup, and —
because the agent sets `KeepAlive` — restarts forever. This produced 128 crash-loops with an
inherited `~/bin/PaddedParakeet` before a local build replaced it. Symptom to recognise:

```
Fatal error: could not load resource bundle: from /Users/<you>/bin/X_X.bundle
  or /Users/<someone-else>/Developer/…/.build/…/X_X.bundle
```

Rebuild from source on each machine. And when debugging a `KeepAlive` agent, check
`grep -c 'Mode: padded' ~/Library/Logs/PaddedParakeet.log` — a high count means crash-looping, and
sampling the PID twice tells you whether it's stabilised.

**Rectangle** is the window manager (drag-to-top vertical extend). **Mac Mouse Fix is installed
alongside Karabiner**, not replaced by it — it owns `button5` Click & Drag for switching screens,
which Karabiner can't express. See the Karabiner section for the button split.
