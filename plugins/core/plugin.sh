#!/usr/bin/env bash
# Enhanced Core Plugin for JB-VPS
# Provides essential system management and initialization functions

set -euo pipefail
source "$JB_DIR/lib/base.sh"

# Core plugin initialization
core_plugin_init() {
    log_info "Initializing core plugin" "CORE"
    
    # Ensure required directories exist
    mkdir -p "$JB_DIR/scripts/bootstrap"
    mkdir -p "$JB_DIR/scripts/maintenance"
    mkdir -p "$JB_DIR/scripts/recovery"
    
    log_debug "Core plugin initialized" "CORE"
}

# Bootstrap/Initialize VPS
core_bootstrap() {
    local force="${1:-false}"
    
    log_info "Starting VPS bootstrap process" "CORE"
    
    local bootstrap_script="$JB_DIR/scripts/bootstrap/vps-bootstrap.sh"
    
    if [[ ! -x "$bootstrap_script" ]]; then
        log_error "Bootstrap script not found or not executable: $bootstrap_script" "CORE"
        return 1
    fi
    
    if [[ "$force" == "true" ]]; then
        log_info "Force bootstrap requested" "CORE"
        as_root "$bootstrap_script" --force
    else
        as_root "$bootstrap_script"
    fi
}

# Legacy init function for backward compatibility
core_init() {
    core_bootstrap "$@"
}

# Security hardening
core_harden() {
    log_info "Starting security hardening" "CORE"
    
    # Use new bootstrap script's hardening if available
    local bootstrap_script="$JB_DIR/scripts/bootstrap/vps-bootstrap.sh"
    if [[ -x "$bootstrap_script" ]]; then
        log_info "Using integrated bootstrap hardening" "CORE"
        as_root "$bootstrap_script" --force
        return $?
    fi
    
    # Fallback to legacy hardening script
    local legacy_script="$JB_DIR/scripts/security_hardening.sh"
    if [[ -x "$legacy_script" ]]; then
        log_warn "Using legacy hardening script" "CORE"
        as_root "$legacy_script"
    else
        log_error "No hardening script available" "CORE"
        return 1
    fi
}

# Enhanced system information
core_info() {
    local format="${1:-json}"
    local detailed="${2:-false}"
    
    log_debug "Gathering system information (format: $format, detailed: $detailed)" "CORE"
    
    # Use enhanced system info from base library
    if command -v get_system_info >/dev/null 2>&1; then
        get_system_info "$format"
        return $?
    fi
    
    # Fallback to basic info
    need jq || pkg_install jq
    
    if [[ -x "$JB_DIR/dashboards/vps-dashboard/scripts/sysinfo.sh" ]]; then
        as_root "$JB_DIR/dashboards/vps-dashboard/scripts/sysinfo.sh"
    else
        echo "{}" | jq -c --arg host "$(hostname)" --arg kern "$(uname -r)" \
          --arg os "$(grep PRETTY_NAME /etc/os-release 2>/dev/null | cut -d= -f2 | tr -d '"')" \
          ". + {hostname:\$host, os:{pretty:\$os}, kernel:\$kern}"
    fi
}

