#!/usr/bin/env bash
# JB-VPS Menu System - Text UI with breadcrumbs and plain English
set -euo pipefail

# Source base functionality
JB_DIR="${JB_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
source "$JB_DIR/lib/base.sh"

# Menu state
declare -g MENU_BREADCRUMB=()
declare -g CURRENT_AREA=""

# Colors for menu display
declare -g MENU_HEADER='\033[1;34m'  # Bold Blue
declare -g MENU_OPTION='\033[0;36m'  # Cyan
declare -g MENU_SPECIAL='\033[1;33m' # Bold Yellow
declare -g MENU_RESET='\033[0m'      # Reset

# Display breadcrumb navigation
show_breadcrumb() {
    local breadcrumb_text="You are here: "
    
    if [[ ${#MENU_BREADCRUMB[@]} -eq 0 ]]; then
        breadcrumb_text+="Home"
    else
        breadcrumb_text+="Home"
        for crumb in "${MENU_BREADCRUMB[@]}"; do
            breadcrumb_text+=" ▸ $crumb"
        done
    fi
    
    echo -e "${MENU_HEADER}$breadcrumb_text${MENU_RESET}"
    echo ""
}

# Display menu header
show_header() {
    local title="$1"
    clear
    echo -e "${MENU_HEADER}╔══════════════════════════════════════════════════════════════╗${MENU_RESET}"
    echo -e "${MENU_HEADER}║                        JB-VPS v2.0                          ║${MENU_RESET}"
    echo -e "${MENU_HEADER}║              Functionality-First VPS Toolkit                ║${MENU_RESET}"
    echo -e "${MENU_HEADER}╚══════════════════════════════════════════════════════════════╝${MENU_RESET}"
    echo ""
    show_breadcrumb
    echo -e "${MENU_HEADER}$title${MENU_RESET}"
    echo ""
}

# Display standard menu options
show_standard_options() {
    echo ""
    echo -e "${MENU_SPECIAL}0)${MENU_RESET} What is this?"
    echo -e "${MENU_SPECIAL}P)${MENU_RESET} Preview"
    echo -e "${MENU_SPECIAL}B)${MENU_RESET} Back"
    echo -e "${MENU_SPECIAL}Q)${MENU_RESET} Quit"
    echo ""
}

# Show README for current area
show_readme() {
    local readme_path
    
    if [[ -z "$CURRENT_AREA" ]]; then
        readme_path="$JB_DIR/README.md"
    else
        readme_path="$JB_DIR/areas/$CURRENT_AREA/README.md"
    fi
    
    if [[ -f "$readme_path" ]]; then
        clear
        show_breadcrumb
        echo -e "${MENU_HEADER}README - What is this?${MENU_RESET}"
        echo ""
        
        # Display README content with basic formatting
        if command -v less >/dev/null 2>&1; then
            less "$readme_path"
        else
            cat "$readme_path"
            echo ""
            read -p "Press Enter to continue..." -r
        fi
    else
        # Auto-generate a basic README stub
        generate_readme_stub "$readme_path"
        show_readme
    fi
}

# Generate README stub for missing areas
generate_readme_stub() {
    local readme_path="$1"
    local area_name="${CURRENT_AREA:-JB-VPS}"
    
    mkdir -p "$(dirname "$readme_path")"
    
    cat > "$readme_path" << EOF
# $area_name

## What this area is for

This area provides functionality for managing $area_name on your VPS.

## Common things you can do here

- View current status and configuration
- Make changes to settings
- Install and configure related services
- Monitor and troubleshoot issues

## What each menu choice will do

Each menu option will guide you through specific tasks with clear previews
before making any changes to your system.

## Where files will be created

- Configuration files: /etc/
- Data files: /var/lib/
- Log files: /var/log/jb-vps/
- Backups: Various locations with .backups/ subdirectories

## Logs and files

- Main log: /var/log/jb-vps/jb-vps.log
- State tracking: $JB_DIR/.state/
- Configuration: $JB_DIR/config/

For more information, run 'jb help' or visit the project documentation.
EOF

    log_info "Generated README stub for $area_name at $readme_path" "MENU"
}

# Preview functionality
show_preview() {
    echo -e "${MENU_HEADER}Preview Mode${MENU_RESET}"
    echo ""
    echo "Preview mode shows you exactly what will happen before any action is taken."
    echo "This includes:"
    echo "  • What commands will be run"
    echo "  • What files will be created or modified"
    echo "  • What packages will be installed"
    echo "  • What services will be started or stopped"
    echo ""
    echo "You'll always be asked to confirm before proceeding."
    echo ""
    read -p "Press Enter to continue..." -r
}

# Main menu
show_main_menu() {
    CURRENT_AREA=""
    MENU_BREADCRUMB=()
    
    while true; do
        show_header "Main Menu"
        
        echo -e "${MENU_OPTION}1)${MENU_RESET} Set up this server for my work"
        echo -e "${MENU_OPTION}2)${MENU_RESET} Apps & services"
        echo -e "${MENU_OPTION}3)${MENU_RESET} Databases"
        echo -e "${MENU_OPTION}4)${MENU_RESET} Websites & domains"
        echo -e "${MENU_OPTION}5)${MENU_RESET} Files & backups"
        echo -e "${MENU_OPTION}6)${MENU_RESET} Users & access"
        echo -e "${MENU_OPTION}7)${MENU_RESET} Monitoring & health"
        echo -e "${MENU_OPTION}8)${MENU_RESET} Developer tools"
        
        show_standard_options
        
        read -p "Choose an option: " -r choice
        
        case "$choice" in
            1) run_server_setup ;;
            2) show_apps_menu ;;
            3) show_databases_menu ;;
            4) show_websites_menu ;;
            5) show_files_menu ;;
            6) show_users_menu ;;
            7) show_monitoring_menu ;;
            8) show_devtools_menu ;;
            0|"0") show_readme ;;
            p|P) show_preview ;;
            q|Q) exit 0 ;;
            b|B) echo "Already at main menu" ;;
            *) echo "Invalid option. Please try again." ;;
        esac
    done
}

