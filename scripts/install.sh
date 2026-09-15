#!/usr/bin/env bash
# Dev / local install — copy this checkout into Omarchy plugins.
# Production: omarchy plugin add <git-url> --enable
set -euo pipefail

PROJECT="$(cd "$(dirname "$(readlink -f "$0" 2>/dev/null || realpath "$0" 2>/dev/null || echo "$0")")/.." && pwd)"
PLUGIN_ID="peponi.one-day"
PLUGIN_DST="${XDG_CONFIG_HOME:-$HOME/.config}/omarchy/plugins/${PLUGIN_ID}"

say() { printf '%s\n' "$*"; }
fail() { printf 'install.sh: %s\n' "$*" >&2; exit 1; }

command -v omarchy >/dev/null 2>&1 || fail "omarchy CLI is not on PATH"
command -v rsync >/dev/null 2>&1 || fail "rsync is required"
[[ -f "$PROJECT/manifest.json" ]] || fail "manifest.json missing at repo root"
[[ -f "$PROJECT/qml/Overlay.qml" ]] || fail "qml/Overlay.qml missing"

omarchy plugin validate "$PROJECT" || fail "manifest validation failed"

mkdir -p "$(dirname "$PLUGIN_DST")"

# Omarchy rejects a plugin folder that is itself a symlink — use a real copy.
if [[ -e "$PLUGIN_DST" && -d "$PLUGIN_DST/.git" && ! -L "$PLUGIN_DST" ]]; then
  fail "$PLUGIN_DST is a git checkout from 'omarchy plugin add'; remove it first:
  omarchy plugin remove $PLUGIN_ID --yes"
fi

rm -rf "$PLUGIN_DST"
mkdir -p "$PLUGIN_DST"
rsync -a --delete \
  --exclude '.git' \
  --exclude '.gitignore' \
  "$PROJECT/" "$PLUGIN_DST/"
say "==> Copied $PROJECT → $PLUGIN_DST"

omarchy plugin validate "$PLUGIN_DST" || fail "installed copy failed validation"

BIN_DST="${XDG_BIN_HOME:-$HOME/.local/bin}/peponi"
mkdir -p "$(dirname "$BIN_DST")"
install -m 755 "$PROJECT/bin/peponi" "$BIN_DST"
say "==> CLI → $BIN_DST"

if command -v omarchy-shell >/dev/null 2>&1; then
  omarchy-shell shell rescanPlugins >/dev/null 2>&1 || true
fi

omarchy plugin enable "$PLUGIN_ID" 2>/dev/null || omarchy plugin enable "$PLUGIN_ID" --yes 2>/dev/null || true
say "==> Enabled $PLUGIN_ID (Omarchy may ask for bar left/center/right)"

say ""
say "Next: run setup (CLI + choose local or paid sign-in):"
say "  $PLUGIN_DST/scripts/setup.sh"
say "  # or from this checkout:"
say "  $PROJECT/scripts/setup.sh"
say "  # skip the prompt with: PEPONI_SETUP_MODE=local $PROJECT/scripts/setup.sh"
