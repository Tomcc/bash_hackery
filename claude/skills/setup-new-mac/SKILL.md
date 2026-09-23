---
name: setup-new-mac
description: >
  Set up a Mac from scratch — a new machine, a loaner, or a temporary account on someone else's
  hardware. Invoke when asked to "set up this Mac", migrate settings between Macs, enable remote
  access (SSH / Screen Sharing / Tailscale), install a specific Unity or macOS version, wire up
  dotfiles from bash_hackery, or tear a borrowed machine back down. Read the relevant section
  before running commands.
---

# Setting up a Mac

- **Always** repopulate fresh, never from Time Machine. Only paid licenses can't be regenerated
  (see MacWhisper); SSH keys are per-machine and disposable.
- Install by hand following this skill; there is no `setup_mac.sh` (it rotted and was deleted).

## Run sudo commands

The agent's Bash tool has no TTY (`sudo` fails with "a terminal is required to read the
password"). Hand the user a single chained paste, via the open-terminal-tab skill if useful:

```bash
brew install mist-cli && sudo mist download installer "15.7.9" application --output-directory ~/Downloads
```

## Drive the machine over SSH as an agent

- **Always** redirect output inside a remote login shell — `pexp_setup.sh` spawns
  `pexp_bin watch $$ &`, which holds the SSH stdout open, so the command looks hung forever:

  ```bash
  ssh host 'zsh -ilc "…" > /tmp/out 2>/dev/null </dev/null; cat /tmp/out'
  ```

- Non-login shells (`ssh host 'cmd'`) skip `.zshrc`, so `PATH` lacks `/opt/homebrew/bin`: call
  `brew` by absolute path or export it first.
