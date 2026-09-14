# Peponi One Day (Omarchy)

Keyboard-first **one-day** focus overlay for [Omarchy](https://omarchy.org/).

Use it **locally on this machine** (no account) or sign in with a **paid** [peponi.to](https://peponi.to) license so we can copy your existing tasks here. After that, daily work stays on disk — peponi.to is not a live Omarchy database.

Browse today with `←` / `→`, add with `n`, remove with `Delete`, open **Not Yet** with `y`, send a Not Yet task to today with `a`, jump to today with `t`. A small local `peponi` CLI stores tasks on disk, and can copy a snapshot from peponi.to when you sign in.

![Peponi One Day overlay](preview.png)

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

Then finish setup (CLI + choose local or paid sign-in + optional keybindings):

```bash
~/.config/omarchy/plugins/peponi.one-day/scripts/setup.sh
```

Setup asks how you want to use it:

1. **Use locally on this Omarchy machine** — no peponi.to account. Tasks live in `~/.local/share/peponi/store.json`.
2. **Sign in with a paid peponi.to license** — email and password; trial-only accounts are rejected. We copy your existing tasks onto this machine. New work stays here (we are not a live cloud for Omarchy).

You can also pick later in the overlay: `l` for local, `a` to sign in.

**Full walkthrough:** [docs/USAGE.md](docs/USAGE.md) · on the site: [peponi.to/how-to#omarchy](https://peponi.to/how-to#omarchy)

Open it:

```bash
omarchy-shell shell toggle peponi.one-day '{}'
```

### Local / development install

From this checkout (copy into Omarchy plugins, no git URL needed):

```bash
./scripts/install.sh
./scripts/setup.sh
```

Skip the prompt:

```bash
PEPONI_SETUP_MODE=local ./scripts/setup.sh
# or
PEPONI_SETUP_MODE=cloud ./scripts/setup.sh
```

Point the CLI at a local Rails API while developing a paid sign-in:

```bash
export PEPONI_BASE_URL=http://127.0.0.1:3000
PEPONI_SETUP_MODE=cloud ./scripts/setup.sh
```

## Requirements

- Omarchy Linux (Quickshell + `omarchy` CLI)
- `python3` (and `curl` only if you sign in to peponi.to)
- Optional: a **paid** peponi.to account, if you want website sync
- peponi.to `/api/v1` desktop endpoints (only for the paid/cloud path)

## After install

```bash
peponi auth local          # this machine only, no account
peponi auth login          # paid peponi.to account
peponi auth status --json
peponi day $(date +%F) --json
peponi add $(date +%F) "Buy milk"
peponi rm ID
peponi not-yet --json
peponi not-yet add "Call mum"
peponi not-yet today ID
```

- **Local mode:** `~/.local/share/peponi/store.json` (mode `0600`). Flag: `~/.config/peponi/config.json`.
- **Cloud mode:** `~/.config/peponi/credentials.json` (mode `0600`).

Switch anytime: `peponi auth local` or `peponi auth login` (copies a snapshot, then stays local). `peponi pull` refreshes the copy. `peponi auth login --cloud` keeps a live peponi.to connection. `peponi auth logout` leaves both and keeps local task files.

## Keybindings

**In-overlay:** `←`/`→` day · `n` add · `Delete` remove · `y` Not Yet · `t` today · `Esc` close · `?` help · `l` use locally · `a` sign in (the last two only when not set up yet, and `a` is sign-in only while the drawer is **closed**)

### Not Yet (the `y` drawer)

**Not Yet** is an undated inbox: tasks you are not doing today. They live in the same local file as your days (`~/.local/share/peponi/store.json`). Open the drawer, then use the same muscle memory as the day list.

| Key | What it does |
|-----|----------------|
| `y` | Open or close the Not Yet drawer |
| `n` | Add a Not Yet task (type a title, Enter) |
| `↑` / `↓` | Highlight a task in the drawer |
| `a` | Move the **highlighted** Not Yet task onto **today** |
| `Delete` | Remove the highlighted Not Yet task |
| `Esc` | Close the drawer (then the overlay) |

While the drawer is open, those keys apply to Not Yet, not the day. `a` means “sign in” only when you are **not set up yet** and the drawer is **closed**.

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
preview.png            # Plugin directory listing screenshot
qml/                   # Overlay, Service, BarWidget, …
bin/peponi             # CLI (local store or peponi.to)
scripts/install.sh     # Dev copy install
scripts/setup.sh       # CLI + local-or-sign-in (+ optional binds)
scripts/install-binding.sh
scripts/uninstall.sh
docs/
```

## Publishing this repo

When you create the GitHub remote, the install line above works unchanged. Keep `preview.png` at the repository root so [plugins.omarchy.org](https://plugins.omarchy.org/) can show it on listing cards. The Rails `/api/v1` API lives in the peponi.to app — not in this repository. Local mode does not need that API.
