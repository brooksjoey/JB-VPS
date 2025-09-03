#!/usr/bin/env bash
# Enterprise-grade logging system for JB-VPS
# Provides structured logging with rotation, filtering, and audit trails

set -euo pipefail

# Logging configuration
declare -g LOG_DIR="${JB_LOG_DIR:-/var/log/jb-vps}"
declare -g LOG_FILE="${LOG_DIR}/jb-vps.log"
declare -g AUDIT_FILE="${LOG_DIR}/audit.log"
declare -g ERROR_FILE="${LOG_DIR}/error.log"
declare -g LOG_LEVEL="${JB_LOG_LEVEL:-INFO}"
declare -g LOG_MAX_SIZE="${JB_LOG_MAX_SIZE:-10M}"
declare -g LOG_MAX_FILES="${JB_LOG_MAX_FILES:-5}"

# Log levels (numeric for comparison)
declare -A LOG_LEVELS=(
    ["TRACE"]=0
    ["DEBUG"]=1
    ["INFO"]=2
    ["WARN"]=3
    ["ERROR"]=4
    ["FATAL"]=5
)

# Color codes for console output
declare -A LOG_COLORS=(
    ["TRACE"]='\033[0;37m'   # Light gray
    ["DEBUG"]='\033[0;36m'   # Cyan
    ["INFO"]='\033[0;32m'    # Green
    ["WARN"]='\033[1;33m'    # Yellow
    ["ERROR"]='\033[0;31m'   # Red
    ["FATAL"]='\033[1;31m'   # Bold red
    ["RESET"]='\033[0m'      # Reset
)

# Initialize logging system
log_init() {
    local log_dir="${1:-${LOG_DIR:-/var/log/jb-vps}}"
    
    # Create log directory if it doesn't exist
    if [[ ! -d "$log_dir" ]]; then
        if [[ $EUID -eq 0 ]]; then
            mkdir -p "$log_dir"
            chmod 750 "$log_dir"
        else
            # Use user's home directory if not root
            LOG_DIR="${HOME:-/tmp}/.jb-vps/logs"
            LOG_FILE="$LOG_DIR/jb-vps.log"
            AUDIT_FILE="$LOG_DIR/audit.log"
            ERROR_FILE="$LOG_DIR/error.log"
            mkdir -p "$LOG_DIR"
        fi
    fi
    
    # Initialize log files with proper permissions
    touch "${LOG_FILE:-}" "${AUDIT_FILE:-}" "${ERROR_FILE:-}"
    chmod 640 "${LOG_FILE:-}" "${AUDIT_FILE:-}" "${ERROR_FILE:-}" 2>/dev/null || true
    
    # Log system initialization
    log_write "INFO" "SYSTEM" "Logging system initialized" "log_dir=${LOG_DIR:-}"
}

# Core logging function
log_write() {
    local level="${1:-INFO}"
    local component="${2:-MAIN}"
    local message="${3:-}"
    local metadata="${4:-}"
    
    # Check if log level is enabled
    local current_level_num="${LOG_LEVELS[${LOG_LEVEL:-INFO}]:-2}"
    local message_level_num="${LOG_LEVELS[${level:-INFO}]:-2}"
    
    if [[ $message_level_num -lt $current_level_num ]]; then
        return 0
    fi
    
    # Generate timestamp
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Generate session ID if not set
    if [[ -z "${JB_SESSION_ID:-}" ]]; then
        export JB_SESSION_ID="$(date +%s)-$$"
    fi
    
    # Format log entry
    local log_entry="[$timestamp] [${level}] [${component}] [${JB_SESSION_ID:-}] ${message}"
    if [[ -n "$metadata" ]]; then
        log_entry="$log_entry | $metadata"
    fi
    
    # Write to appropriate log files
    echo "$log_entry" >> "${LOG_FILE:-}"
    
    # Write errors to error log
    if [[ "${level}" == "ERROR" || "${level}" == "FATAL" ]]; then
        echo "$log_entry" >> "${ERROR_FILE:-}"
    fi
    
    # Console output with colors (if terminal supports it)
    if [[ -t 1 ]]; then
        local color="${LOG_COLORS[${level}]:-}"
        local reset="${LOG_COLORS[RESET]:-}"
        printf "%b[%s] [%s] %s%b\n" "${color:-}" "${level}" "${component}" "${message}" "${reset:-}"
    else
        printf "[%s] [%s] %s\n" "${level}" "${component}" "${message}"
    fi
    
    # Rotate logs if needed
    log_rotate_if_needed
}

# Convenience logging functions
log_trace() { 
    local message="${1:-}"
    local component="${2:-MAIN}"
    local metadata="${3:-}"
    log_write "TRACE" "$component" "$message" "$metadata"
}

log_debug() { 
    local message="${1:-}"
    local component="${2:-MAIN}"
    local metadata="${3:-}"
    log_write "DEBUG" "$component" "$message" "$metadata"
}

log_info() { 
    local message="${1:-}"
    local component="${2:-MAIN}"
    local metadata="${3:-}"
    log_write "INFO" "$component" "$message" "$metadata"
}

log_warn() { 
    local message="${1:-}"
    local component="${2:-MAIN}"
    local metadata="${3:-}"
    log_write "WARN" "$component" "$message" "$metadata"
}

log_error() { 
    local message="${1:-}"
    local component="${2:-MAIN}"
    local metadata="${3:-}"
    log_write "ERROR" "$component" "$message" "$metadata"
}