- Expect orphan `pexp_bin` watchers to kill your session. `kill(pid, SIGUSR2).expect(…)` at
  `pexp/src/main.rs:140` panics with `ESRCH` once the parent shell is gone, inside a C callback
  (notify's fsevents), so since Rust 1.81 it `abort()`s the process group on the next `.pexprc`
  write. Only freshly built `pexp_bin` does this; older binaries unwind harmlessly.
- Find files in TCC-blocked dirs with Spotlight — sshd lacks Full Disk Access, so `ls ~/Downloads`
  gives *Operation not permitted*, and writes to `~/Desktop`, `~/Documents`, `~/Downloads` error
  (dotfiles are fine):

  ```bash
  mdfind -name "Install macOS"          # finds it
  mdls -name kMDItemVersion "…app"      # metadata works; kMDItemFSSize is null for bundles
  ```

- Pre-fetch `.pkg` casks and hand the user the install — they need `sudo`:

  ```bash
  brew fetch --cask zoom onedrive       # no sudo, lands in brew's cache
  # user then pastes: brew install --cask zoom onedrive
  ```

## Enable remote access

Use `launchctl` — it needs no TCC grant. `systemsetup -setremotelogin on` exits 0 and does nothing
when the terminal lacks Full Disk Access.

```bash
sudo launchctl enable system/com.openssh.sshd
sudo launchctl bootstrap system /System/Library/LaunchDaemons/ssh.plist
# Screen Sharing:
sudo launchctl enable system/com.apple.screensharing
sudo launchctl bootstrap system /System/Library/LaunchDaemons/com.apple.screensharing.plist
```

Verify: `launchctl print system/com.openssh.sshd >/dev/null 2>&1 && echo ON || echo OFF`

On a borrowed machine, scope SSH to one user (the toggles are machine-wide):
`sudo dseditgroup -o edit -a <user> -t user com.apple.access_ssh`

**Tailscale** gives stable MagicDNS names (`ssh user@chriss-mac-mini`) from anywhere. For ACLs and
tags see the tailscale-management-manual skill.

- **Always** set `pmset -a sleep 0` — a sleeping Mac is off the tailnet, and `womp` (Wake on LAN)
  can't wake it over Tailscale. `displaysleep` can stay.
- Symlink the Mac App Store build's CLI:
  `/Applications/Tailscale.app/Contents/MacOS/Tailscale` → `/usr/local/bin/tailscale`.
- Delete stale duplicate devices (`host-1`, `host-2`) or MagicDNS may resolve the wrong one.

## SSH keys with Secretive

Secure Enclave keys are non-exportable and machine-bound; replace, never migrate. Git auth is
HTTPS + gh token, so a missing SSH key breaks almost nothing.

- Authorize A → B by putting A's public key in B's `~/.ssh/authorized_keys`. Fetch it without
  touching A: `curl -s https://github.com/<username>.keys`.
- Identify keys by elimination — `.keys` strips comments; Secretive keys are always
  `ecdsa-sha2-nistp256`. Compare with the local agent:

  ```bash
  SSH_AUTH_SOCK=~/Library/Containers/com.maxgoedjen.Secretive.SecretAgent/Data/socket.ssh ssh-add -L
  ```

- Set `700` on `~/.ssh` and `600` on `authorized_keys`, or sshd silently ignores it.
- Multiplex connections so Secretive prompts once (without Touch ID each handshake is a password
  dialog that stalls many `rsync` calls):

  ```
  Host <target>
    ControlMaster auto
    ControlPath ~/.ssh/cm-%r@%h:%p
    ControlPersist 10m
  ```

## Store API keys in the Keychain

On macOS, `keychain_env.zsh` (enabled by `USE_KEYCHAIN_ENV`) exports every Keychain item named
`shell_env.<VARNAME>` at shell start. Manage keys with `save_key NAME value`, `list_keys`,
`delete_key NAME` — never by editing a dotfile. A fresh Mac has no keys: copy them from another
Mac's Keychain or re-issue them. Linux still uses pexp (`USE_PEXP`, plaintext `~/.pexprc`).

`security` quirks the helpers work around:

- Pass values via argv — `-w` from stdin silently truncates at 128 characters.
- Delete-then-add to update — `-U -A` on an existing item prompts for the login password ("wants
  to change access permissions"); `-A` on a new item is silent.
- Reject newlines — `-w` hex-encodes such values indistinguishably from hex-looking ones.
- Count only `svce` lines in `dump-keychain` — each service name also appears as label
  `0x00000007`.
- Batch reads into one `security -i` process: ~75ms total versus ~900ms per spawned key.

For per-project secrets, scope them with `direnv` (`.envrc` is gitignored) instead of exporting
globally, and fetch lazily in `.envrc` (~10–30ms per lookup):

```zsh
security add-generic-password -a "$USER" -s <name> -w      # store (prompts, stays out of history)
keyfrom() { security find-generic-password -s "$1" -w 2>/dev/null }
```

`add-generic-password` items are non-synchronizable, so they stay off iCloud Keychain. Use
`direnv reload` to refresh.

## Install baseline packages

Install Homebrew; on Apple Silicon it lands in `/opt/homebrew`, off `PATH` until you run its
`shellenv` line.

```bash
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
brew install git zsh atuin direnv fzf zoxide diff-so-fancy thefuck rustup nvm
brew install --cask alfred alt-tab iterm2 ghostty karabiner-elements secretive stats vlc
mkdir -p ~/.nvm              # else every shell start errors on $NVM_DIR
rustup default stable        # rustup ships with no toolchain
cargo install --path ~/Developer/bash_hackery/pexp     # provides pexp_bin
```

- Keep the brew `nvm`: `nvm_hook.zsh` sources `$(brew --prefix nvm)/nvm.sh`.
- `diff-so-fancy` is `core.pager` in `base.gitconfig`; if missing, interactive git breaks
  silently (scripted calls piped to `head` skip the pager).
- `cargo` also needs the PATH fix in the next section.

## Fix `cargo: command not found` with a working rustup

Brew's `rustup` is keg-only (it conflicts with the `rust` formula) and no longer ships
`rustup-init`, so `cargo`, `rustc`, `clippy-driver`, `rustfmt`, `rust-analyzer` stay unlinked while
`rustup show` looks healthy. Add the keg to `~/.zshenv`:

```zsh
# opt/ not Cellar/ so it survives version bumps
export PATH="/opt/homebrew/opt/rustup/bin:$PATH"
```

- Keep `$HOME/.cargo/bin` on `PATH` too, for `cargo install` output like `pexp_bin`.
- Verify with `rustup which cargo` → `~/.rustup/toolchains/...`.
- Never `brew install rust`: it ignores `main-repo/rust-toolchain.toml` (`channel = "1.97.1"`;
  the formula shipped 1.98.1) and can't `rustup target add` the Linux targets cargo-lambda needs
  for `cloud_api/*`. Inside the repo, `rustup show active-toolchain` should say
  `overridden by '…/rust-toolchain.toml'`.
- Toolchains cost ~1.3–1.4 GB each; `rustup toolchain uninstall stable` is safe when every repo
  pins its own channel.

## Wire up dotfiles from bash_hackery

Add to `~/.zshrc` (`ZSH_PACKAGES` self-locates via `realpath`). Re-export `SSH_AUTH_SOCK` after it
on a machine with a different short username — `shared.zshrc` has hardcoded `/Users/<name>/…`,
which silently breaks all SSH auth (fix upstream as `$HOME/…`):

```zsh
source ~/Developer/bash_hackery/shared.zshrc
export SSH_AUTH_SOCK="$HOME/Library/Containers/com.maxgoedjen.Secretive.SecretAgent/Data/socket.ssh"
```

- Check `.gitignore` for the same bug: `claude/projects/-Users-<name>` won't match elsewhere.
- Symlink all of `~/.claude` into the repo (`ln -s ~/Developer/bash_hackery/claude ~/.claude`),
  so memory writes are repo changes. Linking only `~/.claude/skills` leaves files `settings.json`
  references by absolute path (e.g. `statusline-command.sh`) missing.
- Keep the `claude/` ignore rules a whitelist; blacklisting leaks every new artifact type (e.g.
  `workflows/`, `auto-mode-classifier-error.txt`). New files like `statusline-command.sh` need an
  explicit `!` line:

  ```
  claude/projects/*/*
  !claude/projects/*/memory/
  ```

- Init submodules by name — `zsh-histdb` and `zsh-z` are orphaned gitlinks with no `.gitmodules`
  entry, and git aborts on the first one, so a bare `git submodule update --init` clones nothing.
  Drop the `-c` once the global `insteadOf` below is set; it leaves no diff, unlike
  `git submodule set-url`:

  ```bash
  git -c url."https://github.com/".insteadOf="git@github.com:" \
    submodule update --init pexp zsh-autosuggestions zsh-syntax-highlighting
  ```

- On macOS `shared.zshrc` sets `USE_ANTIGEN=1`, so plugins come from antigen and those submodule
  dirs are unused.
- Expect non-fatal startup errors until the baseline packages above are installed.

## Configure git

Nothing wires up `base.gitconfig` on a Mac (only `setup_linux.sh:33` does), so `pull.rebase`,
`push.autoSetupRemote`, `rebase.autostash`, the vscode mergetool and `[user] name` are all off.
It sets name but not email. Set identity before the first commit — otherwise git invents one like
`Tommaso <tommaso@Chriss-Mac-mini.local>` that never attributes to GitHub.

```bash
git config --global include.path ~/Developer/bash_hackery/base.gitconfig
git config --global user.name "Tommaso Checchi"          # explicit: survives ~/Developer being wiped
git config --global user.email "tommaso.checchi1@gmail.com"
git config --global url."https://github.com/".insteadOf "git@github.com:"

# absolute path, not the short name "osxkeychain"
git config --global credential.helper \
  /Library/Developer/CommandLineTools/usr/libexec/git-core/git-credential-osxkeychain
```

- Keep the `insteadOf` line: `base.gitconfig` sets `submodule.recurse = true`, so every fetch hits
  the `git@github.com:` submodules and, with no SSH key, prints `Host key verification failed`.
- Keep the helper path absolute for GUI clients. Apple's git gets `osxkeychain` from its system
  config (`/Library/Developer/CommandLineTools/usr/share/git-core/gitconfig`), but Fork's git
  (2.50.1, system config `/usr/local/git/etc/gitconfig`, missing) sees no helper and fails with
  `Password authentication is not supported`. The short name fails in Fork with
  `git: 'credential-osxkeychain' is not a git command`. The path needs Xcode CLT installed.
- Verify the helper alone: `GIT_TERMINAL_PROMPT=0 GIT_ASKPASS=/usr/bin/false git ls-remote origin HEAD`
- Verify includes with `git config --get pull.rebase`; `git config --global --list` doesn't
  expand them.

## Map mouse buttons in Karabiner

Map with `pointing_button` in the device's `simple_modifications`, and set `"ignore": false` on the
device. Prefer real HID events (`apple_vendor_keyboard_key_code: mission_control`) over faked
shortcuts like Ctrl+↑:

```json
{
  "from": { "pointing_button": "button4" },
  "to": [{ "apple_vendor_top_case_key_code": "keyboard_fn" }]
}
```

- Read button numbers from `Karabiner-EventViewer.app`; Mac Mouse Fix numbers differently.
- Leave any button Mac Mouse Fix owns unbound in Karabiner, which grabs the device first. MMF
  stays installed for Click & Drag and smooth scrolling, which Karabiner can't do.
- If scrolling is inverted or doubly inverted, turn off one of Karabiner's
  `mouse_flip_vertical_wheel: true` and MMF's scroll handling.
- Validate after editing (`python3 -m json.tool`) and keep a backup; Karabiner reloads
  `~/.config/karabiner/karabiner.json` live.

Logitech (`vendor_id 1133`) split:

| Button | Owner | Action |
|---|---|---|
| `button4` | Karabiner | → `keyboard_fn` |
| `button5` | **Mac Mouse Fix** | Click & Drag to switch between screens/spaces — leave unbound in Karabiner |
| `button6` | Karabiner | → `return_or_enter` |

### Stop Fn / 🌐 opening the emoji panel

MacWhisper dictation uses `fn` (`dictationKeyboardButton = "fn"`), which macOS also maps to Show
Emoji & Symbols by default:

```bash
defaults write com.apple.HIToolbox AppleFnUsageType -int 0
#  0 = Do Nothing   1 = Change Input Source   2 = Show Emoji & Symbols   3 = Start Dictation
```

GUI: System Settings → Keyboard → "Press 🌐 key to" → Do Nothing. Applies immediately, no logout
(macOS 15.7.9). If not, switch it to another value and back in Settings.

## Toggle light/dark mode from Alfred

Install the app bundle into `~/Applications` (indexed by Alfred, Spotlight, Raycast):

```bash
~/Developer/bash_hackery/bin/install_dark_mode_toggle.sh   # then type "toggle dark" in Alfred
```

- Launch it first from the GUI and accept the Automation prompt. If dismissed, later runs fail
  with `Not authorized to send Apple events (-1743)`; rerun the install script to be asked again.
- `defaults write -g AppleInterfaceStyle` doesn't work: running apps ignore it.

## Migrate prefs to another Mac

Quit the app, then go through `defaults` so `cfprefsd` sees the change — `scp` of a plist is lost
when the running app rewrites its cached domain:

```bash
defaults export <domain> /tmp/x.plist        # on the source
defaults export <domain> /tmp/backup.plist   # on the target, FIRST
defaults import <domain> /tmp/x.plist        # on the target
```

- Convert to XML before grepping (e.g. for hardcoded `/Users/<name>`): exports are binary, and
  `grep -c` on binary prints an empty string rather than `0`.

  ```bash
  plutil -convert xml1 -o - x.plist | grep -oE "/Users/[^<\"]*"
  ```

- Expect Keychain-backed values (licenses, provider API keys) to stay behind; a plist carries
  settings only.
- Strip hardware-specific device blocks before copying `karabiner.json`. A device matched only by
  `{"is_keyboard": true}` matches every keyboard, so the MBP's dead-spacebar remap (`spacebar` →
  `vk_none`, `right_option` → `spacebar`) disables space on the target. Profile-level
  `simple_modifications` are safe to copy.

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

## Install Unity headless via Hub

Always pass `--architecture` (Hub otherwise waits on a prompt) and redirect to a file (piping to
`tail` causes `write EPIPE`). Run it with the Bash tool's `run_in_background`, never `nohup`, so it
stays visible in the task list:

```bash
"/Applications/Unity Hub.app/Contents/MacOS/Unity Hub" -- --headless install \
  --version 6000.0.31f1 --changeset a206c360e2a8 --architecture arm64 > /tmp/unity.log 2>&1
```

- Get the changeset from `ProjectSettings/ProjectVersion.txt` →
  `m_EditorVersionWithRevision: 6000.0.31f1 (a206c360e2a8)`, or from
  `curl -s "https://services.api.unity.com/unity/editor/release/v1/releases?version=6000.0.31"`.
- Confirm installs with `-- --headless editors -i`; Hub may use `~/Applications/Unity/Hub/Editor/`
  whatever `install-path --get` says. A permissions error on `/Applications/Unity/Hub/Editor` is
  usually the arch prompt.

## Install a specific macOS version

Download with `mist-cli` (see "Run sudo commands" for the paste). Software Update only offers the
current major, App Store GET on an older version redirects to it, and
`softwareupdate --list-full-installers` is empty on older macOS (14.1.2). List what Apple serves:

```bash
curl -s https://gdmf.apple.com/v2/pmv | python3 -c 'import json,sys; d=json.load(sys.stdin); print(sorted({a["ProductVersion"] for a in d["AssetSets"]["macOS"]}, reverse=True))'
```

- Versions: Liquid Glass = macOS 26 Tahoe; the last before it is 15 Sequoia. iPhone Mirroring
  needs 15+. Finder device sync works since 10.15.
- Check the minor version first when an installer errors: OneDrive needs 14.4+, and on 14.1.2 says
  `Cannot install on volume / because it is disabled`.
- Swift 6.0 needs Xcode/CLT 16, which needs macOS 14.5+. On 14.1.2 (Swift 5.10) nothing declaring
  `swift-tools-version: 6.0` builds, including `padded-parakeet`.
- Install CLT separately after a macOS upgrade (14.1.2 → 15.7.9 kept Swift 5.10, SDK 14.4).
  Verify with `swift --version`, not `pkgutil --pkg-info=com.apple.pkg.CLTools_Executables` (its
  receipt stayed `15.3.0`):

  ```bash
  softwareupdate --list                                             # look for "Command Line Tools for Xcode-16.4"
  sudo softwareupdate --install "Command Line Tools for Xcode-16.4" # ~862 MB → Swift 6.1.2, SDK 15.5
  ```

### After a major macOS upgrade

- Relaunch Tailscale first (`open -a Tailscale`) — a 14 → 15 upgrade stopped it, which locks out a
  remote machine. Then install CLT as above.
- Expect `pmset` sleep, Remote Login, Screen Sharing and Karabiner (DriverKit
  `[activated enabled]`, no re-approval) to survive.
- Avoid the one-click Tahoe 26 upgrade Software Update lists as `Recommended: YES` on 15.

## Check big clones and LFS

- Treat thousands of `D` entries and `git lfs fsck` missing objects mid-clone as LFS smudging in
  progress. Never remove `.git/index.lock` or `git reset --hard` a live clone.
- Check the process, one pattern per `pgrep` (`\|` is literal in pgrep's ERE; matching is
  case-sensitive):

  ```bash
  pgrep -fl 'git clone'
  pgrep -fil karabiner           # the app is "Karabiner-Elements"
  ```

- Run long clones with `run_in_background`, never `nohup`/`disown`. Pressing Esc in Claude Code
  kills background jobs (exit 144 = SIGTERM); re-run the clone if that happens:

  ```bash
  git clone <url> > /tmp/clone.log 2>&1
  ```

- Confirm success with `git status --porcelain | wc -l` reaching 0, not directory size.

## Measure disk space

Use per-filesystem `df`; `du` can't account for a whole disk (firmlinks put `/Users`, `/Library`,
`/Applications` under `/`, and `du -x` misses the boundary — e.g. `/System` 81 GB, children 0 B):