# System status check
core_status() {
    log_info "Checking system status" "CORE"
    
    echo "🖥️  JB-VPS System Status"
    echo "========================"
    echo ""
    
    # Basic system info
    echo "📋 System Information:"
    echo "  Hostname: $(hostname)"
    echo "  OS: $(grep PRETTY_NAME /etc/os-release 2>/dev/null | cut -d= -f2 | tr -d '"' )"
    echo "  Kernel: $(uname -r)"
    echo "  Architecture: $(uname -m)"
    echo "  Uptime: $(uptime -p 2>/dev/null || uptime)"
    echo ""
    
    # Resource usage
    echo "📊 Resource Usage:"
    local load_avg
    load_avg=$(uptime | awk -F'load average:' '{print $2}' | xargs)
    echo "  Load Average: $load_avg"
    
    local memory_info
    memory_info=$(free -h | awk 'NR==2{printf "Used: %s / %s (%.1f%%)", $3, $2, $3*100/$2}')
    echo "  Memory: $memory_info"
    
    local disk_usage
    disk_usage=$(df -h / | awk 'NR==2{print $5}')
    echo "  Disk Usage: $disk_usage"
    echo ""
    
    # Service status
    echo "🔧 JB-VPS Services:"
    if systemctl is-active --quiet jb-vps-maintenance.timer; then
        echo "  ✅ Maintenance Timer: Active"
    else
        echo "  ❌ Maintenance Timer: Inactive"
    fi
    
    if systemctl is-active --quiet jb-vps-monitor.service; then
        echo "  ✅ System Monitor: Active"
    else
        echo "  ⚠️  System Monitor: Inactive"
    fi
    echo ""
    
    # Security status
    echo "🛡️  Security Status:"
    if systemctl is-active --quiet fail2ban; then
        echo "  ✅ Fail2ban: Active"
    else
        echo "  ❌ Fail2ban: Inactive"
    fi
    
    if command -v ufw >/dev/null 2>&1; then
        if ufw status | grep -q "Status: active"; then
            echo "  ✅ UFW Firewall: Active"
        else
            echo "  ❌ UFW Firewall: Inactive"
        fi
    elif command -v firewall-cmd >/dev/null 2>&1; then
        if systemctl is-active --quiet firewalld; then
            echo "  ✅ Firewalld: Active"
        else
            echo "  ❌ Firewalld: Inactive"
        fi
    else
        echo "  ⚠️  Firewall: Unknown"
    fi
    echo ""
    
    # Bootstrap status
    echo "🚀 Bootstrap Status:"
    local bootstrap_state="/var/lib/jb-vps/bootstrap.state"
    if [[ -f "$bootstrap_state" ]]; then
        if grep -q "bootstrap_completed=completed" "$bootstrap_state"; then
            local completed_date
            completed_date=$(grep "bootstrap_completed=" "$bootstrap_state" | cut -d'=' -f2)
            echo "  ✅ Bootstrap: Completed ($completed_date)"
        else
            echo "  ⚠️  Bootstrap: Partially completed"
        fi
    else
        echo "  ❌ Bootstrap: Not completed"
    fi
    echo ""
    
    # Log system status for monitoring
    if command -v log_system_status >/dev/null 2>&1; then
        log_system_status "CORE"
    fi
}

# System maintenance
core_maintenance() {
    local auto_mode="${1:-false}"
    
    log_info "Starting system maintenance (auto: $auto_mode)" "CORE"
    
    echo "🔧 JB-VPS System Maintenance"
    echo "============================"
    echo ""
    
    # Update package lists
    echo "📦 Updating package lists..."
    local os
    os=$(detect_os)
    
    case "$os" in
        debian|ubuntu)
            as_root apt-get update -qq
            ;;
        fedora)
            as_root dnf check-update -q || true
            ;;
        centos|rhel)
            as_root yum check-update -q || true
            ;;
    esac
    
    # Clean package cache
    echo "🧹 Cleaning package cache..."
    case "$os" in
        debian|ubuntu)
            as_root apt-get autoclean -qq
            as_root apt-get autoremove -qq -y
            ;;
        fedora)
            as_root dnf autoremove -q -y
            as_root dnf clean all -q
            ;;
        centos|rhel)
            as_root yum autoremove -q -y
            as_root yum clean all -q
            ;;
    esac
    
    # Rotate logs
    echo "📝 Rotating logs..."
    as_root logrotate -f /etc/logrotate.conf 2>/dev/null || true
    
    # Clean temporary files
    echo "🗑️  Cleaning temporary files..."
    as_root find /tmp -type f -atime +7 -delete 2>/dev/null || true
    as_root find /var/tmp -type f -atime +7 -delete 2>/dev/null || true
    
    # Update locate database
    echo "🔍 Updating locate database..."
    as_root updatedb 2>/dev/null || true
    
    # Backup cleanup if backup system is available
    if command -v backup_cleanup >/dev/null 2>&1; then
        echo "💾 Cleaning old backups..."
        backup_cleanup
    fi
    
    echo ""
    echo "✅ Maintenance completed successfully"
    
    log_info "System maintenance completed" "CORE"
}

# System monitoring (daemon mode)
core_monitor() {
    local daemon_mode="${1:-false}"
    local interval="${2:-300}"  # 5 minutes default
    
    if [[ "$daemon_mode" == "true" ]] || [[ "$daemon_mode" == "--daemon" ]]; then
        log_info "Starting system monitor in daemon mode (interval: ${interval}s)" "CORE"
        
        while true; do
            # Log system status
            if command -v log_system_status >/dev/null 2>&1; then
                log_system_status "MONITOR"
            fi
            
            # Check for critical issues
            local load_avg
            load_avg=$(uptime | awk '{print $(NF-2)}' | sed 's/,//')
            
            if (( $(echo "$load_avg > 10" | bc -l) )); then
                log_warn "High system load detected: $load_avg" "MONITOR"
            fi
            
            # Check disk space
            local disk_usage
            disk_usage=$(df / | awk 'NR==2{print $5}' | sed 's/%//')
            
            if [[ $disk_usage -gt 90 ]]; then
                log_warn "High disk usage detected: ${disk_usage}%" "MONITOR"
            fi
            
            # Check memory usage
            local memory_usage
            memory_usage=$(free | awk 'NR==2{printf "%.0f", $3*100/$2}')
            
            if [[ $memory_usage -gt 90 ]]; then
                log_warn "High memory usage detected: ${memory_usage}%" "MONITOR"
            fi
            
            sleep "$interval"
        done
    else
        # One-time monitoring check
        core_status
    fi
}

