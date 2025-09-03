#!/usr/bin/env bash
# Snapshot & Push Repository - Stages all changes, commits, and pushes to the remote repository
# Can be called by both CLI plugin and menu system

set -euo pipefail

JB_DIR="${JB_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
# shellcheck disable=SC1091
source "$JB_DIR/lib/base.sh"

# Default values
PREVIEW=false
COMMIT_MSG=""

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --preview)
      PREVIEW=true
      shift
      ;;
    --message)
      COMMIT_MSG="$2"
      shift 2
      ;;
    *)
      echo "Unknown option: $1"
      echo "Usage: repo-snapshot.sh [--preview] [--message \"commit message\"]"
      exit 1
      ;;
  esac
done

# Check if we're in a git repository
if [[ ! -d "$JB_DIR/.git" ]]; then
  log_error "Not in a git repository. Please ensure you're in the JB-VPS directory."
  exit 1
fi

# Get remote and branch information
REMOTE_INFO=$(git remote -v 2>/dev/null || echo "No remote configured")
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "No branch")

# If no commit message provided, use environment variable or default
if [[ -z "$COMMIT_MSG" ]]; then
  COMMIT_MSG="${GIT_COMMIT_MSG:-snapshot: $(date -Is)}"
fi

# Preview mode
if [[ "$PREVIEW" == "true" ]]; then
  echo "=== Repository Snapshot Preview ==="
  echo "Remote:"
  echo "$REMOTE_INFO"
  echo
  echo "Current branch: $CURRENT_BRANCH"
  echo
  echo "Would run:"
  echo "  git add -A"
  echo "  git commit -m \"$COMMIT_MSG\""
  echo "  git push"
  echo
  echo "Changes that would be committed:"
  git status --porcelain
  exit 0
fi

# Prompt for commit message if in interactive mode and no message provided
if [[ -t 0 && "$COMMIT_MSG" == "snapshot: $(date -Is)" ]]; then
  read -p "Commit message [default: \"$COMMIT_MSG\"]: " USER_MSG
  if [[ -n "$USER_MSG" ]]; then
    COMMIT_MSG="$USER_MSG"
  fi
fi

# Execute the commands
log_info "Adding all changes to the staging area"
git add -A

# Check if there are staged changes
if git diff --cached --quiet; then
  log_info "Nothing to commit. Already up-to-date."
  exit 0
fi

# Commit the changes
log_info "Committing changes with message: $COMMIT_MSG"
git commit -m "$COMMIT_MSG"

# Get the short commit hash
COMMIT_HASH=$(git rev-parse --short HEAD)

# Push to remote
log_info "Pushing changes to remote"
git push

# Success message
log_info "Successfully pushed changes to branch '$CURRENT_BRANCH' (commit: $COMMIT_HASH)"