```bash
df -H / /System/Volumes/Data /System/Volumes/Update
```

- Read System Settings → General → Storage when `sudo du` hits "Operation not permitted" (TCC
  blocks root without Full Disk Access).
- Wait and re-measure after deleting; APFS reclaims asynchronously.
- Check the two usual post-upgrade holders:

  ```bash
  # OS-update snapshot; check for "Purgeable: No" and "limits the minimum size of APFS Container"
  diskutil apfs listSnapshots /
  sudo tmutil deletelocalsnapshots <com.apple.os.update-…>

  # the installer itself, ~15 GB — root-owned if mist ran under sudo
  sudo rm -rf ~/Downloads/Install\ macOS\ *.app
  ```

- Budget a 256 GB Mac (`APPLE SSD AP0256Q` → 245 GB container) at ~207 GB free after macOS, apps
  and `/Library` (~38 GB). A 20 GB game repo, 8.6 GB Unity editor, a Sequoia installer and two
  builds fill it; Unity's first-open `Library/` (plausibly 10–40 GB) and Rust `target/` dirs are
  the big growers.

## Borrowed machine: hygiene and teardown

Check the state:

```bash
diskutil apfs list | grep -i FileVault     # "No (Encrypted at rest)" on Apple Silicon
system_profiler SPNVMeDataType | grep TRIM
```

