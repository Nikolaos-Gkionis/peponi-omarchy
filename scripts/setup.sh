#!/usr/bin/env bash
# Post-install for peponi.one-day: install CLI, sign in, optional Hyprland binds.
# Run after: omarchy plugin add <url> --enable
# Or after: ./scripts/install.sh
set -euo pipefail

PROJECT="$(cd "$(dirname "$(readlink -f "$0" 2>/dev/null || echo "$0")")/.." && pwd)"
PLUGIN_ID="peponi.one-day"
BIN_DST="${XDG_BIN_HOME:-$HOME/.local/bin}/peponi"

say() { printf '%s\n' "$*"; }
fail() { printf 'setup.sh: %s\n' "$*" >&2; exit 1; }

[[ -x "$PROJECT/bin/peponi" ]] || fail "missing $PROJECT/bin/peponi"

mkdir -p "$(dirname "$BIN_DST")"
install -m 755 "$PROJECT/bin/peponi" "$BIN_DST"
say "==> CLI → $BIN_DST"

# Prefer PATH for later shells
case ":$PATH:" in
  *":$(dirname "$BIN_DST"):"*) ;;
  *) say "    Tip: ensure $(dirname "$BIN_DST") is on your PATH" ;;
esac

say ""
say "==> Sign in to peponi.to (paid accounts only)"
if [[ -n "${PEPONI_BASE_URL:-}" ]]; then
  say "    PEPONI_BASE_URL=$PEPONI_BASE_URL"
fi
if ! "$BIN_DST" auth login; then
  fail "sign-in failed — fix credentials / paid status, then re-run: $BIN_DST auth login"
fi

say ""
say "==> Auth status"
"$BIN_DST" auth status || true

# Bar placement is handled by `omarchy plugin add --enable` (gum choose).
# Offer a move if the user wants to change it later.
if command -v omarchy >/dev/null 2>&1; then
  say ""
  say "==> Bar toggle placement (optional change)"
  say "    Omarchy already prompted on --enable. Remap now? [left/center/right/skip]"
  printf "Section [skip]: "
  read -r section || true
  case "${section:-skip}" in
    left|center|centre|right)
      [[ "$section" == "centre" ]] && section=center
      omarchy bar put "$PLUGIN_ID" --section "$section" 2>/dev/null \
        || omarchy bar move "$PLUGIN_ID" --section "$section" 2>/dev/null \
        || say "    could not move bar widget — try: omarchy bar put $PLUGIN_ID --section $section"
      ;;
    *) say "    left bar placement unchanged" ;;
  esac
fi

say ""
printf "Install SUPER+ALT keybindings? [y/N]: "
read -r add_binds || true
if [[ "${add_binds:-}" =~ ^[Yy]$ ]]; then
  "$PROJECT/scripts/install-binding.sh"
else
  say "    skipped keybindings (run scripts/install-binding.sh later)"
fi

say ""
say "==> Done"
say "    Toggle: omarchy-shell shell toggle peponi.one-day '{}'"
say "    Or click the Peponi bar icon"
say "    After keepLoaded code edits: omarchy restart shell"
