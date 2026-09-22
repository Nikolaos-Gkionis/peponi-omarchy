#!/usr/bin/env bash
# Remove Peponi Omarchy helper plugin + optional CLI. Does not delete instance accounts.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "$0" 2>/dev/null || echo "$0")")" && pwd)"
# shellcheck source=lib-cli.sh
source "$SCRIPT_DIR/lib-cli.sh"
PLUGIN_ID="peponi.one-day"
PLUGIN_DST="${XDG_CONFIG_HOME:-$HOME/.config}/omarchy/plugins/$PLUGIN_ID"
BIN_DST="$(peponi_cli_dest)"
CRED_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/peponi"
DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/peponi"

echo "==> Peponi Omarchy helper uninstall"

if command -v omarchy >/dev/null 2>&1; then
  omarchy plugin disable "$PLUGIN_ID" 2>/dev/null || true
  omarchy plugin remove "$PLUGIN_ID" --yes 2>/dev/null || true
fi

# If remove left a symlink / leftover dir
if [[ -L "$PLUGIN_DST" || -d "$PLUGIN_DST" ]]; then
  rm -rf "$PLUGIN_DST"
  echo "    removed $PLUGIN_DST"
fi

# Only delete the CLI when its bytes are still the ones this plugin installed.
# A different program named "peponi" in that path is left alone.
cli_removed=0
if peponi_remove_cli "$SCRIPT_DIR/../bin/peponi"; then
  cli_removed=1
fi

printf "Remove cloud credentials in %s? [y/N]: " "$CRED_DIR"
read -r wipe || true
if [[ "${wipe:-}" =~ ^[Yy]$ ]]; then
  # Do not run a foreign peponi that we refused to delete.
  if [[ "$cli_removed" -eq 1 ]]; then
    command -v peponi >/dev/null 2>&1 && peponi auth logout 2>/dev/null || true
  fi
  rm -rf "$CRED_DIR"
  echo "    credentials removed"
else
  echo "    left credentials in place"
fi

printf "Remove local task data in %s? [y/N]: " "$DATA_DIR"
read -r wipe_data || true
if [[ "${wipe_data:-}" =~ ^[Yy]$ ]]; then
  rm -rf "$DATA_DIR"
  echo "    local task data removed"
else
  echo "    left local task data in place"
fi

echo "    Note: SUPER+ALT lines in ~/.config/hypr/bindings.lua are not auto-removed."
echo "==> Done"
