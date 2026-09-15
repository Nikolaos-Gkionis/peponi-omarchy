# How to use Peponi One Day on Omarchy

Use it **locally** (no account) or sign in with a **paid** [peponi.to](https://peponi.to) license so we can copy your tasks onto this machine. After that, Omarchy does not use peponi.to as a live database.

![Peponi One Day on Omarchy](screenshot.png)

## 1. Install

```bash
omarchy plugin add https://github.com/Nikolaos-Gkionis/peponi-omarchy.git --enable
```

Omarchy asks where to place the bar toggle (**left / center / right**).

Then install the CLI and choose how to store tasks:

```bash
~/.config/omarchy/plugins/peponi.one-day/scripts/setup.sh
```

Setup offers two options:

| Choice | What it does |
|--------|----------------|
| **Use locally** | No peponi.to account. Tasks stay on this machine in `~/.local/share/peponi/store.json`. |
| **Sign in** | Paid peponi.to email and password. Trial-only accounts are rejected. We copy your existing tasks onto this machine; new work stays local. |

Press Enter at the numbered prompt to pick **local**. Skip the prompt in scripts with `PEPONI_SETUP_MODE=local` or `PEPONI_SETUP_MODE=cloud`.

If you skip setup, the overlay still asks: `l` = local, `a` = sign in (opens a terminal). After you are set up — or while **Not Yet** is open — `a` means “put this inbox task on today”.

Local Rails while developing a paid sign-in:

```bash
export PEPONI_BASE_URL=http://127.0.0.1:3000
PEPONI_SETUP_MODE=cloud ./scripts/setup.sh
```

## 2. Open the overlay

- Click the **P** icon on the Omarchy bar, or
- Run: `omarchy-shell shell toggle peponi.one-day '{}'`
- Optional: `Super + Alt + O` (if you installed keybindings)

Right-click the bar icon to refresh day data.

## 3. Keyboard while open

| Key | Action |
|-----|--------|
| `h` / `l` or `←` / `→` | Previous / next day |
| `j` / `k` or `↑` / `↓` | Move highlight in the list |
| `Space` | Tick / untick the highlighted task |
| `K` / `J` | Move the highlighted task up / down |
| `n` | Add a task (on this day, or in Not Yet if the drawer is open) |
| `Delete` / `Backspace` | Remove the highlighted task (day list, or Not Yet if the drawer is open) |
| `r` | Toggle rolling unfinished tasks onto today |
| `y` | Toggle Not Yet drawer — then `n` / `a` / `Delete` / `j` `k` / `K` `J` apply there |
| `a` | **Drawer open:** move the highlighted Not Yet task onto **today**. **Drawer closed** and not set up yet: sign in with peponi.to |
| `t` | Jump to today |
| `l` | Use locally on this machine (only when not set up yet). Once set up, `l` is next day |
| `Esc` | Close composer / drawer, then overlay |
| `?` | Shortcuts help |

Mouse: click the checkbox to tick, click `↑` / `↓` on a row to reorder, click **Roll unfinished to today** to toggle.

Unfinished tasks stay at the top (same as peponi.to). If roll-over is on — the website default, and whatever you last saved on peponi.to after a paid sign-in — opening **today** moves leftover unfinished tasks forward. Local-only users toggle that with `r` or `peponi pref roll-over on|off`.

### Not Yet (press `y`)

Think of **Not Yet** as a holding tray. Tasks there have no date until you are ready.

1. Press `y` to slide the tray up.
2. Press `n`, type a title, Enter — it stays in the tray (saved on this machine).
3. Press `↑` / `↓` until the task you want is highlighted.
4. Press `a` — that task leaves Not Yet and appears on **today**.
5. Press `Delete` if you want to throw a tray item away instead.

CLI equivalent of step 4: `peponi not-yet today ID`.

### Optional global chords

| Chord | Action |
|-------|--------|
| `Super + Alt + O` | Toggle overlay |
| `Super + Alt + ←/→` | Change day |
| `Super + Alt + Y` | Toggle Not Yet |
| `Super + Alt + Space` | Tick the highlighted task |
| `Super + Alt + K` / `J` | Move the highlighted task up / down |

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
peponi auth local              # this machine only
peponi auth login              # paid license, copy tasks here
peponi pull                    # refresh the copy from peponi.to
peponi auth status --json
peponi day $(date +%F) --json
peponi add $(date +%F) "Buy milk"
peponi tick ID
peponi move ID up
peponi pref roll-over on
peponi rm ID
peponi not-yet --json
peponi not-yet add "Call mum"
peponi not-yet today ID        # move that inbox task onto today
peponi auth logout             # leave both; local files are kept
```

Switch later with `peponi auth local` or `peponi auth login`. Paid sign-in copies your website tasks onto this machine; it does not keep a live two-way sync. `peponi auth login --cloud` is the exception (tasks stay on peponi.to).

## 6. Uninstall

```bash
~/.config/omarchy/plugins/peponi.one-day/scripts/uninstall.sh
# or
omarchy plugin remove peponi.one-day --yes
```

After plugin code changes (`keepLoaded: true`), run `omarchy restart shell`.

Marketing guide on the site: [peponi.to/how-to#omarchy](https://peponi.to/how-to#omarchy)
