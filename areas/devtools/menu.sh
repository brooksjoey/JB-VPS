#!/usr/bin/env bash
# Area menu: Developer Tools

set -euo pipefail

JB_DIR="${JB_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
# shellcheck disable=SC1091
source "$JB_DIR/lib/base.sh"

devtools_breadcrumb() {
  echo "You are here: Home ▸ Developer Tools"
}

devtools_show_readme() {
  local readme="$JB_DIR/areas/devtools/README.md"
  if [[ -f "$readme" ]]; then
    if command -v less >/dev/null 2>&1; then
      less "$readme"
    else
      cat "$readme"
    fi
  else
    echo "README not found for Developer Tools area: $readme"
  fi
}

# Check if git user is configured
check_git_user_config() {
  local git_user_name
  local git_user_email
  
  git_user_name=$(git config --global user.name 2>/dev/null || echo "")
  git_user_email=$(git config --global user.email 2>/dev/null || echo "")
  
  if [[ -z "$git_user_name" || -z "$git_user_email" ]]; then
    echo "Git user identity is not configured. Please configure with:"
    echo "git config --global user.name \"Your Name\""
    echo "git config --global user.email \"you@example.com\""
    echo ""
    read -p "Press Enter to continue..." _
    return 1
  fi
  
  return 0
}

# Action handlers used by bin/menu.sh -> run_area_script
menu_devtools_repo_snapshot() {
  # Check git configuration first
  check_git_user_config
  
  # Call the repo-snapshot script with preview option using with_preview helper
  with_preview "Snapshot & push repository" "$JB_DIR/scripts/repo-snapshot.sh"
}

# Additional devtools menu actions can be added here

# Optional standalone loop
devtools_menu() {
  while true; do
    clear
    devtools_breadcrumb
    echo ""
    echo "Developer Tools"
    echo "1) Syntax check scripts"
    echo "2) Run unit tests"
    echo "3) Lint project files"
    echo "4) Code quality analysis"
    echo "5) Snapshot & push repo"
    echo ""
    echo "0) What is this?"
    echo "P) Preview"
    echo "B) Back"
    echo "Q) Quit"
    read -rp "Choose an option: " choice
    case "$choice" in
      1) echo "Not yet implemented"; read -rp "Press Enter to continue..." _ ;;
      2) echo "Not yet implemented"; read -rp "Press Enter to continue..." _ ;;
      3) echo "Not yet implemented"; read -rp "Press Enter to continue..." _ ;;
      4) echo "Not yet implemented"; read -rp "Press Enter to continue..." _ ;;
      5) menu_devtools_repo_snapshot ;;
      0) devtools_show_readme ;;
      [Pp]) echo "Preview shows planned actions before execution."; read -rp "Press Enter to continue..." _ ;;
      [Bb]) return 0 ;;
      [Qq]) exit 0 ;;
      *) echo "Invalid option"; sleep 1 ;;
    esac
  done
}
