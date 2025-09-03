#!/usr/bin/env bash
# Detect OS and install required packages
set -euo pipefail

OS_ID="unknown"
if [[ -f /etc/os-release ]]; then
  . /etc/os-release
  OS_ID="${ID:-unknown}"
fi

echo "[OS] Detected: $OS_ID"

case "$OS_ID" in
  ubuntu|debian)
    sudo apt update && sudo apt install -y curl git sudo
    ;;
  centos|fedora|rhel)
    sudo yum update -y && sudo yum install -y curl git sudo
    ;;
  *)
    echo "[WARN] Unsupported OS: $OS_ID. Manual setup may be required."
    ;;
esac
