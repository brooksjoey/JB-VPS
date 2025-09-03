#!/usr/bin/env bash
# Area menu: Websites & domains (scaffold)
set -euo pipefail

JB_DIR="${JB_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
# shellcheck disable=SC1091
source "$JB_DIR/lib/base.sh"

web_breadcrumb() {
  echo "You are here: Home ▸ Websites & domains"
}

web_show_readme() {
  local readme="$JB_DIR/areas/web/README.md"
  if [[ -f "$readme" ]]; then
    if command -v less >/dev/null 2>&1; then
      less "$readme"
    else
      cat "$readme"
    fi
  else
    echo "README not found for Web area: $readme"
  fi
}

# Action handlers used by bin/menu.sh -> run_area_script
menu_web_domain() {
  with_preview "Point a domain to this server" echo "Not yet implemented"
}

menu_web_simple() {
  with_preview "Host a simple website" echo "Not yet implemented"
}

menu_web_manage() {
  with_preview "Add or remove a site" echo "Not yet implemented"
}

menu_web_locations() {
  with_preview "Show where site files live" echo "Not yet implemented"
}

# Standalone area menu loop (optional)
web_menu() {
  while true; do
    clear
    web_breadcrumb
    echo ""
    echo "Websites & Domains"
    echo "1) Point a domain to this server"
    echo "2) Host a simple website"
    echo "3) Add or remove a site"
    echo "4) Show where site files live"
    echo ""
    echo "0) What is this?"
    echo "P) Preview"
    echo "B) Back"
    echo "Q) Quit"
    read -rp "Choose an option: " choice
    case "$choice" in
      1) menu_web_domain ;;
      2) menu_web_simple ;;
      3) menu_web_manage ;;
      4) menu_web_locations ;;
      0) web_show_readme ;;
      [Pp]) echo "Preview shows planned actions before execution."; read -rp "Press Enter to continue..." _ ;;
      [Bb]) return 0 ;;
      [Qq]) exit 0 ;;
      *) echo "Invalid option"; sleep 1 ;;
    esac
  done
}

