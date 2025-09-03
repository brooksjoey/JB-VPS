#!/usr/bin/env bash
# Area menu: Monitoring & health (scaffold)
set -euo pipefail

JB_DIR="${JB_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
# shellcheck disable=SC1091
source "$JB_DIR/lib/base.sh"

monitoring_breadcrumb() {
  echo "You are here: Home ▸ Monitoring & health"
}

monitoring_show_readme() {
  local readme="$JB_DIR/areas/monitoring/README.md"
  if [[ -f "$readme" ]]; then
    if command -v less >/dev/null 2>&1; then
      less "$readme"
    else
      cat "$readme"
    fi
  else
    echo "README not found for Monitoring area: $readme"
  fi
}

# Action handlers used by bin/menu.sh -> run_area_script
menu_monitoring_status() {
  with_preview "Show system status" echo "Not yet implemented"
}

menu_monitoring_resources() {
  with_preview "See what's using CPU and memory" echo "Not yet implemented"
}

menu_monitoring_services() {
  with_preview "Check running services" echo "Not yet implemented"
}

menu_monitoring_errors() {
  with_preview "View recent errors" echo "Not yet implemented"
}

# Standalone area menu loop (optional)
monitoring_menu() {
  while true; do
    clear
    monitoring_breadcrumb
    echo ""
    echo "Monitoring & Health"
    echo "1) Show system status"
    echo "2) See what's using CPU and memory"
    echo "3) Check running services"
    echo "4) View recent errors"
    echo ""
    echo "0) What is this?"
    echo "P) Preview"
    echo "B) Back"
    echo "Q) Quit"
    read -rp "Choose an option: " choice
    case "$choice" in
      1) menu_monitoring_status ;;
      2) menu_monitoring_resources ;;
      3) menu_monitoring_services ;;
      4) menu_monitoring_errors ;;
      0) monitoring_show_readme ;;
      [Pp]) echo "Preview shows planned actions before execution."; read -rp "Press Enter to continue..." _ ;;
      [Bb]) return 0 ;;
      [Qq]) exit 0 ;;
      *) echo "Invalid option"; sleep 1 ;;
    esac
  done
}

