#!/usr/bin/env bash
# JB-VPS :: bootstrap_first_run.sh
# Purpose: On a fresh VPS (after cloning JB-VPS), create your daily user,
# grant sudo, set password, then run vps-init as that user with your modules.
# Safe to re-run; it will skip what already exists.
set -euo pipefail

# --- pretty logging ---
C(){ printf "\033[36m%s\033[0m" "$*"; }
G(){ printf "\033[32m%s\033[0m" "$*"; }
Y(){ printf "\033[33m%s\033[0m" "$*"; }
R(){ printf "\033[31m%s\033[0m" "$*"; }
log(){ C "[JB] "; printf "%s\n" "$*"; }
warn(){ Y "[!] $*\n"; }
die(){ R "[x] $*\n" >&2; exit 1; }

# --- find repo root (works no matter where you run this from) ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
JB_DIR="$(cd "$SCRIPT_DIR/.." && pwd -P)"
cd "$JB_DIR" || die "cannot cd to repo root"

# --- require root (so we can create users, write sudoers, etc.) ---
if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
  die "Run as root: sudo bash scripts/bootstrap_first_run.sh"
fi

export DEBIAN_FRONTEND=noninteractive

# --- ask for username/password (default: jb) ---
read -rp "New admin username [jb]: " USERNAME
USERNAME="${USERNAME:-jb}"

# If user already exists, we can optionally skip password prompt
if id -u "$USERNAME" >/dev/null 2>&1; then
  log "User '$USERNAME' exists; will ensure sudo + run init."
  SKIP_PASS=1
else
  SKIP_PASS=0
fi

if [[ "$SKIP_PASS" -eq 0 ]]; then
  while :; do
    read -srp "Set password for ${USERNAME}: " PW1; echo
    read -srp "Confirm password: " PW2; echo
    [[ "$PW1" == "$PW2" ]] && break || echo "Passwords do not match. Try again."
  done
fi

# --- ensure base packages for clone/init flow (idempotent) ---
apt-get update -y
apt-get install -y git curl ca-certificates

# --- create user if needed, set password, grant sudo (NOPASSWD) ---
if ! id -u "$USERNAME" >/dev/null 2>&1; then
  adduser --disabled-password --gecos "" "$USERNAME"
fi
if [[ "$SKIP_PASS" -eq 0 ]]; then
  echo "${USERNAME}:${PW1}" | chpasswd
fi

# Give sudo (NOPASSWD) via a drop-in; safe to re-run
echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/$USERNAME"
chmod 440 "/etc/sudoers.d/$USERNAME"
usermod -aG sudo "$USERNAME"

# --- set repo ownership to that user (so Textastic/SFTP editing is comfy) ---
chown -R "$USERNAME":"$USERNAME" "$JB_DIR"

# --- make sure init + modules are executable (no-op if already) ---
chmod +x "$JB_DIR/scripts/vps-init.sh" 2>/dev/null || true
chmod +x "$JB_DIR/scripts/init.d/"*.bash 2>/dev/null || true

# --- run init AS THE NEW USER ---
# This installs: packages, jb() shell function, tailscale, nginx, dashboard (if present), safe security.
log "Running vps-init.sh as $USERNAME ..."
runuser -l "$USERNAME" -c "
  set -euo pipefail
  cd '$JB_DIR'
  sudo bash scripts/vps-init.sh \
    --run packages,shell,tailscale,nginx,dashboard,security-sane \
    --user '$USERNAME' \
    --with-webhost
"

echo
echo "All done."
echo "Log in as ${USERNAME} (or 'su - ${USERNAME}') then use:"
echo "  jb         # cds to /home/JB-VPS"
echo "  jb help    # shows your menu"