#!/usr/bin/env bash
# Create admin user and set up environment
set -euo pipefail

USERNAME="jb"
read -rp "Enter admin username [jb]: " input
USERNAME="${input:-jb}"

if id "$USERNAME" &>/dev/null; then
  echo "[User] $USERNAME exists. Skipping creation."
else
  sudo useradd -m -s /bin/bash "$USERNAME"
  echo "Set password for $USERNAME:"
  sudo passwd "$USERNAME"
  sudo usermod -aG sudo "$USERNAME"
  echo "[User] $USERNAME created and added to sudoers."
fi
