#!/usr/bin/env bash
# Area menu: Apps & services (scaffold)
set -euo pipefail

JB_DIR="${JB_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
# shellcheck disable=SC1091
source "$JB_DIR/lib/base.sh"

# Local helpers
apps_breadcrumb() {
  echo "You are here: Home ▸ Apps & services"
}

apps_show_readme() {
  local readme="$JB_DIR/areas/apps/README.md"
  if [[ -f "$readme" ]]; then
    if command -v less >/dev/null 2>&1; then
      less "$readme"
    else
      cat "$readme"
    fi
  else
    echo "README not found for Apps area: $readme"
  fi
}

# Action handlers used by bin/menu.sh -> run_area_script
menu_apps_list() {
  with_preview "List installed apps" echo "Not yet implemented"
}

menu_apps_add() {
  with_preview "Add a new app" echo "Not yet implemented"
}

menu_apps_control() {
  with_preview "Start/Stop/Restart an app" echo "Not yet implemented"
}

menu_apps_startup() {
  with_preview "Toggle app at startup" echo "Not yet implemented"
}

# Standalone area menu loop (optional)
apps_menu() {
  while true; do
    clear
    apps_breadcrumb
    echo ""
    echo "Apps & Services"
    echo "1) List installed apps"
    echo "2) Add a new app"
    echo "3) Start/Stop/Restart an app"
    echo "4) Turn an app on/off at startup"
    echo ""
    echo "0) What is this?"
    echo "P) Preview"
    echo "B) Back"
    echo "Q) Quit"
    read -rp "Choose an option: " choice
    case "$choice" in
      1) menu_apps_list ;;
      2) menu_apps_add ;;
      3) menu_apps_control ;;
      4) menu_apps_startup ;;
      0) apps_show_readme ;;
      [Pp]) echo "Preview shows planned actions before execution."; read -rp "Press Enter to continue..." _ ;;
      [Bb]) return 0 ;;
      [Qq]) exit 0 ;;
      *) echo "Invalid option"; sleep 1 ;;
    esac
  done
}

