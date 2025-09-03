#!/usr/bin/env bash
# Service control script for JB-VPS
set -euo pipefail

# Source base functionality
JB_DIR="${JB_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)}"
source "$JB_DIR/lib/base.sh"

# Control application services
control_app_services() {
    log_info "Managing application services" "APPS"
    
    echo "🔧 Start/Stop/Restart Applications"
    echo "=================================="
    echo ""
    
    # Get list of relevant services
    local services=()
    local service_names=()
    
    # Check for common services
    if systemctl list-unit-files nginx.service >/dev/null 2>&1; then
        services+=("nginx")
        service_names+=("Nginx Web Server")
    fi
    
    if systemctl list-unit-files apache2.service >/dev/null 2>&1; then
        services+=("apache2")
        service_names+=("Apache Web Server")
    fi
    
    if systemctl list-unit-files postgresql.service >/dev/null 2>&1; then
        services+=("postgresql")
        service_names+=("PostgreSQL Database")
    fi
    
    if systemctl list-unit-files mysql.service >/dev/null 2>&1; then
        services+=("mysql")
        service_names+=("MySQL Database")
    fi
    
    if systemctl list-unit-files mariadb.service >/dev/null 2>&1; then
        services+=("mariadb")
        service_names+=("MariaDB Database")
    fi
    
    if systemctl list-unit-files fail2ban.service >/dev/null 2>&1; then
        services+=("fail2ban")
        service_names+=("Fail2ban Security")
    fi
    
    if systemctl list-unit-files docker.service >/dev/null 2>&1; then
        services+=("docker")
        service_names+=("Docker Container Platform")
    fi
    
    if systemctl list-unit-files jb-dashboard-update.timer >/dev/null 2>&1; then
        services+=("jb-dashboard-update.timer")
        service_names+=("JB-VPS Dashboard Timer")
    fi
    
    if [[ ${#services[@]} -eq 0 ]]; then
        echo "❌ No manageable services found"
        echo ""
        echo "Install some applications first using:"
        echo "   jb menu → Apps & services → Add a new app"
        read -p "Press Enter to continue..." -r
        return
    fi
    
    echo "Available services:"
    echo ""
    
    # Display services with status
    for i in "${!services[@]}"; do
        local service="${services[$i]}"
        local name="${service_names[$i]}"
        local status
        
        if systemctl is-active --quiet "$service" 2>/dev/null; then
            status="🟢 Running"
        else
            status="🔴 Stopped"
        fi
        
        printf "  %2d) %-30s %s\n" $((i+1)) "$name" "$status"
    done
    
    echo ""
    echo "  0) Back to menu"
    echo ""
    
    read -p "Choose a service to manage (1-${#services[@]}): " -r choice
    
    if [[ "$choice" == "0" ]]; then
        return
    fi
    
    if [[ "$choice" =~ ^[0-9]+$ ]] && [[ $choice -ge 1 ]] && [[ $choice -le ${#services[@]} ]]; then
        local selected_service="${services[$((choice-1))]}"
        local selected_name="${service_names[$((choice-1))]}"
        manage_service "$selected_service" "$selected_name"
    else
        echo "Invalid option. Please try again."
        read -p "Press Enter to continue..." -r
        control_app_services
    fi
}

# Manage individual service
manage_service() {
    local service="$1"
    local name="$2"
    
    while true; do
        clear
        echo "🔧 Managing: $name"
        echo "===================="
        echo ""
        
        # Show current status
        local status
        local enabled_status
        
        if systemctl is-active --quiet "$service" 2>/dev/null; then
            status="🟢 Running"
        else
            status="🔴 Stopped"
        fi
        
        if systemctl is-enabled --quiet "$service" 2>/dev/null; then
            enabled_status="🟢 Enabled (starts at boot)"
        else
            enabled_status="🔴 Disabled (manual start only)"
        fi
        
        echo "Current Status: $status"
        echo "Boot Status: $enabled_status"
        echo ""
        
        # Show service actions
        echo "Available actions:"
        echo ""
        echo "  1) Start service"
        echo "  2) Stop service"
        echo "  3) Restart service"
        echo "  4) Enable at boot"
        echo "  5) Disable at boot"
        echo "  6) View service logs"
        echo "  7) View service status details"
        echo ""
        echo "  0) Back to service list"
        echo ""
        
        read -p "Choose an action (1-7): " -r action
        
        case "$action" in
            1) service_start "$service" "$name" ;;
            2) service_stop "$service" "$name" ;;
            3) service_restart "$service" "$name" ;;
            4) service_enable "$service" "$name" ;;
            5) service_disable "$service" "$name" ;;
            6) service_logs "$service" "$name" ;;
            7) service_status "$service" "$name" ;;
            0) return ;;
            *) 
                echo "Invalid option. Please try again."
                read -p "Press Enter to continue..." -r
                ;;
        esac
    done
}

