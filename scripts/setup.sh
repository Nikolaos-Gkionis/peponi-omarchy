#!/usr/bin/env bash
# Post-install for peponi.one-day: install CLI, choose local vs paid, optional binds.
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

# --- Choose local machine vs paid peponi.to --------------------------------
# PEPONI_SETUP_MODE=local|cloud skips the prompt (useful for scripts).

auth_json() {
  "$BIN_DST" auth status --json 2>/dev/null || printf '{"authenticated":false,"mode":"none"}\n'
}

mode_from_status() {
  python3 -c 'import json,sys
try:
    d=json.load(sys.stdin)
except Exception:
    d={}
mode=d.get("mode") or ""
if not mode:
    mode = "cloud" if d.get("authenticated") else "none"
print(mode)
' <<<"$1"
}

email_from_status() {
  python3 -c 'import json,sys
try:
    d=json.load(sys.stdin)
except Exception:
    d={}
print(((d.get("user") or {}).get("email")) or "")
' <<<"$1"
}

choose_setup_mode() {
  local current="$1"
  if [[ -n "${PEPONI_SETUP_MODE:-}" ]]; then
    printf '%s\n' "$PEPONI_SETUP_MODE"
    return
  fi

  say ""
  if [[ "$current" == "local" ]]; then
    say "==> Already using local data on this machine"
    printf "Sign in with a paid peponi.to account instead? [y/N]: "
    read -r switch || true
    if [[ "${switch:-}" =~ ^[Yy]$ ]]; then
      printf 'cloud\n'
    else
      printf 'keep\n'
    fi
    return
  fi

  if [[ "$current" == "cloud" ]]; then
    say "==> Already signed in to peponi.to"
    printf "Switch to local-only on this machine? [y/N]: "
    read -r switch || true
    if [[ "${switch:-}" =~ ^[Yy]$ ]]; then
      printf 'local\n'
    else
      printf 'keep\n'
    fi
    return
  fi

  say "==> How do you want to use Peponi One Day?"
  local choice=""
  if command -v gum >/dev/null 2>&1; then
    # gum returns 1 if the user cancels — default to local so setup still finishes.
    choice="$(gum choose \
      "Use locally on this Omarchy machine (no account needed)" \
      "Sign in with a paid peponi.to account" || true)"
    case "$choice" in
      Sign\ in*) printf 'cloud\n' ;;
      *) printf 'local\n' ;;
    esac
    return
  fi

  say "    1) Use locally on this Omarchy machine (no account needed)"
  say "    2) Sign in with a paid peponi.to account"
  printf "Choice [1]: "
  read -r choice || true
  case "${choice:-1}" in
    2|cloud|login|paid) printf 'cloud\n' ;;
    *) printf 'local\n' ;;
  esac
}

status="$(auth_json)"
current_mode="$(mode_from_status "$status")"
current_email="$(email_from_status "$status")"
if [[ -n "$current_email" && "$current_mode" == "cloud" ]]; then
  say "    Current account: $current_email"
fi

picked="$(choose_setup_mode "$current_mode")"
case "$picked" in
  local)
    say ""
    say "==> Local mode (tasks stay on this machine)"
    "$BIN_DST" auth local
    ;;
  cloud)
    say ""
    say "==> Sign in to peponi.to (paid license, then copy tasks onto this machine)"
    if [[ -n "${PEPONI_BASE_URL:-}" ]]; then
      say "    PEPONI_BASE_URL=$PEPONI_BASE_URL"
    fi
    if "$BIN_DST" auth login; then
      :
    else
      say "    sign-in failed — continuing with local mode so setup can finish"
      say "    later: $BIN_DST auth login"
      "$BIN_DST" auth local
    fi
    ;;
  keep)
    say "    leaving current mode unchanged"
    ;;
  *)
    fail "unknown setup mode: $picked (use PEPONI_SETUP_MODE=local or cloud)"
    ;;
esac

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
