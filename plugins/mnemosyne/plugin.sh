#!/usr/bin/env bash
# Mnemosyneos plugin: register simple view/log commands
set -euo pipefail

# Expect JB_DIR from bin/jb
MNEMO_SH="${JB_DIR}/mnemosyneos/memory.sh"

mnemo_view() {
  "$MNEMO_SH" view
}

mnemo_log() {
  if [[ $# -eq 0 ]]; then
    echo "Usage: jb mnemo:log <message>" >&2
    return 1
  fi
  "$MNEMO_SH" log "$*"
}

# Register commands
jb_register "mnemo:view" mnemo_view "View Mnemosyneos log" "system"
jb_register "mnemo:log" mnemo_log "Append a line to Mnemosyneos log" "system"

