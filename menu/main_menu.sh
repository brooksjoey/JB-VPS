#!/usr/bin/env bash
# JB-VPS Main Menu System
set -euo pipefail

done

while true; do
  echo "\n==== JB-VPS Main Menu ===="
  echo "1) System Info"
  echo "2) Run Modules"
  echo "3) View Mnemosyneos Log"
  echo "4) Backup VPS"
  echo "5) Monitor VPS"
  echo "6) Configure Firewall"
  echo "7) Help"
  echo "8) Exit"
  read -rp "Select an option: " choice
  case "$choice" in
    1)
      uname -a
      ;;
    2)
      for mod in "$(dirname "$0")/../modules/"*.sh; do
        [ -f "$mod" ] && bash "$mod"
      done
      ;;
    3)
      bash "$(dirname "$0")/../mnemosyneos/memory.sh" view
      ;;
    4)
      bash "$(dirname "$0")/../modules/backup.sh"
      ;;
    5)
      bash "$(dirname "$0")/../modules/monitoring.sh"
      ;;
    6)
      bash "$(dirname "$0")/../modules/firewall.sh"
      ;;
    7)
      bash "$(dirname "$0")/help_menu.sh"
      ;;
    8)
      echo "Exiting JB-VPS menu."
      exit 0
      ;;
    *)
      echo "Invalid option. Try again."
      ;;
  esac
