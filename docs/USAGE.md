# How to use Peponi One Day on Omarchy

Paid [peponi.to](https://peponi.to) accounts can run a keyboard-first **one-day Focus** overlay on [Omarchy](https://omarchy.org/).

![Peponi One Day on Omarchy](screenshot.png)

## 1. Install

```bash
omarchy plugin add https://github.com/Nikolaos-Gkionis/peponi-omarchy.git --enable
```

Omarchy asks where to place the bar toggle (**left / center / right**).

Then sign in and install the CLI:

```bash
~/.config/omarchy/plugins/peponi.one-day/scripts/setup.sh
```

Use your **paid** peponi.to email and password. Trial-only accounts are rejected.

Local Rails while developing:

```bash
export PEPONI_BASE_URL=http://127.0.0.1:3000
./scripts/setup.sh
```

## 2. Open the overlay

- Click the **P** icon on the Omarchy bar, or
- Run: `omarchy-shell shell toggle peponi.one-day '{}'`
- Optional: `Super + Alt + O` (if you installed keybindings)

Right-click the bar icon to refresh day data.

## 3. Keyboard while open

| Key | Action |
|-----|--------|
| `←` / `→` | Previous / next day |
| `y` | Toggle Not Yet drawer |
| `t` | Jump to today |
| `a` | Sign in (opens terminal; signed out only) |
| `↑` / `↓` | Move in the list |
| `Esc` | Close drawer, then overlay |
| `?` | Shortcuts help |

### Optional global chords

| Chord | Action |
|-------|--------|
| `Super + Alt + O` | Toggle overlay |
| `Super + Alt + ←/→` | Change day |
| `Super + Alt + Y` | Toggle Not Yet |

Install later with:

```bash
~/.config/omarchy/plugins/peponi.one-day/scripts/install-binding.sh
```

## 4. Move the bar toggle

```bash
omarchy bar put peponi.one-day --section left
omarchy bar put peponi.one-day --section center
omarchy bar put peponi.one-day --section right
```

## 5. CLI cheatsheet

```bash
peponi auth login
peponi auth status --json
peponi day $(date +%F) --json
peponi not-yet --json
peponi auth logout
```

## 6. Uninstall

```bash
~/.config/omarchy/plugins/peponi.one-day/scripts/uninstall.sh
# or
omarchy plugin remove peponi.one-day --yes
```

After plugin code changes (`keepLoaded: true`), run `omarchy restart shell`.

Marketing guide on the site: [peponi.to/how-to#omarchy](https://peponi.to/how-to#omarchy)