# Package installation wrapper
core_install() {
    local packages=("$@")
    
    if [[ ${#packages[@]} -eq 0 ]]; then
        log_error "No packages specified for installation" "CORE"
        return 1
    fi
    
    log_info "Installing packages: ${packages[*]}" "CORE"
    pkg_install "${packages[@]}"
}

# Configuration management
core_config() {
    local action="${1:-show}"
    local key="${2:-}"
    local value="${3:-}"
    
    case "$action" in
        "show"|"get")
            if [[ -n "$key" ]]; then
                jb_config_get "$key"
            else
                echo "JB-VPS Configuration:"
                echo "===================="
                local config_file="${JB_CONFIG_FILE:-$JB_DIR/config/jb-vps.conf}"
                if [[ -f "$config_file" ]]; then
                    cat "$config_file"
                else
                    echo "No configuration file found"
                fi
            fi
            ;;
        "set")
            if [[ -z "$key" ]] || [[ -z "$value" ]]; then
                log_error "Both key and value required for set operation" "CORE"
                return 1
            fi
            jb_config_set "$key" "$value"
            log_info "Configuration updated: $key=$value" "CORE"
            ;;
        *)
            log_error "Unknown config action: $action" "CORE"
            echo "Usage: jb config [show|get|set] [key] [value]"
            return 1
            ;;
    esac
}

# Self-update functionality
core_self_update() {
    log_info "Updating JB-VPS to latest version" "CORE"
    
    local current_dir="$PWD"
    cd "$JB_DIR"
    
    # Check if we're in a git repository
    if [[ -d ".git" ]]; then
        log_info "Pulling latest changes from git repository" "CORE"
        git fetch origin
        git pull origin main || git pull origin master
        
        # Re-link the jb command
        if [[ -f "/usr/local/bin/jb" ]]; then
            log_info "Re-linking jb command" "CORE"
            as_root ln -sf "$JB_DIR/bin/jb" "/usr/local/bin/jb"
        fi
        
        log_info "JB-VPS updated successfully" "CORE"
    else
        log_warn "Not in a git repository, cannot auto-update" "CORE"
        log_info "To update manually, re-run the installer from the latest code" "CORE"
    fi
    
    cd "$current_dir"
}

# Register core commands with categories (matching CLINE spec)
jb_register "init" core_bootstrap "Full everyday setup on a fresh VPS" "core"
jb_register "self:update" core_self_update "Pull latest and re-link" "core"
jb_register "harden" core_harden "Apply security hardening (optional)" "security"
jb_register "info" core_info "Display detailed system information" "system"
jb_register "status" core_status "Show comprehensive system status" "system"
jb_register "maintenance" core_maintenance "Perform system maintenance tasks" "maintenance"
jb_register "monitor" core_monitor "Monitor system health (use --daemon for background)" "monitoring"
jb_register "install" core_install "Install system packages" "system"
jb_register "config" core_config "Manage JB-VPS configuration" "config"

# Legacy aliases for backward compatibility
jb_register "bootstrap" core_bootstrap "Bootstrap/initialize a fresh VPS (legacy)" "core"

