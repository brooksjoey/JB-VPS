#!/usr/bin/env bash
# Area menu: Users & access (scaffold)
set -euo pipefail

JB_DIR="${JB_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
# shellcheck disable=SC1091
source "$JB_DIR/lib/base.sh"

users_breadcrumb() {
  echo "You are here: Home ▸ Users & access"
}

users_show_readme() {
  local readme="$JB_DIR/areas/users/README.md"
  if [[ -f "$readme" ]]; then
    if command -v less >/dev/null 2>&1; then
      less "$readme"
    else
      cat "$readme"
    fi
  else
    echo "README not found for Users area: $readme"
  fi
}

# Action handlers used by bin/menu.sh -> run_area_script
menu_users_add() {
  with_preview "Add a user" echo "Not yet implemented"
}

menu_users_admin() {
  with_preview "Give or remove admin rights" echo "Not yet implemented"
}

menu_users_ssh() {
  with_preview "Set up SSH keys" echo "Not yet implemented"
}

menu_users_password() {
  with_preview "Turn password login on/off" echo "Not yet implemented"
}

# Optional standalone loop
users_menu() {
  while true; do
    clear
    users_breadcrumb
    echo ""
    echo "Users & Access"
    echo "1) Add a user"
    echo "2) Give or remove admin rights"
    echo "3) Set up SSH keys"
    echo "4) Turn password login on/off"
    echo ""
    echo "0) What is this?"
    echo "P) Preview"
    echo "B) Back"
    echo "Q) Quit"
    read -rp "Choose an option: " choice
    case "$choice" in
      1) menu_users_add ;;
      2) menu_users_admin ;;
      3) menu_users_ssh ;;
      4) menu_users_password ;;
      0) users_show_readme ;;
      [Pp]) echo "Preview shows planned actions before execution."; read -rp "Press Enter to continue..." _ ;;
      [Bb]) return 0 ;;
      [Qq]) exit 0 ;;
      *) echo "Invalid option"; sleep 1 ;;
    esac
  done
}

