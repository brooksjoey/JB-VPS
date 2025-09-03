#!/usr/bin/env bash
# Startup management script for JB-VPS
set -euo pipefail

# Source base functionality
JB_DIR="${JB_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)}"
source "$JB_DIR/lib/base.sh"

# Manage application startup settings
manage_app_startup() {
    log_info "Managing application startup settings" "APPS"
    
    echo "🚀 Application Startup Management"
    echo "================================="
    echo ""
    echo "This lets you control which applications start automatically when your server boots."
    echo ""
    
    # Get list of relevant services
    local services=()
    local service_names=()
    local service_descriptions=()
    
    # Check for common services
    if systemctl list-unit-files nginx.service >/dev/null 2>&1; then
        services+=("nginx")
        service_names+=("Nginx Web Server")
        service_descriptions+=("High-performance web server for hosting websites")
    fi
    
    if systemctl list-unit-files apache2.service >/dev/null 2>&1; then
        services+=("apache2")
        service_names+=("Apache Web Server")
        service_descriptions+=("Popular web server for hosting websites")
    fi
    
    if systemctl list-unit-files postgresql.service >/dev/null 2>&1; then
        services+=("postgresql")
        service_names+=("PostgreSQL Database")
        service_descriptions+=("Advanced relational database server")
    fi
    
    if systemctl list-unit-files mysql.service >/dev/null 2>&1; then
        services+=("mysql")
        service_names+=("MySQL Database")
        service_descriptions+=("Popular relational database server")
    fi
    
    if systemctl list-unit-files mariadb.service >/dev/null 2>&1; then
        services+=("mariadb")
        service_names+=("MariaDB Database")
        service_descriptions+=("MySQL-compatible database server")
    fi
    
    if systemctl list-unit-files fail2ban.service >/dev/null 2>&1; then
        services+=("fail2ban")
        service_names+=("Fail2ban Security")
        service_descriptions+=("Intrusion prevention system")
    fi
    
    if systemctl list-unit-files docker.service >/dev/null 2>&1; then
        services+=("docker")
        service_names+=("Docker Platform")
        service_descriptions+=("Container platform for applications")
    fi
    
    if systemctl list-unit-files jb-dashboard-update.timer >/dev/null 2>&1; then
        services+=("jb-dashboard-update.timer")
        service_names+=("JB-VPS Dashboard")
        service_descriptions+=("System monitoring dashboard updates")
    fi
    
    if [[ ${#services[@]} -eq 0 ]]; then
        echo "❌ No manageable services found"
        echo ""
        echo "Install some applications first using:"
        echo "   jb menu → Apps & services → Add a new app"
        read -p "Press Enter to continue..." -r
        return
    fi
    
    echo "Current startup configuration:"
    echo ""
    
    # Display services with startup status
    for i in "${!services[@]}"; do
        local service="${services[$i]}"
        local name="${service_names[$i]}"
        local description="${service_descriptions[$i]}"
        local status
        
        if systemctl is-enabled --quiet "$service" 2>/dev/null; then
            status="🟢 Enabled"
        else
            status="🔴 Disabled"
        fi
        
        printf "  %2d) %-25s %s\n" $((i+1)) "$name" "$status"
        printf "      %s\n" "$description"
        echo ""
    done
    
    echo "Actions:"
    echo "  E) Enable all recommended services"
    echo "  D) Disable all services"
    echo "  C) Custom configuration"
    echo "  0) Back to menu"
    echo ""
    
    read -p "Choose an option: " -r choice
    
    case "$choice" in
        [Ee]) enable_recommended_services "${services[@]}" ;;
        [Dd]) disable_all_services "${services[@]}" ;;
        [Cc]) custom_startup_config "${services[@]}" ;;
        0) return ;;
        [1-9]|[1-9][0-9]) 
            if [[ $choice -ge 1 ]] && [[ $choice -le ${#services[@]} ]]; then
                toggle_service_startup "${services[$((choice-1))]}" "${service_names[$((choice-1))]}"
            else
                echo "Invalid option. Please try again."
                read -p "Press Enter to continue..." -r
                manage_app_startup
            fi
            ;;
        *) 
            echo "Invalid option. Please try again."
            read -p "Press Enter to continue..." -r
            manage_app_startup
            ;;
    esac
}

# Enable recommended services
enable_recommended_services() {
    local services=("$@")
    
    echo "🟢 Enabling Recommended Services"
    echo "================================"
    echo ""
    echo "This will enable essential services to start automatically at boot:"
    echo ""
    
    # Define recommended services
    local recommended=("nginx" "apache2" "postgresql" "mysql" "mariadb" "fail2ban" "jb-dashboard-update.timer")
    
    for service in "${services[@]}"; do
        for rec in "${recommended[@]}"; do
            if [[ "$service" == "$rec" ]]; then
                if systemctl is-enabled --quiet "$service" 2>/dev/null; then
                    echo "  ✅ $service (already enabled)"
                else
                    echo "  🔄 $service (enabling...)"
                fi
                break
            fi
        done
    done
    
    echo ""
    read -p "Continue with enabling recommended services? [y/N] " -r
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo ""
        echo "Enabling services..."
        
        for service in "${services[@]}"; do
            for rec in "${recommended[@]}"; do
                if [[ "$service" == "$rec" ]]; then
                    if ! systemctl is-enabled --quiet "$service" 2>/dev/null; then
                        if as_root systemctl enable "$service" 2>/dev/null; then
                            echo "  ✅ Enabled $service"
                            log_info "Enabled service at startup: $service" "APPS"
                        else
                            echo "  ❌ Failed to enable $service"
                            log_error "Failed to enable service at startup: $service" "APPS"
                        fi
                    fi
                    break
                fi
            done
        done
        
        echo ""
        echo "✅ Recommended services have been enabled for startup"
    else
        echo "Operation cancelled."
    fi
    
    read -p "Press Enter to continue..." -r
}

# Disable all services
disable_all_services() {
    local services=("$@")
    
    echo "🔴 Disabling All Services"
    echo "========================="
    echo ""
    echo "⚠️  Warning: This will disable ALL services from starting at boot."
    echo "   You will need to start them manually after each reboot."
    echo ""
    echo "Services that will be disabled:"
    
    for service in "${services[@]}"; do
        if systemctl is-enabled --quiet "$service" 2>/dev/null; then
            echo "  • $service"
        fi
    done
    
    echo ""
    read -p "Are you sure you want to disable all services? [y/N] " -r
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo ""
        echo "Disabling services..."
        
        for service in "${services[@]}"; do
            if systemctl is-enabled --quiet "$service" 2>/dev/null; then
                if as_root systemctl disable "$service" 2>/dev/null; then
                    echo "  ✅ Disabled $service"
                    log_info "Disabled service at startup: $service" "APPS"
                else
                    echo "  ❌ Failed to disable $service"
                    log_error "Failed to disable service at startup: $service" "APPS"
                fi
            fi
        done
        
        echo ""
        echo "✅ All services have been disabled from startup"
    else
        echo "Operation cancelled."
    fi
    
    read -p "Press Enter to continue..." -r
}

# Custom startup configuration
custom_startup_config() {
    local services=("$@")
    
    while true; do
        clear
        echo "⚙️  Custom Startup Configuration"
        echo "================================"
        echo ""
        echo "Toggle individual services on/off for startup:"
        echo ""
        
        # Display services with current status
        for i in "${!services[@]}"; do
            local service="${services[$i]}"
            local status
            
            if systemctl is-enabled --quiet "$service" 2>/dev/null; then
                status="🟢 Enabled"
            else
                status="🔴 Disabled"
            fi
            
            printf "  %2d) %-25s %s\n" $((i+1)) "$service" "$status"
        done
        
        echo ""
        echo "  0) Back to startup menu"
        echo ""
        
        read -p "Choose a service to toggle (1-${#services[@]}): " -r choice
        
        if [[ "$choice" == "0" ]]; then
            return
        fi
        
        if [[ "$choice" =~ ^[0-9]+$ ]] && [[ $choice -ge 1 ]] && [[ $choice -le ${#services[@]} ]]; then
            local selected_service="${services[$((choice-1))]}"
            toggle_service_startup "$selected_service" "$selected_service"
        else
            echo "Invalid option. Please try again."
            read -p "Press Enter to continue..." -r
        fi
    done
}

# Toggle individual service startup
toggle_service_startup() {
    local service="$1"
    local name="$2"
    
    echo ""
    echo "Managing startup for: $name"
    echo "=========================="
    echo ""
    
    if systemctl is-enabled --quiet "$service" 2>/dev/null; then
        echo "Current status: 🟢 Enabled (starts at boot)"
        echo ""
        read -p "Disable $name from starting at boot? [y/N] " -r
        
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            if as_root systemctl disable "$service" 2>/dev/null; then
                echo "✅ $name disabled from startup"
                log_info "Disabled service at startup: $service" "APPS"
            else
                echo "❌ Failed to disable $name from startup"
                log_error "Failed to disable service at startup: $service" "APPS"
            fi
        else
            echo "No changes made."
        fi
    else
        echo "Current status: 🔴 Disabled (manual start only)"
        echo ""
        read -p "Enable $name to start at boot? [y/N] " -r
        
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            if as_root systemctl enable "$service" 2>/dev/null; then
                echo "✅ $name enabled for startup"
                log_info "Enabled service at startup: $service" "APPS"
            else
                echo "❌ Failed to enable $name for startup"
                log_error "Failed to enable service at startup: $service" "APPS"
            fi
        else
            echo "No changes made."
        fi
    fi
    
    read -p "Press Enter to continue..." -r
}

# Run the function
manage_app_startup
