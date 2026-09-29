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
    "94d15c5d4e81bd517ce37c6af6e89f955a5cd3aecdc4ff234455d51852995aa9",
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
  # A planted symlink at the stamp path must not be opened and truncated.
  # Write a new private file in the same directory, then rename it into place.
  # rename replaces a symlink; it does not follow it.
  python3 - "$(peponi_cli_stamp)" "$dest" "$digest" "$PEPONI_CLI_PLUGIN_ID" <<'PY'
import json, os, secrets, stat, sys

path, dest, digest, plugin_id = sys.argv[1:5]
parent = os.path.dirname(path)

def fail(message):
    print("peponi: " + message, file=sys.stderr)
    sys.exit(1)

def real_dir(directory):
    info = os.lstat(directory)
    if stat.S_ISLNK(info.st_mode) or not stat.S_ISDIR(info.st_mode):
        fail("refusing to write the install stamp through " + directory)

if os.path.lexists(parent):
    real_dir(parent)
else:
    os.makedirs(parent, mode=0o700, exist_ok=True)
    real_dir(parent)

tmp = os.path.join(parent, ".cli-install." + secrets.token_hex(8))
flags = os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW
fd = os.open(tmp, flags, 0o600)
try:
    with os.fdopen(fd, "w") as handle:
        json.dump(
            {"plugin": plugin_id, "path": dest, "sha256": digest},
            handle,
            indent=2,
        )
        handle.write("\n")
        handle.flush()
        os.fsync(handle.fileno())
    os.replace(tmp, path)
except Exception:
    try:
        os.unlink(tmp)
    except OSError:
        pass
    raise
PY
}

# Where this plugin is copied for a local install.
peponi_plugin_dst() {
  printf '%s\n' "${XDG_CONFIG_HOME:-$HOME/.config}/omarchy/plugins/${PEPONI_CLI_PLUGIN_ID}"
}

# Record of the files this installer wrote. Kept outside the plugin folder
# so a copied manifest inside that folder cannot pretend to be our record.
# Each files[] entry must be a relative path inside that folder. The tool
# refuses ".." and absolute paths, and it does not follow symlinks to delete.
peponi_plugin_stamp() {
  printf '%s\n' "${XDG_CONFIG_HOME:-$HOME/.config}/peponi/plugin-install.json"
}

# Print missing, ours, or foreign.
# "ours" here only means the folder looks like this plugin: a real directory
# whose manifest.json is a regular file and says our id. That is not enough
# to delete unrelated files. Deleting uses the install record as well.
peponi_plugin_state() {
  python3 - "$1" "$PEPONI_CLI_PLUGIN_ID" <<'PY'
import json, os, stat, sys

path, plugin_id = sys.argv[1], sys.argv[2]
if not os.path.lexists(path):
    print("missing")
    raise SystemExit(0)
info = os.lstat(path)
if stat.S_ISLNK(info.st_mode) or not stat.S_ISDIR(info.st_mode):
    print("foreign")
    raise SystemExit(0)
manifest = os.path.join(path, "manifest.json")
if not os.path.lexists(manifest):
    print("foreign")
    raise SystemExit(0)
minfo = os.lstat(manifest)
if stat.S_ISLNK(minfo.st_mode) or not stat.S_ISREG(minfo.st_mode):
    print("foreign")
    raise SystemExit(0)
try:
    fd = os.open(manifest, os.O_RDONLY | os.O_NOFOLLOW)
except OSError:
    print("foreign")
    raise SystemExit(0)
with os.fdopen(fd, "r") as handle:
    try:
        data = json.load(handle)
    except Exception:
        print("foreign")
        raise SystemExit(0)
print("ours" if data.get("id") == plugin_id else "foreign")
PY
}

# Delete a real file or directory without following symlinks.
# A symlink is unlinked itself. It is never treated as the thing it points at.
peponi_remove_tree() {
  python3 - "$1" <<'PY'
import os, stat, sys

def remove(path, top):
    info = os.lstat(path)
    if stat.S_ISLNK(info.st_mode):
        if top:
            print("peponi: refusing to remove symlink " + path, file=sys.stderr)
            sys.exit(1)
        os.unlink(path)
        return
    if stat.S_ISDIR(info.st_mode):
        for name in os.listdir(path):
            remove(os.path.join(path, name), False)
        os.rmdir(path)
        return
    os.unlink(path)

remove(sys.argv[1], True)
PY
}