# Start service
service_start() {
    local service="$1"
    local name="$2"
    
    echo "Starting $name..."
    
    if systemctl is-active --quiet "$service" 2>/dev/null; then
        echo "✅ $name is already running"
    else
        if as_root systemctl start "$service"; then
            echo "✅ $name started successfully"
            log_info "Started service: $service" "APPS"
        else
            echo "❌ Failed to start $name"
            log_error "Failed to start service: $service" "APPS"
        fi
    fi
    
    read -p "Press Enter to continue..." -r
}

# Stop service
service_stop() {
    local service="$1"
    local name="$2"
    
    echo "Stopping $name..."
    echo ""
    echo "⚠️  Warning: This will stop the $name service."
    echo "   Users may lose access to functionality provided by this service."
    echo ""
    read -p "Are you sure you want to stop $name? [y/N] " -r
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        if as_root systemctl stop "$service"; then
            echo "✅ $name stopped successfully"
            log_info "Stopped service: $service" "APPS"
        else
            echo "❌ Failed to stop $name"
            log_error "Failed to stop service: $service" "APPS"
        fi
    else
        echo "Operation cancelled."
    fi
    
    read -p "Press Enter to continue..." -r
}

# Restart service
service_restart() {
    local service="$1"
    local name="$2"
    
    echo "Restarting $name..."
    echo ""
    echo "This will restart the $name service."
    echo "There may be a brief interruption in service."
    echo ""
    read -p "Continue with restart? [y/N] " -r
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        if as_root systemctl restart "$service"; then
            echo "✅ $name restarted successfully"
            log_info "Restarted service: $service" "APPS"
        else
            echo "❌ Failed to restart $name"
            log_error "Failed to restart service: $service" "APPS"
        fi
    else
        echo "Operation cancelled."
    fi
    
    read -p "Press Enter to continue..." -r
}

# Enable service at boot
service_enable() {
    local service="$1"
    local name="$2"
    
    echo "Enabling $name to start at boot..."
    
    if systemctl is-enabled --quiet "$service" 2>/dev/null; then
        echo "✅ $name is already enabled at boot"
    else
        if as_root systemctl enable "$service"; then
            echo "✅ $name enabled to start at boot"
            log_info "Enabled service at boot: $service" "APPS"
        else
            echo "❌ Failed to enable $name at boot"
            log_error "Failed to enable service at boot: $service" "APPS"
        fi
    fi
    
    read -p "Press Enter to continue..." -r
}

# Disable service at boot
service_disable() {
    local service="$1"
    local name="$2"
    
    echo "Disabling $name from starting at boot..."
    echo ""
    echo "⚠️  Warning: $name will not start automatically after system reboot."
    echo "   You will need to start it manually if needed."
    echo ""
    read -p "Are you sure you want to disable $name at boot? [y/N] " -r
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        if as_root systemctl disable "$service"; then
            echo "✅ $name disabled from starting at boot"
            log_info "Disabled service at boot: $service" "APPS"
        else
            echo "❌ Failed to disable $name at boot"
            log_error "Failed to disable service at boot: $service" "APPS"
        fi
    else
        echo "Operation cancelled."
    fi
    
    read -p "Press Enter to continue..." -r
}

# View service logs
service_logs() {
    local service="$1"
    local name="$2"
    
    echo "Viewing logs for $name..."
    echo ""
    echo "Showing last 50 lines (press 'q' to quit, space for more):"
    echo ""
    
    if command -v journalctl >/dev/null 2>&1; then
        journalctl -u "$service" -n 50 --no-pager || true
    else
        echo "❌ journalctl not available"
    fi
    
    echo ""
    read -p "Press Enter to continue..." -r
}

# View detailed service status
service_status() {
    local service="$1"
    local name="$2"
    
    echo "Detailed status for $name:"
    echo ""
    
    if command -v systemctl >/dev/null 2>&1; then
        systemctl status "$service" --no-pager || true
    else
        echo "❌ systemctl not available"
    fi
    
    echo ""
    read -p "Press Enter to continue..." -r
}

# Run the function
control_app_services
