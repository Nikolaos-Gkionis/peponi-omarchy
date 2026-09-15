#!/usr/bin/env bash
# Opt-in Hyprland chords for Peponi One Day (does not touch Omarchy defaults otherwise).
set -euo pipefail

BINDINGS_LUA="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/bindings.lua"
MARKER="peponi.one-day"

say() { printf '%s\n' "$*"; }

say "==> Checking for SUPER+ALT collisions…"
if command -v omarchy >/dev/null 2>&1; then
  omarchy menu keybindings --print 2>/dev/null | grep -E 'SUPER \+ ALT \+ (O|Y|LEFT|RIGHT|SPACE|K|J)' || say "    (none obvious in printout)"
fi

mkdir -p "$(dirname "$BINDINGS_LUA")"
touch "$BINDINGS_LUA"

if grep -q "$MARKER" "$BINDINGS_LUA" 2>/dev/null; then
  say "==> $BINDINGS_LUA already mentions $MARKER — left unchanged"
  exit 0
fi

cat >> "$BINDINGS_LUA" <<'LUA'

-- Peponi One Day (desktop helper)
o.bind("SUPER + ALT + O", "Peponi one day", "omarchy-shell shell toggle peponi.one-day '{}'")
o.bind("SUPER + ALT + LEFT", "Peponi previous day", "omarchy-shell shell call peponi.one-day prevDay ''")
o.bind("SUPER + ALT + RIGHT", "Peponi next day", "omarchy-shell shell call peponi.one-day nextDay ''")
o.bind("SUPER + ALT + Y", "Peponi Not Yet", "omarchy-shell shell call peponi.one-day toggleDrawer ''")
o.bind("SUPER + ALT + SPACE", "Peponi tick task", "omarchy-shell shell call peponi.one-day toggleSelected ''")
o.bind("SUPER + ALT + K", "Peponi move task up", "omarchy-shell shell call peponi.one-day moveSelectedUp ''")
o.bind("SUPER + ALT + J", "Peponi move task down", "omarchy-shell shell call peponi.one-day moveSelectedDown ''")
LUA

say "==> Appended SUPER+ALT binds to $BINDINGS_LUA"
say "    Reload Hyprland config if they do not apply immediately"
