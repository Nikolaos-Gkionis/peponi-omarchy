# Peponi One Day (Omarchy)

Keyboard-first **one-day** focus overlay for **paid** [peponi.to](https://peponi.to) accounts on [Omarchy](https://omarchy.org/).

Browse today with `←` / `→`, open **Not Yet** with `y`, jump to today with `t`. Data comes from peponi.to through a small local `peponi` CLI.

![Peponi One Day on Omarchy](docs/screenshot.png)

| | |
|---|---|
| **Plugin id** | `peponi.one-day` |
| **Kinds** | `service` · `overlay` · `bar-widget` |

## Install

Omarchy plugins run as unsandboxed code inside the long-lived `omarchy-shell` process. Review a plugin before you enable it.

```bash
omarchy plugin add https://github.com/Nikolaos-Gkionis/peponi-omarchy.git --enable
```

That clones into `~/.config/omarchy/plugins/peponi.one-day` and enables it. With `--enable`, Omarchy also asks where to put the **bar toggle** (left / center / right).

Then finish setup (CLI + sign-in + optional keybindings):

```bash
~/.config/omarchy/plugins/peponi.one-day/scripts/setup.sh
```

**Full walkthrough:** [docs/USAGE.md](docs/USAGE.md) · on the site: [peponi.to/how-to#omarchy](https://peponi.to/how-to#omarchy)

Open it:

```bash
omarchy-shell shell toggle peponi.one-day '{}'
```

### Local / development install

From this checkout (symlink into Omarchy plugins, no git URL needed):

```bash
./scripts/install.sh
./scripts/setup.sh
```

Point the CLI at a local Rails API while developing:

```bash
export PEPONI_BASE_URL=http://127.0.0.1:3000
./scripts/setup.sh
```

## Requirements

- Omarchy Linux (Quickshell + `omarchy` CLI)
- A **paid** peponi.to account
- peponi.to `/api/v1` desktop endpoints deployed
- `curl`, `python3`

## After install

```bash
peponi auth login
peponi auth status --json
peponi day $(date +%F) --json
peponi not-yet --json
```

Credentials: `~/.config/peponi/credentials.json` (mode `0600`).

## Keybindings

**In-overlay:** `←`/`→` day · `y` Not Yet · `t` today · `Esc` close · `?` help · `a` sign in (signed out only)

**Optional global** (setup script or `scripts/install-binding.sh`):

| Chord | Action |
|-------|--------|
| `SUPER + ALT + O` | Toggle overlay |
| `SUPER + ALT + LEFT/RIGHT` | Prev / next day |
| `SUPER + ALT + Y` | Toggle Not Yet drawer |

## Uninstall

```bash
~/.config/omarchy/plugins/peponi.one-day/scripts/uninstall.sh
# or:
omarchy plugin remove peponi.one-day --yes
```

## Layout

```
manifest.json          # Omarchy plugin contract (repo root)
qml/                   # Overlay, Service, BarWidget, …
bin/peponi             # CLI
scripts/install.sh     # Dev symlink install
scripts/setup.sh       # CLI + sign-in (+ optional binds)
scripts/install-binding.sh
scripts/uninstall.sh
docs/
```

## Publishing this repo

When you create the GitHub remote, the install line above works unchanged. The Rails `/api/v1` API lives in the peponi.to app — not in this repository.
