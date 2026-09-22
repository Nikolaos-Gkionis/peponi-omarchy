# Shared by install.sh, setup.sh, and uninstall.sh.
# ~/.local/bin/peponi is a generic name. Another program may already use it.
# We record the exact bytes we install, and we only replace or delete a file
# whose bytes are still ours.

PEPONI_CLI_PLUGIN_ID="peponi.one-day"

peponi_cli_dest() {
  printf '%s\n' "${XDG_BIN_HOME:-$HOME/.local/bin}/peponi"
}

peponi_cli_stamp() {
  printf '%s\n' "${XDG_CONFIG_HOME:-$HOME/.config}/peponi/cli-install.json"
}

# 0 when $1 is a regular file this plugin may replace or remove.
# $2 is this checkout's bin/peponi (optional). Ownership means exact bytes:
# the stamp from our last install, this checkout's CLI, or a bin/peponi
# this repository shipped before stamps existed.
peponi_cli_is_ours() {
  local dest="$1" src="${2:-}"
  [[ -n "$dest" && -f "$dest" && ! -L "$dest" ]] || return 1
  python3 - "$dest" "$src" "$(peponi_cli_stamp)" "$PEPONI_CLI_PLUGIN_ID" <<'PY'
import hashlib, json, sys

dest, src, stamp_path, plugin_id = sys.argv[1:5]
# sha256 of bin/peponi blobs shipped before installs recorded a stamp.
# Matching one means this path is an older copy of this plugin.
KNOWN = {
    "1ac61626c2bcb20040fc92441a29072ce939564c32f7266d9b290e7f1ecce6eb",
    "c99fd9a54f0503637bd3a0e5d56533c196af9ff9197d4dec5e515dd792e95313",
    "000eb2f3291acf0c0f6868c622ad7990205e4cfc9c4f85ffb82bb76243d4fcc8",
    "b2d18720f1a8402deb43b1268d871efae25977083fb84f27dfe8fcadc3fd690c",
    "0b9ae97fc1e009b030dd1eb25472eaaf7a8a74fada60b000420e518d73904d78",
    "7d38448a7a365705f562e378bbaaf5193e13ba868d954b0cf7ed0fdca2526cd3",
}

def sha(path):
    digest = hashlib.sha256()
    with open(path, "rb") as handle:
        for chunk in iter(lambda: handle.read(1 << 20), b""):
            digest.update(chunk)
    return digest.hexdigest()

try:
    dest_sha = sha(dest)
except OSError:
    sys.exit(1)

if src:
    try:
        if sha(src) == dest_sha:
            sys.exit(0)
    except OSError:
        pass

try:
    with open(stamp_path) as handle:
        stamp = json.load(handle)
    if (
        stamp.get("plugin") == plugin_id
        and stamp.get("path") == dest
        and stamp.get("sha256") == dest_sha
    ):
        sys.exit(0)
except Exception:
    pass

sys.exit(0 if dest_sha in KNOWN else 1)
PY
}

peponi_cli_write_stamp() {
  local dest="$1" digest="$2"
  umask 077
  python3 - "$(peponi_cli_stamp)" "$dest" "$digest" "$PEPONI_CLI_PLUGIN_ID" <<'PY'
import json, os, sys
path, dest, digest, plugin_id = sys.argv[1:5]
os.makedirs(os.path.dirname(path), mode=0o700, exist_ok=True)
fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
with os.fdopen(fd, "w") as handle:
    json.dump(
        {"plugin": plugin_id, "path": dest, "sha256": digest},
        handle,
        indent=2,
    )
    handle.write("\n")
os.chmod(path, 0o600)
PY
}

# Copy $1 to ~/.local/bin/peponi. Return 1 and set PEPONI_CLI_ERROR when
# something else already owns that path.
peponi_install_cli() {
  local src="$1" dest links digest
  PEPONI_CLI_ERROR=""
  dest="$(peponi_cli_dest)"
  [[ -f "$src" && ! -L "$src" ]] || {
    PEPONI_CLI_ERROR="missing CLI source: $src"
    return 1
  }
  mkdir -p "$(dirname "$dest")"
  if [[ -e "$dest" || -L "$dest" ]]; then
    # A symlink: install(1) would follow it and overwrite the other file.
    if [[ -L "$dest" || ! -f "$dest" ]]; then
      PEPONI_CLI_ERROR="refusing to replace $dest — it is not a regular file owned by $PEPONI_CLI_PLUGIN_ID"
      return 1
    fi
    links="$(stat -c '%h' "$dest" 2>/dev/null || echo 0)"
    if [[ "$links" -gt 1 ]]; then
      PEPONI_CLI_ERROR="refusing to replace $dest — that file is hard-linked elsewhere"
      return 1
    fi
    if ! peponi_cli_is_ours "$dest" "$src"; then
      PEPONI_CLI_ERROR="refusing to replace $dest — another program owns that path. Move it aside, then run setup again."
      return 1
    fi
  fi
  install -m 755 "$src" "$dest"
  digest="$(python3 -c 'import hashlib,sys; print(hashlib.sha256(open(sys.argv[1],"rb").read()).hexdigest())' "$dest")"
  peponi_cli_write_stamp "$dest" "$digest"
}

# Delete ~/.local/bin/peponi only when its bytes are still this install.
# $1 is this checkout's bin/peponi, used when the stamp file is missing.
# Prints a short status line. Return 0 if removed, 1 if left in place.
peponi_remove_cli() {
  local src="${1:-}" dest
  dest="$(peponi_cli_dest)"
  if [[ ! -e "$dest" && ! -L "$dest" ]]; then
    return 1
  fi
  if peponi_cli_is_ours "$dest" "$src"; then
    rm -f -- "$dest"
    rm -f -- "$(peponi_cli_stamp)"
    printf '    removed %s\n' "$dest"
    return 0
  fi
  printf '    left %s in place (not installed by %s)\n' "$dest" "$PEPONI_CLI_PLUGIN_ID"
  return 1
}
