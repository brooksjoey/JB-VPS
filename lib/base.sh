#!/usr/bin/env bash
# Enhanced base library for JB-VPS with enterprise-grade features
# Provides core functionality, error handling, and system integration

set -euo pipefail

# Global configuration
declare -g JB_DIR="${JB_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
declare -g JB_VERSION="${JB_VERSION:-2.0.0}"
declare -g JB_SESSION_ID="${JB_SESSION_ID:-$(date +%s)-$$}"
declare -g JB_DEBUG="${JB_DEBUG:-false}"
declare -g JB_QUIET="${JB_QUIET:-false}"
declare -g JB_DRY_RUN="${JB_DRY_RUN:-false}"

# Command registry
declare -A JB_CMDS_FUNC
declare -A JB_CMDS_HELP
declare -A JB_CMDS_CATEGORY

# Load enterprise libraries
source_lib() {
    local lib="$1"
    local lib_path="$JB_DIR/lib/$lib.sh"
    
    if [[ -f "$lib_path" ]]; then
        source "$lib_path"
        return 0
    else
        echo "Warning: Library $lib not found at $lib_path" >&2
        return 1
    fi
}

# Load core libraries
source_lib "logging" || true
source_lib "validation" || true
source_lib "backup" || true

# Initialize enterprise features
jb_init() {
    # Initialize logging system
    if command -v log_init >/dev/null 2>&1; then
        log_init "${JB_LOG_DIR:-/var/log/jb-vps}"
        log_info "JB-VPS v$JB_VERSION initialized" "SYSTEM"
        log_audit "INIT" "system" "SUCCESS" "version=$JB_VERSION,session=$JB_SESSION_ID"
    fi
    
    # Initialize backup system
    if command -v backup_init >/dev/null 2>&1; then
        backup_init
    fi
    
    # Set up error handling
    trap 'jb_error_handler $? $LINENO $BASH_LINENO "$BASH_COMMAND" "${FUNCNAME[*]}" "${BASH_SOURCE[*]}"' ERR
    
    # Set up cleanup on exit
    trap 'jb_cleanup' EXIT
}

# Enhanced command registration with categories
jb_register() {
    local cmd="$1"
    local func="$2"
    local help="$3"
    local category="${4:-general}"
    
    JB_CMDS_FUNC["$cmd"]="$func"
    JB_CMDS_HELP["$cmd"]="$help"
    JB_CMDS_CATEGORY["$cmd"]="$category"
    
    if command -v log_debug >/dev/null 2>&1; then
        log_debug "Registered command: $cmd -> $func" "REGISTRY"
    fi
}

# Enhanced help system with categories
jb_help() {
    local category="${1:-all}"
    
    echo "JB-VPS v$JB_VERSION — Enterprise Linux VPS Automation"
    echo "Usage: jb <command> [args]"
    echo ""
    
    if [[ "$category" == "all" ]]; then
        # Group commands by category
        declare -A categories
        for cmd in "${!JB_CMDS_FUNC[@]}"; do
            local cat="${JB_CMDS_CATEGORY[$cmd]:-general}"
            categories["$cat"]+="$cmd "
        done
        
        for cat in $(printf '%s\n' "${!categories[@]}" | sort); do
            echo "=== ${cat^^} COMMANDS ==="
            for cmd in ${categories[$cat]}; do
                printf "  %-20s %s\n" "$cmd" "${JB_CMDS_HELP[$cmd]}"
            done
            echo ""
        done
    else
        echo "=== ${category^^} COMMANDS ==="
        for cmd in "${!JB_CMDS_FUNC[@]}"; do
            if [[ "${JB_CMDS_CATEGORY[$cmd]:-general}" == "$category" ]]; then
                printf "  %-20s %s\n" "$cmd" "${JB_CMDS_HELP[$cmd]}"
            fi
        done | sort
    fi
    
    echo "Use 'jb help <category>' to see commands in a specific category"
    echo "Available categories: $(printf '%s ' "${!categories[@]}" | tr ' ' '\n' | sort | tr '\n' ' ')"
}

# Enhanced logging functions (fallback if logging.sh not available)
if ! command -v log_info >/dev/null 2>&1; then
    log() { printf "\033[36m[JB]\033[0m %s\n" "$*"; }
    log_info() { log "$1"; }
    log_warn() { printf "\033[33m[!]\033[0m %s\n" "$*"; }
    log_error() { printf "\033[31m[x]\033[0m %s\n" "$*" >&2; }
    log_debug() { [[ "$JB_DEBUG" == "true" ]] && printf "\033[37m[DEBUG]\033[0m %s\n" "$*" >&2; }
fi

# Legacy compatibility
log() { log_info "$1" "MAIN"; }
warn() { log_warn "$1" "MAIN"; }
die() { log_error "$1" "MAIN"; exit 1; }