- Deleting the account is enough: Apple Silicon hardware-encrypts the SSD regardless of
  FileVault, and with TRIM deleted blocks aren't practically recoverable. Skip secure-erase tools
  and FileVault (the owner has admin anyway).
- Expect the owner's admin to be able to `sudo` into your home while it exists.
- Turn off unneeded Apple ID dataclasses (iCloud Keychain, Photos, Mail, Notes, Contacts, Desktop)
  right after sign-in — Photos and Mail backfill quietly.

Teardown:

```bash
rm ~/.pexprc                                        # plaintext keys
gh auth logout
rm -rf ~/.aws ~/.ssh ~/.claude ~/.claude.json ~/.config
```

Then sign out of Apple ID (removing local copies) and Slack/Discord/Signal/Chrome; delete the
account with **Delete the home folder**; revert any `chown` under `/Applications`; turn off Remote
Login + Screen Sharing; restore `pmset` (default `sleep 60 displaysleep 60`).

## Set up apps

### MacWhisper

- License: `524A16AB-1FC2446E-994D2247-E2CD340B` (also in Notes). Enter it in the UI — license and
  provider API keys are in the Keychain, so the plist
  `~/Library/Preferences/com.goodsnooze.MacWhisper.plist` (`isPro`, settings) doesn't carry it
  (`HasMigratedFromOldKeychainWrapper` is the tell).