# upgrade SRC DST — copy our files, leave unknown files, drop only files we
# recorded last time that this checkout no longer ships.
# plan DST — print gone, skip, files, or whole.
#   skip: do not call omarchy plugin remove
#   files: delete only recorded files; unknown files stay
#   whole: the folder contains nothing except files we recorded
# remove-recorded DST — delete recorded files and leave everything else.
peponi_plugin_tool() {
  local cmd="$1"
  shift
  python3 - "$cmd" "$PEPONI_CLI_PLUGIN_ID" "$(peponi_plugin_stamp)" "$@" <<'PY'
import json, os, secrets, stat, sys

cmd, plugin_id, stamp_path = sys.argv[1:4]
args = sys.argv[4:]
src = ""
dst = ""
if cmd == "upgrade":
    src, dst = args[0], args[1]
elif cmd in ("plan", "remove-recorded"):
    dst = args[0]

def fail(message):
    print("peponi: " + message, file=sys.stderr)
    sys.exit(1)

def read_manifest(directory):
    # Same rule as peponi_plugin_state: never follow a symlink.
    if not os.path.lexists(directory):
        return None
    info = os.lstat(directory)
    if stat.S_ISLNK(info.st_mode) or not stat.S_ISDIR(info.st_mode):
        return None
    manifest = os.path.join(directory, "manifest.json")
    if not os.path.lexists(manifest):
        return None
    minfo = os.lstat(manifest)
    if stat.S_ISLNK(minfo.st_mode) or not stat.S_ISREG(minfo.st_mode):
        return None
    try:
        fd = os.open(manifest, os.O_RDONLY | os.O_NOFOLLOW)
    except OSError:
        return None
    with os.fdopen(fd, "r") as handle:
        try:
            data = json.load(handle)
        except Exception:
            return None
    if data.get("id") != plugin_id:
        return None
    return data

def read_stamp():
    if not os.path.lexists(stamp_path):
        return None
    info = os.lstat(stamp_path)
    if stat.S_ISLNK(info.st_mode) or not stat.S_ISREG(info.st_mode):
        return None
    try:
        fd = os.open(stamp_path, os.O_RDONLY | os.O_NOFOLLOW)
    except OSError:
        return None
    with os.fdopen(fd, "r") as handle:
        try:
            data = json.load(handle)
        except Exception:
            return None
    if data.get("plugin") != plugin_id or data.get("path") != dst:
        return None
    files = data.get("files")
    if not isinstance(files, list):
        return None
    # One illegal path means the whole record is untrusted. Do not delete
    # any of its entries, including the ones that look normal.
    if any(safe_parts(item) is None for item in files):
        print(
            "peponi: install record has a path that leaves the plugin directory; ignoring it",
            file=sys.stderr,
        )
        return None
    return data

def safe_parts(rel):
    """A recorded path is only a list of names inside the plugin directory.

    Allowed: qml/Overlay.qml
    Refused: ../secret, /etc/passwd, qml/../../secret

    The text must already be in normal form. We do not "clean it up",
    because cleaning can hide a jump out of the directory.
    """
    if not isinstance(rel, str) or rel == "" or "\0" in rel:
        return None
    if os.path.isabs(rel) or os.path.normpath(rel) != rel:
        return None
    parts = rel.split("/")
    if any(part in ("", ".", "..") for part in parts):
        return None
    return parts

def open_parent(parts):
    """Open the directory that holds the last name, without following links.

    Start at the plugin directory. Each step uses O_NOFOLLOW, so a parent
    that was replaced by a symlink is a stop, not a doorway to another folder.
    Returns (directory_fd, final_name). The caller closes the fd.
    """
    try:
        dirfd = os.open(dst, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
    except OSError:
        return None
    try:
        for part in parts[:-1]:
            try:
                child = os.open(
                    part,
                    os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW,
                    dir_fd=dirfd,
                )
            except OSError:
                os.close(dirfd)
                return None
            os.close(dirfd)
            dirfd = child
    except Exception:
        os.close(dirfd)
        raise
    return dirfd, parts[-1]

def write_stamp(files):
    if any(safe_parts(rel) is None for rel in files):
        fail("refusing to record a path that leaves the plugin directory")
    parent = os.path.dirname(stamp_path)
    if os.path.lexists(parent):
        info = os.lstat(parent)
        if stat.S_ISLNK(info.st_mode) or not stat.S_ISDIR(info.st_mode):
            fail("refusing to write the plugin record through " + parent)
    else:
        os.makedirs(parent, mode=0o700, exist_ok=True)
    payload = {"plugin": plugin_id, "path": dst, "files": files}
    tmp = os.path.join(parent, ".plugin-install." + secrets.token_hex(8))
    flags = os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW
    fd = os.open(tmp, flags, 0o600)
    try:
        with os.fdopen(fd, "w") as handle:
            json.dump(payload, handle, indent=2)
            handle.write("\n")
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(tmp, stamp_path)
    except Exception:
        try:
            os.unlink(tmp)
        except OSError:
            pass
        raise

def source_files(root):
    found = []
    for dirpath, dirnames, filenames in os.walk(root, followlinks=False):
        kept = []
        for name in dirnames:
            path = os.path.join(dirpath, name)
            # Do not walk a symlinked directory or a nested git checkout.
            if name == ".git" or os.path.islink(path):
                continue
            kept.append(name)
        dirnames[:] = kept
        for name in filenames:
            if name == ".gitignore":
                continue
            path = os.path.join(dirpath, name)
            rel = os.path.relpath(path, root).replace(os.sep, "/")
            found.append(rel)
    return sorted(found)

def dest_files(root):
    found = []
    for dirpath, dirnames, filenames in os.walk(root, followlinks=False):
        kept = []
        for name in dirnames:
            path = os.path.join(dirpath, name)
            rel = os.path.relpath(path, root).replace(os.sep, "/")
            if os.path.islink(path) or name == ".git":
                found.append(rel)
                continue
            kept.append(name)
        dirnames[:] = kept
        for name in filenames:
            path = os.path.join(dirpath, name)
            rel = os.path.relpath(path, root).replace(os.sep, "/")
            found.append(rel)
    return found

def clear_stamp():
    # Unlink the record itself. Do not follow it if it is a symlink.
    if not os.path.lexists(stamp_path):
        return
    info = os.lstat(stamp_path)
    if stat.S_ISLNK(info.st_mode) or stat.S_ISREG(info.st_mode):
        os.unlink(stamp_path)

def unlink_recorded(rel):
    # Only a normal relative path. A symlink is removed as a symlink.
    # Parents are opened with O_NOFOLLOW, so the name cannot escape dst.
    parts = safe_parts(rel)
    if parts is None:
        return False
    opened = open_parent(parts)
    if opened is None:
        return False
    dirfd, name = opened
    try:
        try:
            info = os.lstat(name, dir_fd=dirfd)
        except OSError:
            return False
        if stat.S_ISDIR(info.st_mode) and not stat.S_ISLNK(info.st_mode):
            return False
        os.unlink(name, dir_fd=dirfd)
        return True
    finally:
        os.close(dirfd)

def rmdir_if_empty(rel):
    # Same walk as unlink: do not rmdir through a symlink parent.
    parts = safe_parts(rel)
    if parts is None:
        return
    opened = open_parent(parts)
    if opened is None:
        return
    dirfd, name = opened
    try:
        try:
            info = os.lstat(name, dir_fd=dirfd)
        except OSError:
            return
        if stat.S_ISLNK(info.st_mode) or not stat.S_ISDIR(info.st_mode):
            return
        try:
            sub = os.open(
                name,
                os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW,
                dir_fd=dirfd,
            )
        except OSError:
            return
        try:
            if os.listdir(sub):
                return
        finally:
            os.close(sub)
        os.rmdir(name, dir_fd=dirfd)
    finally:
        os.close(dirfd)

def prune_empty_parents(removed):
    parents = []
    for rel in removed:
        parent = os.path.dirname(rel)
        while parent:
            parents.append(parent)
            parent = os.path.dirname(parent)
    for rel in sorted(set(parents), key=lambda item: item.count("/"), reverse=True):
        rmdir_if_empty(rel)

if cmd == "upgrade":
    if read_manifest(dst) is None:
        fail("refusing to update " + dst + " — it is not a " + plugin_id + " install")
    shipped = source_files(src)
    previous = read_stamp()
    old = set(previous["files"]) if previous else set()
    removed = []
    for rel in sorted(old - set(shipped), key=lambda item: item.count("/"), reverse=True):
        if unlink_recorded(rel):
            removed.append(rel)
    prune_empty_parents(removed)
    write_stamp(shipped)
    raise SystemExit(0)

if cmd == "plan":
    if not os.path.lexists(dst):
        print("gone")
        raise SystemExit(0)
    if read_manifest(dst) is None or read_stamp() is None:
        print("skip")
        raise SystemExit(0)
    recorded = set(read_stamp()["files"])
    extras = [rel for rel in dest_files(dst) if rel not in recorded]
    print("files" if extras else "whole")
    raise SystemExit(0)

if cmd == "remove-recorded":
    previous = read_stamp()
    if read_manifest(dst) is None or previous is None:
        fail("refusing to remove files from " + dst)
    removed = []
    for rel in previous["files"]:
        if unlink_recorded(rel):
            removed.append(rel)
    prune_empty_parents(removed)
    clear_stamp()
    raise SystemExit(0)

if cmd == "clear-stamp":
    clear_stamp()
    raise SystemExit(0)

fail("unknown plugin tool: " + cmd)
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