# Enhanced error handling
jb_error_handler() {
    local exit_code="$1"
    local line_number="$2"
    local bash_lineno="$3"
    local last_command="$4"
    local function_stack="$5"
    local source_stack="$6"
    
    if command -v log_error_context >/dev/null 2>&1; then
        log_error_context "Command failed: $last_command" "$exit_code" "$line_number" "${function_stack%% *}" "${source_stack%% *}"
    else
        log_error "Command failed: $last_command (exit code: $exit_code, line: $line_number)"
    fi
    
    # Don't exit on error in interactive mode
    if [[ -t 0 ]]; then
        return 0
    fi
}

# Cleanup function
jb_cleanup() {
    local exit_code=$?
    
    if command -v log_info >/dev/null 2>&1; then
        if [[ $exit_code -eq 0 ]]; then
            log_info "JB-VPS session completed successfully" "SYSTEM"
        else
            log_error "JB-VPS session ended with errors (exit code: $exit_code)" "SYSTEM"
        fi
        log_audit "EXIT" "system" "$([ $exit_code -eq 0 ] && echo SUCCESS || echo FAILURE)" "exit_code=$exit_code"
    fi
}

# Enhanced dependency checking
need() {
    local cmd="$1"
    local package="${2:-$cmd}"
    local required="${3:-true}"
    
    if command -v "$cmd" >/dev/null 2>&1; then
        log_debug "Dependency satisfied: $cmd" "DEPS"
        return 0
    fi
    
    if [[ "$required" == "true" ]]; then
        log_error "Missing required dependency: $cmd" "DEPS"
        log_info "Try installing with: jb install $package" "DEPS"
        return 1
    else
        log_warn "Optional dependency missing: $cmd" "DEPS"
        return 1
    fi
}

# Enhanced privilege escalation with audit logging
as_root() {
    if [[ $EUID -eq 0 ]]; then
        if command -v log_audit >/dev/null 2>&1; then
            log_audit "EXEC_ROOT" "$*" "SUCCESS" "already_root=true"
        fi
        "$@"
    else
        if command -v log_audit >/dev/null 2>&1; then
            log_audit "EXEC_ROOT" "$*" "ATTEMPT" "user=$USER"
        fi
        
        if sudo -n "$@" 2>/dev/null; then
            if command -v log_audit >/dev/null 2>&1; then
                log_audit "EXEC_ROOT" "$*" "SUCCESS" "method=sudo_nopasswd"
            fi
        else
            log_warn "Requesting elevated privileges for: $*" "SUDO"
            if sudo "$@"; then
                if command -v log_audit >/dev/null 2>&1; then
                    log_audit "EXEC_ROOT" "$*" "SUCCESS" "method=sudo_passwd"
                fi
            else
                if command -v log_audit >/dev/null 2>&1; then
                    log_audit "EXEC_ROOT" "$*" "FAILURE" "method=sudo_denied"
                fi
                return 1
            fi
        fi
    fi
}

# Enhanced OS detection with detailed information
detect_os() {
    local detail="${1:-false}"
    
    if [[ ! -f /etc/os-release ]]; then
        echo "unknown"
        return 1
    fi
    
    source /etc/os-release
    
    if [[ "$detail" == "true" ]]; then
        echo "${ID:-unknown}:${VERSION_ID:-unknown}:${PRETTY_NAME:-unknown}"
    else
        echo "${ID:-unknown}"
    fi
}

# Enhanced package installation with validation and logging
pkg_install() {
    local packages=("$@")
    local os
    os="$(detect_os)"
    
    log_info "Installing packages: ${packages[*]}" "PKG"
    log_audit "PKG_INSTALL" "${packages[*]}" "ATTEMPT" "os=$os"
    
    # Validate package names
    for pkg in "${packages[@]}"; do
        if command -v validate_safe_filename >/dev/null 2>&1; then
            if ! validate_safe_filename "$pkg" "package name"; then
                log_error "Invalid package name: $pkg" "PKG"
                return 1
            fi
        fi
    done
    
    local start_time
    start_time=$(date +%s.%N)
    
    case "$os" in
        debian|ubuntu)
            as_root apt-get update -y || return 1
            as_root apt-get install -y "${packages[@]}" || return 1
            ;;
        fedora)
            as_root dnf install -y "${packages[@]}" || return 1
            ;;
        centos|rhel)
            as_root yum install -y "${packages[@]}" || return 1
            ;;
        arch)
            as_root pacman -Sy --noconfirm "${packages[@]}" || return 1
            ;;
        *)
            log_error "Unsupported OS for package installation: $os" "PKG"
            return 1
            ;;
    esac
    
    local end_time
    end_time=$(date +%s.%N)
    
    if command -v log_performance >/dev/null 2>&1; then
        log_performance "pkg_install" "$start_time" "$end_time" "packages=${#packages[@]},os=$os"
    fi
    
    log_audit "PKG_INSTALL" "${packages[*]}" "SUCCESS" "os=$os"
    log_info "Package installation completed successfully" "PKG"
}

