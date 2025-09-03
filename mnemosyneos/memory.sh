#!/usr/bin/env bash
# Mnemosyneos: Memory/Log/History System
set -euo pipefail

LOG_FILE="/var/log/jb-vps-mnemosyneos.log"

case "${1:-}" in
  view)
    if [[ -f "$LOG_FILE" ]]; then
      cat "$LOG_FILE"
    else
      echo "No mnemosyneos log found."
    fi
    ;;
  log)
    shift
    echo "[$(date)] $*" | tee -a "$LOG_FILE"
    ;;
  *)
    echo "Usage: $0 [view|log <message>]"
    ;;
esac
