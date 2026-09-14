# Omarchy One-Day Plugin — Design Note

Research-only guidance for turning Peponi.to’s **Focus (1-day)** GUI into an Omarchy Quickshell shell experience. **Do not implement the full plugin in this note.**

Safe edit roots only: `~/.config/omarchy/`, `~/.config/hypr/`. **Never edit `/usr/share/omarchy/`.**

---

## Concept map (GUI → shell)

| Peponi GUI | Meaning | Omarchy / Quickshell pattern |
|------------|---------|------------------------------|
| Focus / 1-day view | One day’s tasks, full attention | `overlay` layer-shell surface (clipboard / reminders / menu style) |
| `←` / `→` day nav | Change selected date | In-overlay `Keys` when focused; optional global Hyprland → `shell call` |
| Not Yet bottom drawer (`y`) | Undated inbox slide-up | **In-overlay UI state**, not a second plugin / layer |
| Settings / notes drawers | Side panels | Defer or nest inside same overlay later |
| Bar badge / open | Quick access | Optional `bar-widget` (HEY pattern) |
| Live data / API | Todos for a date | Optional `service` singleton + Process/CLI or HTTP |

### Layer shells vs panels vs bar widgets (simple definitions)

- **Bar widget** — icon/label living in the top bar. Click opens a small popup. Best for status + shortcut open. Example: `37signals.hey`, `omarchy.clock`.
- **Overlay** — full-screen (or large) summoned UI with exclusive keyboard focus. Best for keyboard-first “TUI in the shell.” Examples: `omarchy.clipboard`, `omarchy.reminders`, `omarchy.menu`.
- **Panel (kind)** — persistent or summoned floating surface (e.g. `omarchy.osd`). Less ideal for a focused day planner than `overlay`.
- **Service** — headless singleton: one data engine per shell, shared by widgets. Example: HEY’s `Service.qml` + `hey watch`.
- **Layer shell** — Wayland surface type used by bar/overlays (`PanelWindow` + `WlrLayershell.*`). Not a plugin kind; it is how UI is drawn on Hyprland.

**Recommendation:** treat the one-day experience as an **overlay**, not a bar popup. A bar popup is too small for a day planner; clipboard/reminders are the right mental model.

---

## Recommended architecture

### Plugin identity

- **id:** `peponi.one-day` (or `nikolaos.peponi` if personal-only; avoid `omarchy.*` — reserved)
- **Install path:** `~/.config/omarchy/plugins/peponi.one-day/`
- **kinds (v1):** `["overlay"]` with `keepLoaded: true`
- **kinds (v1.5):** add `"service"` for shared day model / fetch
- **kinds (v2 optional):** add `"bar-widget"` for today count + click-to-summon (clone HEY’s service + widget split)

### File layout (implementer checklist)

```
~/.config/omarchy/plugins/peponi.one-day/
  manifest.json          # schemaVersion 1, id, kinds, entryPoints
  Overlay.qml            # entryPoints.overlay — one-day UI + Keys + drawer
  Service.qml            # optional entryPoints.service — date state + data
  Model.js               # pure helpers: filter tasks, shift date, etc.
  DayView.qml            # task list for selected date
  BottomDrawer.qml       # Not Yet UI (child of Overlay, not separate plugin)
  README.md              # keybinds, enable steps, data backend notes
```

Optional later: `BarWidget.qml` + `barWidget` block in manifest (like HEY’s `Panel.qml`).

### Manifest sketch

```json
{
  "schemaVersion": 1,
  "id": "peponi.one-day",
  "name": "Peponi One Day",
  "version": "0.1.0",
  "author": "nikolaos",
  "description": "Focused one-day task view with keyboard navigation",
  "kinds": ["overlay"],
  "keepLoaded": true,
  "entryPoints": {
    "overlay": "Overlay.qml"
  }
}
```

With service + bar later:

```json
"kinds": ["service", "overlay", "bar-widget"],
"entryPoints": {
  "service": "Service.qml",
  "overlay": "Overlay.qml",
  "barWidget": "BarWidget.qml"
}
```

### Enable / shell.json

Third-party plugins are enabled by appearing in `~/.config/omarchy/shell.json`:

- Overlay/service: entry in top-level `"plugins": [ { "id": "peponi.one-day", ...settings } ]`
- Bar widget (if any): also place in `bar.layout.<section>`

Commands:

```bash
omarchy plugin validate ~/.config/omarchy/plugins/peponi.one-day
omarchy-shell shell rescanPlugins
omarchy plugin enable peponi.one-day --yes   # or enable via IPC after validate
omarchy-shell shell toggle peponi.one-day '{}'
```

Hot reload: saving under `~/.config/omarchy/plugins/` reloads most plugin code. **`keepLoaded: true` instances are not replaced** — overlay/service code changes may need `omarchy restart shell`.

---

## Keybinding scheme

Split into two layers (this is the main gotcha for learners):

### A. Global — Hyprland (`~/.config/hypr/bindings.lua`)

These work even when the overlay is closed. Always use modifiers so bare arrows are not stolen desktop-wide.

Check collisions first: `omarchy menu keybindings --print`. Unbind with `hl.unbind(...)` before rebinding.

Suggested (adjust if taken):

| Chord | Action | Command |
|-------|--------|---------|
| `SUPER + CTRL + O` | Open / close one-day view | `omarchy-shell shell toggle peponi.one-day '{}'` |
| `SUPER + CTRL + LEFT` | Previous day (IPC) | `omarchy-shell shell call peponi.one-day prevDay` |
| `SUPER + CTRL + RIGHT` | Next day (IPC) | `omarchy-shell shell call peponi.one-day nextDay` |
| `SUPER + CTRL + Y` | Toggle Not Yet drawer | `omarchy-shell shell call peponi.one-day toggleDrawer` |