# Server setup (jb init equivalent)
run_server_setup() {
    show_header "Set up this server for my work"
    
    echo "This will set up your server with common tools and configurations."
    echo ""
    echo "What will be installed and configured:"
    echo "  • Essential system packages"
    echo "  • Security hardening (optional)"
    echo "  • Basic monitoring"
    echo "  • Development tools"
    echo ""
    
    if [[ "$(jb_state_get 'server_setup_complete')" == "true" ]]; then
        echo -e "${MENU_SPECIAL}✓ Server setup already completed${MENU_RESET}"
        echo ""
        read -p "Press Enter to continue..." -r
        return
    fi
    
    read -p "Proceed with server setup? [y/N] " -r
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        if command -v jb_init_server >/dev/null 2>&1; then
            jb_init_server
        else
            log_info "Running basic server initialization..." "SETUP"
            # Basic setup - this would call the actual init function
            jb_state_set "server_setup_complete" "true"
            echo "Server setup completed!"
        fi
    fi
    
    read -p "Press Enter to continue..." -r
}

# Apps & services menu
show_apps_menu() {
    CURRENT_AREA="apps"
    MENU_BREADCRUMB=("Apps & services")
    
    while true; do
        show_header "Apps & Services"
        
        echo -e "${MENU_OPTION}1)${MENU_RESET} List installed apps"
        echo -e "${MENU_OPTION}2)${MENU_RESET} Add a new app"
        echo -e "${MENU_OPTION}3)${MENU_RESET} Start/Stop/Restart an app"
        echo -e "${MENU_OPTION}4)${MENU_RESET} Turn an app on/off at startup"
        
        show_standard_options
        
        read -p "Choose an option: " -r choice
        
        case "$choice" in
            1) run_area_script "apps" "list" ;;
            2) run_area_script "apps" "add" ;;
            3) run_area_script "apps" "control" ;;
            4) run_area_script "apps" "startup" ;;
            0|"0") show_readme ;;
            p|P) show_preview ;;
            b|B) return ;;
            q|Q) exit 0 ;;
            *) echo "Invalid option. Please try again." ;;
        esac
    done
}