# System information gathering
get_system_info() {
    local format="${1:-json}"
    
    local hostname
    hostname=$(hostname)
    local kernel
    kernel=$(uname -r)
    local arch
    arch=$(uname -m)
    local os_info
    os_info=$(detect_os true)
    local uptime
    uptime=$(uptime -p 2>/dev/null || uptime)
    local load_avg
    load_avg=$(uptime | awk -F'load average:' '{print $2}' | xargs)
    local memory_total
    memory_total=$(free -h | awk 'NR==2{print $2}')
    local memory_used
    memory_used=$(free -h | awk 'NR==2{print $3}')
    local disk_usage
    disk_usage=$(df -h / | awk 'NR==2{print $5}')
    
    case "$format" in
        "json")
            if command -v jq >/dev/null 2>&1; then
                jq -n \
                    --arg hostname "$hostname" \
                    --arg kernel "$kernel" \
                    --arg arch "$arch" \
                    --arg os "$os_info" \
                    --arg uptime "$uptime" \
                    --arg load "$load_avg" \
                    --arg mem_total "$memory_total" \
                    --arg mem_used "$memory_used" \
                    --arg disk "$disk_usage" \
                    --arg session "$JB_SESSION_ID" \
                    --arg version "$JB_VERSION" \
                    '{
                        hostname: $hostname,
                        kernel: $kernel,
                        architecture: $arch,
                        os: $os,
                        uptime: $uptime,
                        load_average: $load,
                        memory: {total: $mem_total, used: $mem_used},
                        disk_usage: $disk,
                        jb_session: $session,
                        jb_version: $version,
                        timestamp: now | strftime("%Y-%m-%d %H:%M:%S")
                    }'
            else
                echo "{\"hostname\":\"$hostname\",\"kernel\":\"$kernel\",\"os\":\"$os_info\"}"
            fi
            ;;
        "text")
            echo "=== SYSTEM INFORMATION ==="
            echo "Hostname: $hostname"
            echo "Kernel: $kernel"
            echo "Architecture: $arch"
            echo "OS: $os_info"
            echo "Uptime: $uptime"
            echo "Load Average: $load_avg"
            echo "Memory: $memory_used / $memory_total"
            echo "Disk Usage: $disk_usage"
            echo "JB-VPS Version: $JB_VERSION"
            echo "Session ID: $JB_SESSION_ID"
            ;;
    esac
}

# Configuration management
jb_config_get() {
    local key="$1"
    local default="${2:-}"
    local config_file="${JB_CONFIG_FILE:-$JB_DIR/config/jb-vps.conf}"
    
    if [[ -f "$config_file" ]]; then
        grep "^$key=" "$config_file" 2>/dev/null | cut -d'=' -f2- | head -1 || echo "$default"
    else
        echo "$default"
    fi
}

jb_config_set() {
    local key="$1"
    local value="$2"
    local config_file="${JB_CONFIG_FILE:-$JB_DIR/config/jb-vps.conf}"
    
    mkdir -p "$(dirname "$config_file")"
    
    if [[ -f "$config_file" ]]; then
        # Update existing key or add new one
        if grep -q "^$key=" "$config_file"; then
            sed -i "s/^$key=.*/$key=$value/" "$config_file"
        else
            echo "$key=$value" >> "$config_file"
        fi
    else
        echo "$key=$value" > "$config_file"
    fi
    
    log_audit "CONFIG_SET" "$key" "SUCCESS" "value=$value"
}

# Dry run support
jb_execute() {
    local description="$1"
    shift
    
    if [[ "$JB_DRY_RUN" == "true" ]]; then
        log_info "[DRY RUN] Would execute: $description" "DRYRUN"
        log_debug "Command: $*" "DRYRUN"
        return 0
    else
        log_debug "Executing: $description" "EXEC"
        "$@"
    fi
}

# State management for idempotent operations
jb_state_get() {
    local key="$1"
    local state_file="${JB_STATE_FILE:-$JB_DIR/.state/jb-vps.state}"
    
    if [[ -f "$state_file" ]]; then
        grep "^$key=" "$state_file" 2>/dev/null | cut -d'=' -f2- | head -1
    fi
}

jb_state_set() {
    local key="$1"
    local value="$2"
    local state_file="${JB_STATE_FILE:-$JB_DIR/.state/jb-vps.state}"
    
    mkdir -p "$(dirname "$state_file")"
    
    if [[ -f "$state_file" ]]; then
        if grep -q "^$key=" "$state_file"; then
            sed -i "s/^$key=.*/$key=$value/" "$state_file"
        else
            echo "$key=$value" >> "$state_file"
        fi
    else
        echo "$key=$value" > "$state_file"
    fi
}

# Initialize on source
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    jb_init
fi

# Export enhanced functions
export -f jb_register jb_help log log_info log_warn log_error log_debug
export -f need as_root detect_os pkg_install get_system_info
export -f jb_config_get jb_config_set jb_execute jb_state_get jb_state_set
export -f jb_error_handler jb_cleanup source_lib