Example Lua:

```lua
o.bind("SUPER + CTRL + O", "Peponi one day", "omarchy-shell shell toggle peponi.one-day '{}'")
o.bind("SUPER + CTRL + LEFT", "Peponi previous day", "omarchy-shell shell call peponi.one-day prevDay")
o.bind("SUPER + CTRL + RIGHT", "Peponi next day", "omarchy-shell shell call peponi.one-day nextDay")
o.bind("SUPER + CTRL + Y", "Peponi Not Yet", "omarchy-shell shell call peponi.one-day toggleDrawer")
```

IPC methods must exist on the overlay (or its `IpcHandler` / shell `call` surface), mirroring HEY’s `open` / `close` / `toggle` and clipboard’s `open(payloadJson)`.

### B. In-overlay — QML `Keys` (only while overlay has focus)

Mirror Peponi’s GUI shortcuts when `WlrKeyboardFocus.Exclusive` is held:

| Key | Action |
|-----|--------|
| `←` / `→` | Previous / next day |
| `y` | Toggle bottom drawer (Not Yet) |
| `t` | Jump to today |
| `n` | Focus new-task field |
| `↑` / `↓` | Move among tasks (and in drawer when open) |
| `Esc` | Close drawer if open; else dismiss overlay |
| `?` | Shortcuts help |

**Do not** put bare `←`/`→` only in Hyprland — that fights window focus and every other app. Bare arrows belong in-plugin.

### Reference: how Omarchy does this today

- Global toggle overlays: `omarchy-shell shell toggle omarchy.clipboard` (see `/usr/share/omarchy/default/hypr/bindings/clipboard.lua`, utilities.lua).
- In-panel keys: HEY `Panel.qml` (`Keys.onEscapePressed`, arrows for accounts); reminders/clipboard `keyCatcher.forceActiveFocus()` on open.

---

## Overlay implementation notes (for the sibling agent)

Follow `omarchy.clipboard` / `omarchy.reminders`:

1. Root `Item` with `open(payloadJson)` / `close()` / `toggle()` / `dismiss()`.
2. `PanelWindow` with:
   - `WlrLayershell.namespace: "peponi-one-day"` (unique)
   - `WlrLayershell.layer: WlrLayer.Overlay`
   - `WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive`
   - `exclusionMode: ExclusionMode.Ignore`
3. On open: `Qt.callLater(() => keyCatcher.forceActiveFocus())`.
4. Bottom drawer = anchored child `Rectangle`/`Item` with height animation; `drawerOpen` bool — **same window**, not a second layer-shell.
5. Day state: `selectedDate` property; `prevDay` / `nextDay` mutate it and reload tasks.
6. Data: start with a stub/`Process` calling a future `peponi` CLI or Rails JSON endpoint; keep parsing in `Model.js`.

### Optional Hyprland layer rule (user config only)

Stock rules live in `/usr/share/omarchy/default/hypr/apps/omarchy-shell.lua` (read-only). To skip compositor fade on your namespace, add in `~/.config/hypr/` (e.g. hyprland.lua or a required file):

```lua
hl.layer_rule({ match = { namespace = "peponi-one-day" }, no_anim = true, animation = "none" })
```

Then `hyprctl reload` and `hyprctl configerrors`.

---

## Validate

```bash
omarchy plugin validate ~/.config/omarchy/plugins/peponi.one-day
```

Checks: `schemaVersion == 1`, required fields, safe relative entry points that exist, no `omarchy.*` id, no symlinks, kinds/entryPoints consistency. Exit 0 before enable.

Manual smoke:

```bash
omarchy-shell shell ping
omarchy-shell shell listPlugins | jq '.[] | select(.id|test("peponi"))'
omarchy-shell shell toggle peponi.one-day '{}'
omarchy-shell shell call peponi.one-day prevDay
omarchy-shell shell hide peponi.one-day
```

---

## Risks / gotchas

1. **`keepLoaded: true` + hot reload** — code edits may not apply until `omarchy restart shell`.
2. **Focus grab** — without `WlrKeyboardFocus.Exclusive` + `forceActiveFocus`, in-overlay keys feel broken.
3. **Global vs local keys** — bare arrows only inside overlay; Hyprland chords for summon/nav when closed or for muscle-memory globals.
4. **Drawer as second layer-shell** — avoid; focus and z-order become messy. Keep Not Yet inside the overlay.
5. **Third-party enable ⇔ present in shell.json** — missing from `plugins[]` / bar layout means disabled.
6. **Facades / security** — plugins run unsandboxed inside `omarchy-shell`; only talk to trusted local CLI/API; no secrets in QML strings committed to git.
7. **Never edit `/usr/share/omarchy/`** — updates wipe it; clone/customize under `~/.config/omarchy/plugins/`.
8. **Namespace collisions** — pick a unique `WlrLayershell.namespace`; add user layer rules if animation looks wrong.
9. **Multi-monitor** — one overlay summon is shell-wide; bar widgets are per-monitor (if added later, share one `service`).
10. **Data backend** — Rails PWA is not automatically available in Quickshell; plan CLI/API auth separately from UI chrome.

---

## Primary references (read-only)

- Skill: `~/.claude/skills/omarchy/SKILL.md`, `plugins.md`, `hyprland.md`
- Host docs: `/usr/share/omarchy/shell/README.md`, `plugins/README.md`
- Overlay patterns: `shell/plugins/clipboard/`, `shell/plugins/reminders/`
- Bar + service: `~/.config/omarchy/plugins/37signals.hey/`
- User shell config: `~/.config/omarchy/shell.json`
- GUI shortcuts: Peponi `README.md` + `app/javascript/controllers/keyboard_shortcuts_controller.js`