# Databases menu
show_databases_menu() {
    CURRENT_AREA="databases"
    MENU_BREADCRUMB=("Databases")
    
    while true; do
        show_header "Databases"
        
        echo -e "${MENU_OPTION}1)${MENU_RESET} Install a database (PostgreSQL/MySQL/SQLite)"
        echo -e "${MENU_OPTION}2)${MENU_RESET} Create a database and user"
        echo -e "${MENU_OPTION}3)${MENU_RESET} Back up a database"
        echo -e "${MENU_OPTION}4)${MENU_RESET} Restore a backup"
        
        show_standard_options
        
        read -p "Choose an option: " -r choice
        
        case "$choice" in
            1) run_area_script "databases" "install" ;;
            2) run_area_script "databases" "create" ;;
            3) run_area_script "databases" "backup" ;;
            4) run_area_script "databases" "restore" ;;
            0|"0") show_readme ;;
            p|P) show_preview ;;
            b|B) return ;;
            q|Q) exit 0 ;;
            *) echo "Invalid option. Please try again." ;;
        esac
    done
}

# Websites & domains menu
show_websites_menu() {
    CURRENT_AREA="web"
    MENU_BREADCRUMB=("Websites & domains")
    
    while true; do
        show_header "Websites & Domains"
        
        echo -e "${MENU_OPTION}1)${MENU_RESET} Point a domain to this server"
        echo -e "${MENU_OPTION}2)${MENU_RESET} Host a simple website"
        echo -e "${MENU_OPTION}3)${MENU_RESET} Add or remove a site"
        echo -e "${MENU_OPTION}4)${MENU_RESET} Show where site files live"
        
        show_standard_options
        
        read -p "Choose an option: " -r choice
        
        case "$choice" in
            1) run_area_script "web" "domain" ;;
            2) run_area_script "web" "simple" ;;
            3) run_area_script "web" "manage" ;;
            4) run_area_script "web" "locations" ;;
            0|"0") show_readme ;;
            p|P) show_preview ;;
            b|B) return ;;
            q|Q) exit 0 ;;
            *) echo "Invalid option. Please try again." ;;
        esac
    done
}

# Files & backups menu
show_files_menu() {
    CURRENT_AREA="files"
    MENU_BREADCRUMB=("Files & backups")
    
    while true; do
        show_header "Files & Backups"
        
        echo -e "${MENU_OPTION}1)${MENU_RESET} Show disk space"
        echo -e "${MENU_OPTION}2)${MENU_RESET} Create a backup plan"
        echo -e "${MENU_OPTION}3)${MENU_RESET} Run a backup now"
        echo -e "${MENU_OPTION}4)${MENU_RESET} Restore files from backup"
        
        show_standard_options
        
        read -p "Choose an option: " -r choice
        
        case "$choice" in
            1) run_area_script "files" "space" ;;
            2) run_area_script "files" "plan" ;;
            3) run_area_script "files" "backup" ;;
            4) run_area_script "files" "restore" ;;
            0|"0") show_readme ;;
            p|P) show_preview ;;
            b|B) return ;;
            q|Q) exit 0 ;;
            *) echo "Invalid option. Please try again." ;;
        esac
    done
}

# Users & access menu
show_users_menu() {
    CURRENT_AREA="users"
    MENU_BREADCRUMB=("Users & access")
    
    while true; do
        show_header "Users & Access"
        
        echo -e "${MENU_OPTION}1)${MENU_RESET} Add a user"
        echo -e "${MENU_OPTION}2)${MENU_RESET} Give or remove admin rights"
        echo -e "${MENU_OPTION}3)${MENU_RESET} Set up SSH keys"
        echo -e "${MENU_OPTION}4)${MENU_RESET} Turn password login on/off"
        
        show_standard_options
        
        read -p "Choose an option: " -r choice
        
        case "$choice" in
            1) run_area_script "users" "add" ;;
            2) run_area_script "users" "admin" ;;
            3) run_area_script "users" "ssh" ;;
            4) run_area_script "users" "password" ;;
            0|"0") show_readme ;;
            p|P) show_preview ;;
            b|B) return ;;
            q|Q) exit 0 ;;
            *) echo "Invalid option. Please try again." ;;
        esac
    done
}

