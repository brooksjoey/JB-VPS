#!/usr/bin/env bash
# Developer Tools Plugin - provides development and repository management commands

set -euo pipefail

JB_DIR="${JB_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
# shellcheck disable=SC1091
source "$JB_DIR/lib/base.sh"

# Command: repo:snapshot
# Description: Snapshot and push repository (stage all changes, commit, push)
# Usage: jb repo:snapshot [--preview] [--message "commit message"]
repo_snapshot_cmd() {
  local preview=false
  local message=""

  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --preview)
        preview=true
        shift
        ;;
      --message)
        message="$2"
        shift 2
        ;;
      *)
        log_error "Unknown option: $1"
        echo "Usage: jb repo:snapshot [--preview] [--message \"commit message\"]"
        return 1
        ;;
    esac
  done

  # Build command arguments
  local args=()
  
  if [[ "$preview" == "true" ]]; then
    args+=(--preview)
  fi
  
  if [[ -n "$message" ]]; then
    args+=(--message "$message")
  fi

  # Execute the repo-snapshot script
  "$JB_DIR/scripts/repo-snapshot.sh" "${args[@]}"
}

# Register commands with the system
jb_register "repo:snapshot" "repo_snapshot_cmd" "Snapshot and push repository changes" "devtools"

# Additional registrations for other devtools commands can be added here
