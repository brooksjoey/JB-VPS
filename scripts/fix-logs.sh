#!/usr/bin/env bash
# Ensure /var/log/jb-vps exists and is writable by user jb
set -euo pipefail

TARGET_DIR="/var/log/jb-vps"
FILES=("jb-vps.log" "audit.log" "error.log")
OWNER_USER="jb"
OWNER_GROUP="jb"

# Detect jb directory for sourcing base helpers if available
JB_DIR="${JB_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
if [[ -f "$JB_DIR/lib/base.sh" ]]; then
  # shellcheck disable=SC1091
  source "$JB_DIR/lib/base.sh"
fi

run_root() {
  if command -v as_root >/dev/null 2>&1; then
    as_root "$@"
  elif [[ $EUID -eq 0 ]]; then
    "$@"
  else
    if command -v sudo >/dev/null 2>&1; then
      sudo "$@"
    else
      echo "This script needs root to modify $TARGET_DIR" >&2
      exit 1
    fi
  fi
}

echo "Fixing log directory permissions at $TARGET_DIR"

run_root mkdir -p "$TARGET_DIR"
run_root touch "$TARGET_DIR/${FILES[0]}" "$TARGET_DIR/${FILES[1]}" "$TARGET_DIR/${FILES[2]}"

# Set directory ownership so user can create/append
run_root chown -R "$OWNER_USER:$OWNER_GROUP" "$TARGET_DIR"
run_root chmod 0755 "$TARGET_DIR"

# Set file permissions to 0644
for f in "${FILES[@]}"; do
  run_root chmod 0644 "$TARGET_DIR/$f"
done

echo "Log directory fixed: $TARGET_DIR"
ls -l "$TARGET_DIR" || true