log_fatal() { 
    local message="${1:-}"
    local component="${2:-MAIN}"
    local metadata="${3:-}"
    log_write "FATAL" "$component" "$message" "$metadata"
}

# Audit logging for security-sensitive operations
log_audit() {
    local action="${1:-}"
    local resource="${2:-}"
    local result="${3:-}"
    local details="${4:-}"
    
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    local user="${SUDO_USER:-${USER:-$(id -un 2>/dev/null || echo unknown)}}"
    local real_user="${USER:-$(id -un 2>/dev/null || echo unknown)}"
    local pid="$$"
    local tty="${SSH_TTY:-$(tty 2>/dev/null || echo 'unknown')}"
    
    local audit_entry="[$timestamp] USER=$user REAL_USER=$real_user PID=$pid TTY=$tty ACTION=$action RESOURCE=$resource RESULT=$result"
    if [[ -n "$details" ]]; then
        audit_entry="$audit_entry DETAILS=$details"
    fi
    
    echo "$audit_entry" >> "${AUDIT_FILE:-}"
    log_info "Audit: $action on $resource -> $result" "AUDIT" "user=$user,resource=$resource"
}

# Log rotation
log_rotate_if_needed() {
    local file="${LOG_FILE:-}"
    
    # Check if log file exists and is larger than max size
    if [[ -n "$file" && -f "$file" ]]; then
        local size
        size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null || echo 0)
        local max_bytes
        
        # Convert size notation to bytes
        case "${LOG_MAX_SIZE:-10M}" in
            *K|*k) max_bytes=$(( ${LOG_MAX_SIZE%[Kk]} * 1024 )) ;;
            *M|*m) max_bytes=$(( ${LOG_MAX_SIZE%[Mm]} * 1024 * 1024 )) ;;
            *G|*g) max_bytes=$(( ${LOG_MAX_SIZE%[Gg]} * 1024 * 1024 * 1024 )) ;;
            *) max_bytes="${LOG_MAX_SIZE:-10485760}" ;;
        esac
        
        if [[ $size -gt $max_bytes ]]; then
            log_rotate "$file"
        fi
    fi
}

log_rotate() {
    local file="$1"
    local base_name="${file%.*}"
    local extension="${file##*.}"
    
    # Rotate existing files
    local max_files="${LOG_MAX_FILES:-5}"
    for ((i=max_files-1; i>=1; i--)); do
        local old_file="${base_name}.${i}.${extension}"
        local new_file="${base_name}.$((i+1)).${extension}"
        
        if [[ -f "$old_file" ]]; then
            if [[ $i -eq $((max_files-1)) ]]; then
                rm -f "$old_file"  # Remove oldest file
            else
                mv "$old_file" "$new_file"
            fi
        fi
    done
    
    # Move current file to .1
    if [[ -f "$file" ]]; then
        mv "$file" "${base_name}.1.${extension}"
        touch "$file"
        chmod 640 "$file" 2>/dev/null || true
    fi
    
    log_info "Log rotated: $file" "LOGGING"
}

# Performance logging
log_performance() {
    local operation="${1:-}"
    local start_time="${2:-}"
    local end_time="${3:-$(date +%s.%N)}"
    local metadata="${4:-}"
    
    local duration
    duration=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "unknown")
    
    log_info "Performance: $operation completed in ${duration}s" "PERF" "operation=$operation,duration=${duration}s,$metadata"
}

# Error context logging
log_error_context() {
    local error_msg="${1:-}"
    local exit_code="${2:-$?}"
    local line_number="${3:-${BASH_LINENO[1]:-unknown}}"
    local function_name="${4:-${FUNCNAME[2]:-main}}"
    local script_name="${5:-${BASH_SOURCE[2]:-unknown}}"
    
    local context="script=$script_name,function=$function_name,line=$line_number,exit_code=$exit_code"
    log_error "$error_msg" "ERROR" "$context"
    
    # Also log stack trace if available
    if [[ ${#BASH_SOURCE[@]} -gt 1 ]]; then
        log_debug "Stack trace:" "ERROR"
        for ((i=1; i<${#BASH_SOURCE[@]}; i++)); do
            log_debug "  ${BASH_SOURCE[i]}:${BASH_LINENO[i-1]} in ${FUNCNAME[i]}" "ERROR"
        done
    fi
}

# Structured logging for complex data
log_structured() {
    local level="$1"
    local component="$2"
    local event="$3"
    shift 3
    
    local metadata=""
    while [[ $# -gt 0 ]]; do
        if [[ -n "$metadata" ]]; then
            metadata="$metadata,"
        fi
        metadata="$metadata$1"
        shift
    done
    
    log_write "$level" "$component" "$event" "$metadata"
}

# Log system status
log_system_status() {
    local component="${1:-SYSTEM}"
    
    local load_avg
    load_avg=$(uptime | awk -F'load average:' '{print $2}' | xargs)
    
    local memory_usage
    memory_usage=$(free | awk 'NR==2{printf "%.1f%%", $3*100/$2}')
    
    local disk_usage
    disk_usage=$(df / | awk 'NR==2{print $5}')
    
    log_info "System status check" "$component" "load=$load_avg,memory=$memory_usage,disk=$disk_usage"
}

# Initialize logging on source
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    # Only initialize if being sourced, not executed directly
    log_init "${LOG_DIR}"
fi

# Export functions for use in other scripts
export -f log_init log_write log_trace log_debug log_info log_warn log_error log_fatal
export -f log_audit log_performance log_error_context log_structured log_system_status