# System doctor: checks and auto-fixes common issues
core_doctor() {
    local preview=false
    if [[ "${1:-}" == "--preview" ]]; then
        preview=true
    fi

    local repo_dir="${JB_DIR}"
    local launcher="/usr/local/bin/jb"
    local target="$repo_dir/bin/jb"
    local profile="/etc/profile.d/jb-dir.sh"
    local log_dir="/var/log/jb-vps"
    local state_dir="/var/lib/jb-vps"
    local log_files=("jb-vps.log" "audit.log" "error.log")
    local desired_user="jb"
    local desired_group="jb"

    local summary=()
    local errors=0

    run_or_preview() {
        if [[ $preview == true ]]; then
            echo "[PREVIEW] Would run: $*"
            return 0
        fi
        "$@"
    }

    as_root_or_preview() {
        if [[ $preview == true ]]; then
            echo "[PREVIEW] Would run as root: $*"
            return 0
        fi
        as_root "$@"
    }

    # 1) Launcher symlink
    {
        local status
        local current_target=""
        if [[ -L "$launcher" ]]; then
            current_target="$(readlink -f "$launcher" 2>/dev/null || true)"
        fi
        if [[ -L "$launcher" && "$current_target" == "$target" ]]; then
            status="OK"
        else
            if [[ $preview == true ]]; then
                status="WOULD FIX"
            else
                as_root_or_preview rm -f "$launcher" || true
                if as_root ln -s "$target" "$launcher" 2>/dev/null; then
                    as_root chmod 0755 "$target" 2>/dev/null || true
                    status="FIXED"
                else
                    status="ERROR"
                    ((errors++))
                fi
            fi
        fi
        summary+=("Launcher symlink: $status -> $launcher → $target")
    }

    # 2) JB_DIR persisted
    {
        local status
        local want_content="# managed by jb\nexport JB_DIR=\"$repo_dir\"\n"
        local have_ok=false
        if [[ -f "$profile" ]]; then
            if grep -q "^export JB_DIR=\"$repo_dir\"$" "$profile"; then
                have_ok=true
            fi
        fi
        if [[ "$have_ok" == true ]]; then
            status="OK"
        else
            if [[ $preview == true ]]; then
                status="WOULD FIX"
            else
                if printf "%b" "$want_content" | as_root tee "$profile" >/dev/null; then
                    status="FIXED"
                else
                    status="ERROR"
                    ((errors++))
                fi
            fi
        fi
        summary+=("JB_DIR profile: $status -> $profile")
    }

    # 3) Log dir/files
    {
        local status
        local changed=false
        # Ensure directory
        if [[ ! -d "$log_dir" ]]; then
            as_root_or_preview mkdir -p "$log_dir" || true
            changed=true
        fi
        # Permissions on dir
        if [[ -d "$log_dir" ]]; then
            # shellcheck disable=SC2012
            if [[ $(stat -c %a "$log_dir" 2>/dev/null || echo "") != "755" ]]; then
                as_root_or_preview chmod 0755 "$log_dir" || true
                changed=true
            fi
        fi
        # Files + perms + ownership
        for f in "${log_files[@]}"; do
            local path="$log_dir/$f"
            if [[ ! -f "$path" ]]; then
                as_root_or_preview touch "$path" || true
                changed=true
            fi
            if [[ $(stat -c %a "$path" 2>/dev/null || echo "") != "644" ]]; then
                as_root_or_preview chmod 0644 "$path" || true
                changed=true
            fi
            # ownership (best effort)
            if id "$desired_user" >/dev/null 2>&1; then
                as_root_or_preview chown "$desired_user:$desired_group" "$path" || true
            fi
        done
        # Directory ownership (best effort)
        if id "$desired_user" >/dev/null 2>&1; then
            as_root_or_preview chown -R "$desired_user:$desired_group" "$log_dir" || true
        fi
        # Decide status for logs
        if [[ $preview == true ]]; then
            status="WOULD FIX"
        else
            status=$([[ "$changed" == true ]] && echo "FIXED" || echo "OK")
        fi
        summary+=("Log directory: $status -> $log_dir (jb-vps.log, audit.log, error.log)")
    }

    # 4) State dir
    {
        local status
        local changed=false
        if [[ ! -d "$state_dir" ]]; then
            as_root_or_preview mkdir -p "$state_dir" || true
            changed=true
        fi
        if [[ -d "$state_dir" ]]; then
            if [[ $(stat -c %a "$state_dir" 2>/dev/null || echo "") != "755" ]]; then
                as_root_or_preview chmod 0755 "$state_dir" || true
                changed=true
            fi
        fi
        if [[ $preview == true ]]; then
            status="WOULD FIX"
        else
            status=$([[ "$changed" == true ]] && echo "FIXED" || echo "OK")
        fi
        summary+=("State directory: $status -> $state_dir")
    }

    echo "JB Doctor Summary"
    echo "=================="
    for line in "${summary[@]}"; do
        echo "$line"
    done

    if [[ $errors -gt 0 && $preview == false ]]; then
        return 1
    fi
}

# Register doctor command
jb_register "doctor" core_doctor "Check and auto-fix common JB-VPS issues" "system"

# Initialize core plugin
core_plugin_init
