#!/usr/bin/env bash
# Area menu: Databases (scaffold)
set -euo pipefail

JB_DIR="${JB_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
# shellcheck disable=SC1091
source "$JB_DIR/lib/base.sh"

db_breadcrumb() {
  echo "You are here: Home ▸ Databases"
}

db_show_readme() {
  local readme="$JB_DIR/areas/databases/README.md"
  if [[ -f "$readme" ]]; then
    if command -v less >/dev/null 2>&1; then
      less "$readme"
    else
      cat "$readme"
    fi
  else
    echo "README not found for Databases area: $readme"
  fi
}

# Action handlers used by bin/menu.sh -> run_area_script
menu_databases_install() {
  with_preview "Install a database (PostgreSQL/MySQL/SQLite)" echo "Not yet implemented"
}

menu_databases_create() {
  with_preview "Create a database and user" echo "Not yet implemented"
}

menu_databases_backup() {
  with_preview "Back up a database" echo "Not yet implemented"
}

menu_databases_restore() {
  with_preview "Restore a backup" echo "Not yet implemented"
}

# Optional standalone loop
databases_menu() {
  while true; do
    clear
    db_breadcrumb
    echo ""
    echo "Databases"
    echo "1) Install a database (PostgreSQL/MySQL/SQLite)"
    echo "2) Create a database and user"
    echo "3) Back up a database"
    echo "4) Restore a backup"
    echo ""
    echo "0) What is this?"
    echo "P) Preview"
    echo "B) Back"
    echo "Q) Quit"
    read -rp "Choose an option: " choice
    case "$choice" in
      1) menu_databases_install ;;
      2) menu_databases_create ;;
      3) menu_databases_backup ;;
      4) menu_databases_restore ;;
      0) db_show_readme ;;
      [Pp]) echo "Preview shows planned actions before execution."; read -rp "Press Enter to continue..." _ ;;
      [Bb]) return 0 ;;
      [Qq]) exit 0 ;;
      *) echo "Invalid option"; sleep 1 ;;
    esac
  done
}

