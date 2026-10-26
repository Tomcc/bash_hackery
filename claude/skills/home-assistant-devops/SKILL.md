---
name: home-assistant-devops
description: How Tommaso's condo Home Assistant is run — the home_claude repo, deploying the Docker stack (HA, Zigbee2MQTT, Mosquitto) on the Hammerbot PC, the SONOFF Dongle-M Zigbee coordinator, pairing devices, access rules, and keeping device manuals. Invoke when working on Home Assistant, Zigbee devices, smart plugs/lights/sensors at home, or the ~/Developer/home_claude repo.
---

# Home Assistant devops

Everything lives in `~/Developer/home_claude` (private, `github.com/Tomcc/home_claude`).

- **Read `docs/home-assistant-manual.md` first**: it has the architecture, addresses, deploy,
  rebuild-from-nothing steps, Zigbee2MQTT and pairing. The device inventory is
  `docs/condo-manual.md`.
- **Commit and push as you go**: git is the long-term memory for this setup.
- **Update the manual in the same commit** whenever the setup changes, so a fresh session can
  rebuild it from the docs alone.

## Find the passwords

- **Tommaso's HA password is in iCloud Passwords**, saved under the HA Tailscale name.
- **The dongle's web console uses the same password as HA.**
- **Always give Tommaso hostnames, never raw IPs**, for any page he opens: Passwords only saves and
  autofills for names. Use `http://Dongle-M.local` (mDNS, home Wi-Fi) for the dongle.

## Never expose it to the internet

- **Reach HA only over the LAN or Tailscale**: no port forwards, tunnels, Nabu Casa or Funnel.
- **Never leave admin access open by default**: every admin UI gets a login, and non-owner HA
  accounts are non-admin. Network limits alone don't count; the tailnet has teammates' machines.
- **Keep secrets in the Keychain via `save_key`**, never in git; `deploy.sh` turns them into `.env`.
- **Prefer local Zigbee devices over Wi-Fi/cloud ones** when suggesting purchases.

## Prefer declarative config

- **Put settings in `compose.yaml`** (`ZIGBEE2MQTT_CONFIG_*` env vars) or YAML in git, never only
  in a UI.
- **Script UI-only HA setup through the API**, then record the exact call in the manual.
- **Call the API with `$HOME_ASSISTANT_KEY`**, an admin long-lived token kept in the Keychain by
  bash_hackery's `save_key`: `curl -H "Authorization: Bearer $HOME_ASSISTANT_KEY" .../api/`.

## Deploy or update

- **Deploy only with `./deploy.sh`**, never `docker compose pull` over SSH: Docker's credential
  helper fails in passwordless logons with `A specified logon session does not exist`.
- **Pin exact image versions**, never `stable` or `latest`.
- Operate the PC itself (SSH, RDP, the CI runner sharing it) per the repo skill
  `hammerbot-ci-devops` in `~/Developer/tomatocake-dev`.

## Pairing new devices

Follow the manual's "Pair a device" section. After every device joins, always do all of:

1. **Name it and assign its area** in `ha/devices.yaml`, then `uv run scripts/sync_devices.py`.
2. **Update its firmware**, after naming: a rename hides an update already in progress.
3. **Save its official manual** to `docs/manuals/` (below), if it's a new model.
4. **Commit and push.**

- **Use the reset steps from the manual in `docs/manuals/`**, not from memory.
- **Pair from the dongle outward**: mains-powered routers first, battery sensors last.
- **Keep areas in `ha/areas.yaml`** (`uv run scripts/sync_areas.py`), never only in the HA UI.
- **Keep bulbs off switched circuits as routers**: a bulb with its power cut drops its routes.
- **Never delete the `z2m_data` volume**: it holds the network key, and losing it means
  re-pairing every device.

## Keep every device manual in the repo

- **Save every device's official manual in full to `docs/manuals/`** when a device is added: PDF
  from the manufacturer's site, or the full page as markdown if there's no PDF.
- **Use manufacturer domains only**, never manualslib or mirrors.
- **Name files `<brand>-<product>-<model>.pdf`** and list them in `docs/condo-manual.md`.
