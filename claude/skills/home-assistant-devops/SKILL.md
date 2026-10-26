---
name: home-assistant-devops
description: How Tommaso's condo Home Assistant is run — the home_claude repo, deploying the Docker stack on the Hammerbot PC, the SONOFF Dongle-M Zigbee coordinator and ZHA, pairing devices, access rules, and keeping device manuals. Invoke when working on Home Assistant, Zigbee devices, smart plugs/lights/sensors at home, or the ~/Developer/home_claude repo.
---

# Home Assistant devops

Everything lives in `~/Developer/home_claude` (private, `github.com/Tomcc/home_claude`); commit
and push as you go. The device inventory is `docs/condo-manual.md`.

## Never expose it to the internet

- **Reach HA only over the LAN or Tailscale**: no port forwards, tunnels, Nabu Casa or Funnel.
- **Prefer local Zigbee devices over Wi-Fi/cloud ones** when suggesting purchases.

## Open the UI

- `http://hammerbot.tail094345.ts.net:8123` over Tailscale.
- `http://192.168.4.122:8123` on the home Wi-Fi, for people without Tailscale.
- **Call the API with `$HOME_ASSISTANT_KEY`**, an admin long-lived token kept in the Keychain by
  bash_hackery's `save_key`: `curl -H "Authorization: Bearer $HOME_ASSISTANT_KEY" .../api/`.

## Deploy or update

Bump the image tag in `compose.yaml`, then run `./deploy.sh` from the Mac.

- **Pin exact HA versions**, never `stable`: `gh api repos/home-assistant/core/releases/latest`.
- **Add add-ons as extra services in `compose.yaml`**: this is HA Container, with no add-on store.
- **Run every pull through the `home_claude deploy` task** (what `deploy.sh` does), never
  `docker compose pull` over SSH: Docker's credential helper fails in passwordless logons (SSH keys,
  S4U), even for public images, with `A specified logon session does not exist`.
- **Re-run `register-tasks.ps1` over RDP after the `tomma` password changes**: both the deploy task
  and `Ensure Docker Desktop for CI` store it, and stop working with a stale one.
- **Leave `credsStore` in `~\.docker\config.json` alone**: Docker Desktop re-adds it on every start.
- Operate the PC itself (SSH, RDP, the CI runner sharing it) per the repo skill
  `hammerbot-ci-devops` in `~/Developer/tomatocake-dev`.

## Connect the Zigbee coordinator

The SONOFF Dongle-M is wired to the attic eero, in Zigbee coordinator mode (EmberZNet).

- **Find it by mDNS**, it advertises its own settings:
  ```bash
  timeout 4 dns-sd -L "SONOFF Dongle-M_2968" _zigbee-coordinator._tcp local.
  dscacheutil -q host -a name Dongle-M.local
  ```
- **Configure ZHA with radio type EZSP, `socket://<dongle-ip>:6638`, baud `115200`**. Use the IP:
  the HA container can't resolve `.local` names.
- **Expect no auto-discovery**: Docker Desktop doesn't pass LAN multicast, so add devices by hand.

## Pair devices

- **Pair from the coordinator outward**: mains-powered routers first (dimmers, plugs), battery
  sensors last, since a sensor picks its parent when it joins.
- **Factory reset a device before pairing**: most are still bound to the old Alexa Echo hub.
- **Use the reset steps from the manual in `docs/manuals/`**, not from memory.
- **Keep bulbs off switched circuits as routers**: a bulb with its power cut drops its routes.

## Keep every device manual in the repo

- **Save every device's official manual in full to `docs/manuals/`** when a device is added: PDF
  from the manufacturer's site, or the full page as markdown if there's no PDF.
- **Use manufacturer domains only**, never manualslib or mirrors.
- **Name files `<brand>-<product>-<model>.pdf`** and list them in `docs/condo-manual.md`.