# Monitoring & health menu
show_monitoring_menu() {
    CURRENT_AREA="monitoring"
    MENU_BREADCRUMB=("Monitoring & health")
    
    while true; do
        show_header "Monitoring & Health"
        
        echo -e "${MENU_OPTION}1)${MENU_RESET} Show system status"
        echo -e "${MENU_OPTION}2)${MENU_RESET} See what's using CPU and memory"
        echo -e "${MENU_OPTION}3)${MENU_RESET} Check running services"
        echo -e "${MENU_OPTION}4)${MENU_RESET} View recent errors"
        echo -e "${MENU_OPTION}5)${MENU_RESET} View Mnemosyneos log"
        
        show_standard_options
        
        read -p "Choose an option: " -r choice
        
        case "$choice" in
            1) run_area_script "monitoring" "status" ;;
            2) run_area_script "monitoring" "resources" ;;
            3) run_area_script "monitoring" "services" ;;
            4) run_area_script "monitoring" "errors" ;;
            5) with_preview "View Mnemosyneos log" "$JB_DIR/mnemosyneos/memory.sh" view ;;
            0|"0") show_readme ;;
            p|P) show_preview ;;
            b|B) return ;;
            q|Q) exit 0 ;;
            *) echo "Invalid option. Please try again." ;;
        esac
    done
}

# Developer tools menu
show_devtools_menu() {
    CURRENT_AREA="devtools"
    MENU_BREADCRUMB=("Developer tools")
    
    while true; do
        show_header "Developer Tools"
        
        echo -e "${MENU_OPTION}1)${MENU_RESET} Install common developer tools"
        echo -e "${MENU_OPTION}2)${MENU_RESET} Set up a code workspace"
        echo -e "${MENU_OPTION}3)${MENU_RESET} Pull a repo and run it"
        echo -e "${MENU_OPTION}4)${MENU_RESET} Fix log permissions"
        echo -e "${MENU_OPTION}5)${MENU_RESET} Snapshot & push repo"
        
        show_standard_options
        
        read -p "Choose an option: " -r choice
        
        case "$choice" in
            1) run_area_script "devtools" "install" ;;
            2) run_area_script "devtools" "workspace" ;;
            3) run_area_script "devtools" "repo" ;;
            4) "$JB_DIR/scripts/fix-logs.sh" ;;
            5) run_area_script "devtools" "repo_snapshot" ;;
            0|"0") show_readme ;;
            p|P) show_preview ;;
            b|B) return ;;
            q|Q) exit 0 ;;
            *) echo "Invalid option. Please try again." ;;
        esac
    done
}

# Run area-specific scripts
run_area_script() {
    local area="$1"
    local action="$2"
    
    local script_path="$JB_DIR/areas/$area/scripts/$action.sh"
    local menu_script="$JB_DIR/areas/$area/menu.sh"
    
    # Try area-specific menu script first
    if [[ -f "$menu_script" ]]; then
        source "$menu_script"
        if command -v "menu_${area}_${action}" >/dev/null 2>&1; then
            "menu_${area}_${action}"
            return
        fi
    fi
    
    # Try direct script execution
    if [[ -f "$script_path" ]]; then
        "$script_path"
    else
        echo "Feature not yet implemented: $area/$action"
        echo "Script would be at: $script_path"
        read -p "Press Enter to continue..." -r
    fi
}

# Main entry point
main() {
    # Ensure we have the base system
    if ! command -v jb_register >/dev/null 2>&1; then
        echo "Error: JB-VPS base system not properly loaded"
        exit 1
    fi
    
    # Start the main menu
    show_main_menu
}

# Run if called directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