- The brew cask is the direct/Gumroad build. `/Applications/MacWhisper.app/Contents/_MASReceipt`
  marks an App Store copy (no key). Search email for **Gumroad** receipts.
- Set the **API Key field to `none`** in the UI for the local server; it's Keychain-backed, so
  `defaults write` can't set it and a missing value fails auth silently.

padded-parakeet settings in prefs:

```
customOpenAIWhisperProviderBaseURL = http://127.0.0.1:8737
customOpenAIWhisperProviderModel   = aaaaaaa
selectedRunnerConfig               = {"engine":{"customOpenaiCloud":{}}}
dictationRunnerConfig              = {"engine":{"customOpenaiCloud":{}}}
```

### padded-parakeet

`main` is Swift-only (the Rust server is gone); the Apple SpeechTranscriber engine needs the
macOS 26 SDK and lives on `speech-transcriber`. Needs Swift 6.0 (macOS 14.5+, CLT 16).

```bash
source ~/.pexprc                                   # install.sh hard-requires OPENROUTER_API_KEY
cd ~/Developer/padded-parakeet/swift && ./install.sh
tail -f ~/Library/Logs/PaddedParakeet.log
```

- `install.sh` builds release (~390 s cold), copies the binary and its resource bundle to `~/bin`,
  writes the LaunchAgent with the API key baked in, and bootstraps it.
- It listens on `127.0.0.1:8737`, matching MacWhisper's base URL; override with `ADDR=host:port`.
  The plist passes `--addr` because `App.swift` defaults to the busy `:8000`.
- Grant **Accessibility** to `~/bin/PaddedParakeet`, or edit mode silently fails (log: "edit mode
  will not read selected text").
- **Always** rebuild on each Mac, never copy the binary: `Bundle.module` falls back to the
  compile-time `.build` path, so a copied binary dies at startup and `KeepAlive` crash-loops it:

  ```
  Fatal error: could not load resource bundle: from /Users/<you>/bin/X_X.bundle
    or /Users/<someone-else>/Developer/…/.build/…/X_X.bundle
  ```

- Detect crash-looping with `grep -c 'Mode: padded' ~/Library/Logs/PaddedParakeet.log` (high count
  = looping); sample the PID twice to see if it stabilised.

### Others

- **Rectangle** is the window manager (drag-to-top vertical extend).
- **Mac Mouse Fix** runs alongside Karabiner; see the Karabiner section.
