#!/usr/bin/env bash
# Input validation and safety checks for JB-VPS
# Provides comprehensive validation functions for enterprise-grade safety

set -euo pipefail

# Source logging if available
if [[ -f "${JB_DIR:-}/lib/logging.sh" ]]; then
    source "${JB_DIR}/lib/logging.sh"
else
    # Fallback logging functions
    log_error() { echo "ERROR: $1" >&2; }
    log_warn() { echo "WARN: $1" >&2; }
    log_info() { echo "INFO: $1"; }
fi

# Validation configuration
declare -g VALIDATION_STRICT="${JB_VALIDATION_STRICT:-true}"
declare -g VALIDATION_LOG_FAILURES="${JB_VALIDATION_LOG_FAILURES:-true}"

# Common validation patterns
declare -A VALIDATION_PATTERNS=(
    ["email"]="^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$"
    ["domain"]="^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$"
    ["ipv4"]="^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$"
    ["ipv6"]="^([0-9a-fA-F]{1,4}:){7}[0-9a-fA-F]{1,4}$"
    ["port"]="^([1-9][0-9]{0,3}|[1-5][0-9]{4}|6[0-4][0-9]{3}|65[0-4][0-9]{2}|655[0-2][0-9]|6553[0-5])$"
    ["username"]="^[a-zA-Z][a-zA-Z0-9_-]{2,31}$"
    ["filename"]="^[a-zA-Z0-9._-]+$"
    ["path"]="^[a-zA-Z0-9._/-]+$"
    ["url"]="^https?://[a-zA-Z0-9.-]+(/.*)?$"
)

# Core validation function
validate() {
    local value="$1"
    local type="$2"
    local field_name="${3:-field}"
    local required="${4:-true}"
    
    # Check if value is empty
    if [[ -z "$value" ]]; then
        if [[ "$required" == "true" ]]; then
            validation_error "$field_name is required but was empty"
            return 1
        else
            return 0  # Optional field, empty is OK
        fi
    fi
    
    # Validate based on type
    case "$type" in
        "email")
            validate_email "$value" "$field_name"
            ;;
        "domain")
            validate_domain "$value" "$field_name"
            ;;
        "ip"|"ipv4")
            validate_ipv4 "$value" "$field_name"
            ;;
        "ipv6")
            validate_ipv6 "$value" "$field_name"
            ;;
        "port")
            validate_port "$value" "$field_name"
            ;;
        "username")
            validate_username "$value" "$field_name"
            ;;
        "filename")
            validate_filename "$value" "$field_name"
            ;;
        "path")
            validate_path "$value" "$field_name"
            ;;
        "url")
            validate_url "$value" "$field_name"
            ;;
        "number")
            validate_number "$value" "$field_name"
            ;;
        "range")
            local min="${5:-}"
            local max="${6:-}"
            validate_range "$value" "$min" "$max" "$field_name"
            ;;
        "length")
            local min_len="${5:-0}"
            local max_len="${6:-255}"
            validate_length "$value" "$min_len" "$max_len" "$field_name"
            ;;
        "regex")
            local pattern="${5:-}"
            validate_regex "$value" "$pattern" "$field_name"
            ;;
        *)
            validation_error "Unknown validation type: $type"
            return 1
            ;;
    esac
}

# Specific validation functions
validate_email() {
    local email="$1"
    local field_name="${2:-email}"
    
    if [[ ! "$email" =~ ${VALIDATION_PATTERNS["email"]} ]]; then
        validation_error "$field_name '$email' is not a valid email address"
        return 1
    fi
    
    # Additional checks
    if [[ ${#email} -gt 254 ]]; then
        validation_error "$field_name '$email' is too long (max 254 characters)"
        return 1
    fi
    
    return 0
}

validate_domain() {
    local domain="$1"
    local field_name="${2:-domain}"
    
    if [[ ! "$domain" =~ ${VALIDATION_PATTERNS["domain"]} ]]; then
        validation_error "$field_name '$domain' is not a valid domain name"
        return 1
    fi
    
    # Check length constraints
    if [[ ${#domain} -gt 253 ]]; then
        validation_error "$field_name '$domain' is too long (max 253 characters)"
        return 1
    fi
    
    return 0
}

validate_ipv4() {
    local ip="$1"
    local field_name="${2:-IP address}"
    
    if [[ ! "$ip" =~ ${VALIDATION_PATTERNS["ipv4"]} ]]; then
        validation_error "$field_name '$ip' is not a valid IPv4 address"
        return 1
    fi
    
    return 0
}

validate_ipv6() {
    local ip="$1"
    local field_name="${2:-IPv6 address}"
    
    if [[ ! "$ip" =~ ${VALIDATION_PATTERNS["ipv6"]} ]]; then
        validation_error "$field_name '$ip' is not a valid IPv6 address"
        return 1
    fi
    
    return 0
}

validate_port() {
    local port="$1"
    local field_name="${2:-port}"
    
    if [[ ! "$port" =~ ${VALIDATION_PATTERNS["port"]} ]]; then
        validation_error "$field_name '$port' is not a valid port number (1-65535)"
        return 1
    fi
    
    return 0
}

validate_username() {
    local username="$1"
    local field_name="${2:-username}"
    
    if [[ ! "$username" =~ ${VALIDATION_PATTERNS["username"]} ]]; then
        validation_error "$field_name '$username' is not a valid username (3-32 chars, alphanumeric, underscore, hyphen)"
        return 1
    fi
    
    return 0
}

validate_filename() {
    local filename="$1"
    local field_name="${2:-filename}"
    
    if [[ ! "$filename" =~ ${VALIDATION_PATTERNS["filename"]} ]]; then
        validation_error "$field_name '$filename' contains invalid characters"
        return 1
    fi
    
    # Check for dangerous patterns
    if [[ "$filename" == *".."* ]] || [[ "$filename" == "."* ]]; then
        validation_error "$field_name '$filename' contains dangerous path elements"
        return 1
    fi
    
    return 0
}

validate_path() {
    local path="$1"
    local field_name="${2:-path}"
    
    # Basic path validation
    if [[ ! "$path" =~ ${VALIDATION_PATTERNS["path"]} ]]; then
        validation_error "$field_name '$path' contains invalid characters"
        return 1
    fi
    
    # Check for path traversal attempts
    if [[ "$path" == *".."* ]]; then
        validation_error "$field_name '$path' contains path traversal elements"
        return 1
    fi
    
    return 0
}

validate_url() {
    local url="$1"
    local field_name="${2:-URL}"
    
    if [[ ! "$url" =~ ${VALIDATION_PATTERNS["url"]} ]]; then
        validation_error "$field_name '$url' is not a valid URL"
        return 1
    fi
    
    return 0
}

validate_number() {
    local number="$1"
    local field_name="${2:-number}"
    
    if [[ ! "$number" =~ ^-?[0-9]+(\.[0-9]+)?$ ]]; then
        validation_error "$field_name '$number' is not a valid number"
        return 1
    fi
    
    return 0
}

validate_range() {
    local value="$1"
    local min="$2"
    local max="$3"
    local field_name="${4:-value}"
    
    # First validate it's a number
    if ! validate_number "$value" "$field_name"; then
        return 1
    fi
    
    # Check range
    if [[ -n "$min" ]] && (( $(echo "$value < $min" | bc -l) )); then
        validation_error "$field_name '$value' is below minimum value $min"
        return 1
    fi
    
    if [[ -n "$max" ]] && (( $(echo "$value > $max" | bc -l) )); then
        validation_error "$field_name '$value' is above maximum value $max"
        return 1
    fi
    
    return 0
}

validate_length() {
    local value="$1"
    local min_len="$2"
    local max_len="$3"
    local field_name="${4:-value}"
    
    local length=${#value}
    
    if [[ $length -lt $min_len ]]; then
        validation_error "$field_name is too short (minimum $min_len characters, got $length)"
        return 1
    fi
    
    if [[ $length -gt $max_len ]]; then
        validation_error "$field_name is too long (maximum $max_len characters, got $length)"
        return 1
    fi
    
    return 0
}

validate_regex() {
    local value="$1"
    local pattern="$2"
    local field_name="${3:-value}"
    
    if [[ ! "$value" =~ $pattern ]]; then
        validation_error "$field_name '$value' does not match required pattern"
        return 1
    fi
    
    return 0
}

# File and directory validation
validate_file_exists() {
    local file="$1"
    local field_name="${2:-file}"
    
    if [[ ! -f "$file" ]]; then
        validation_error "$field_name '$file' does not exist or is not a regular file"
        return 1
    fi
    
    return 0
}

validate_dir_exists() {
    local dir="$1"
    local field_name="${2:-directory}"
    
    if [[ ! -d "$dir" ]]; then
        validation_error "$field_name '$dir' does not exist or is not a directory"
        return 1
    fi
    
    return 0
}

validate_file_readable() {
    local file="$1"
    local field_name="${2:-file}"
    
    if [[ ! -r "$file" ]]; then
        validation_error "$field_name '$file' is not readable"
        return 1
    fi
    
    return 0
}

validate_file_writable() {
    local file="$1"
    local field_name="${2:-file}"
    
    if [[ ! -w "$file" ]]; then
        validation_error "$field_name '$file' is not writable"
        return 1
    fi
    
    return 0
}

validate_file_executable() {
    local file="$1"
    local field_name="${2:-file}"
    
    if [[ ! -x "$file" ]]; then
        validation_error "$field_name '$file' is not executable"
        return 1
    fi
    
    return 0
}

# System validation
validate_command_exists() {
    local command="$1"
    local field_name="${2:-command}"
    
    if ! command -v "$command" >/dev/null 2>&1; then
        validation_error "$field_name '$command' is not available on this system"
        return 1
    fi
    
    return 0
}

validate_user_exists() {
    local username="$1"
    local field_name="${2:-user}"
    
    if ! id "$username" >/dev/null 2>&1; then
        validation_error "$field_name '$username' does not exist on this system"
        return 1
    fi
    
    return 0
}

validate_group_exists() {
    local groupname="$1"
    local field_name="${2:-group}"
    
    if ! getent group "$groupname" >/dev/null 2>&1; then
        validation_error "$field_name '$groupname' does not exist on this system"
        return 1
    fi
    
    return 0
}

validate_service_exists() {
    local service="$1"
    local field_name="${2:-service}"
    
    if ! systemctl list-unit-files "$service.service" >/dev/null 2>&1; then
        validation_error "$field_name '$service' is not a valid systemd service"
        return 1
    fi
    
    return 0
}

# Network validation
validate_port_available() {
    local port="$1"
    local field_name="${2:-port}"
    
    if netstat -tuln 2>/dev/null | grep -q ":$port "; then
        validation_error "$field_name $port is already in use"
        return 1
    fi
    
    return 0
}

validate_host_reachable() {
    local host="$1"
    local field_name="${2:-host}"
    local timeout="${3:-5}"
    
    if ! ping -c 1 -W "$timeout" "$host" >/dev/null 2>&1; then
        validation_error "$field_name '$host' is not reachable"
        return 1
    fi
    
    return 0
}

# Security validation
validate_no_shell_injection() {
    local input="$1"
    local field_name="${2:-input}"
    
    # Check for common shell injection patterns
    local dangerous_patterns=(
        ";"
        "&"
        "|"
        "\$("
        "`"
        ">"
        "<"
        "*"
        "?"
        "["
        "]"
        "{"
        "}"
        "\\"
    )
    
    for pattern in "${dangerous_patterns[@]}"; do
        if [[ "$input" == *"$pattern"* ]]; then
            validation_error "$field_name contains potentially dangerous characters: $pattern"
            return 1
        fi
    done
    
    return 0
}

validate_safe_filename() {
    local filename="$1"
    local field_name="${2:-filename}"
    
    # Check basic filename validation first
    if ! validate_filename "$filename" "$field_name"; then
        return 1
    fi
    
    # Additional security checks
    local dangerous_names=(
        "."
        ".."
        "con"
        "prn"
        "aux"
        "nul"
        "com1"
        "com2"
        "com3"
        "com4"
        "com5"
        "com6"
        "com7"
        "com8"
        "com9"
        "lpt1"
        "lpt2"
        "lpt3"
        "lpt4"
        "lpt5"
        "lpt6"
        "lpt7"
        "lpt8"
        "lpt9"
    )
    
    local lower_filename
    lower_filename=$(echo "$filename" | tr '[:upper:]' '[:lower:]')
    
    for dangerous in "${dangerous_names[@]}"; do
        if [[ "$lower_filename" == "$dangerous" ]] || [[ "$lower_filename" == "$dangerous".* ]]; then
            validation_error "$field_name '$filename' is a reserved system name"
            return 1
        fi
    done
    
    return 0
}

# Batch validation
validate_batch() {
    local -n validations=$1
    local errors=()
    
    for validation in "${validations[@]}"; do
        # Parse validation string: "value|type|field_name|required|extra1|extra2"
        IFS='|' read -ra parts <<< "$validation"
        local value="${parts[0]}"
        local type="${parts[1]}"
        local field_name="${parts[2]:-field}"
        local required="${parts[3]:-true}"
        local extra1="${parts[4]:-}"
        local extra2="${parts[5]:-}"
        
        if ! validate "$value" "$type" "$field_name" "$required" "$extra1" "$extra2"; then
            errors+=("$field_name validation failed")
        fi
    done
    
    if [[ ${#errors[@]} -gt 0 ]]; then
        validation_error "Batch validation failed: ${errors[*]}"
        return 1
    fi
    
    return 0
}

# Error handling
validation_error() {
    local message="$1"
    
    if [[ "$VALIDATION_LOG_FAILURES" == "true" ]]; then
        log_error "Validation failed: $message" "VALIDATION"
    fi
    
    if [[ "$VALIDATION_STRICT" == "true" ]]; then
        echo "VALIDATION ERROR: $message" >&2
        return 1
    else
        log_warn "Validation warning: $message" "VALIDATION"
        return 0
    fi
}

# Interactive validation
validate_interactive() {
    local prompt="$1"
    local type="$2"
    local field_name="${3:-input}"
    local required="${4:-true}"
    local default="${5:-}"
    
    local value
    local attempts=0
    local max_attempts=3
    
    while [[ $attempts -lt $max_attempts ]]; do
        if [[ -n "$default" ]]; then
            read -p "$prompt [$default]: " value
            value="${value:-$default}"
        else
            read -p "$prompt: " value
        fi
        
        if validate "$value" "$type" "$field_name" "$required"; then
            echo "$value"
            return 0
        fi
        
        ((attempts++))
        if [[ $attempts -lt $max_attempts ]]; then
            echo "Please try again ($((max_attempts - attempts)) attempts remaining)"
        fi
    done
    
    validation_error "Maximum validation attempts exceeded for $field_name"
    return 1
}

# Export functions for use in other scripts
export -f validate validate_email validate_domain validate_ipv4 validate_ipv6
export -f validate_port validate_username validate_filename validate_path validate_url
export -f validate_number validate_range validate_length validate_regex
export -f validate_file_exists validate_dir_exists validate_file_readable
export -f validate_file_writable validate_file_executable validate_command_exists
export -f validate_user_exists validate_group_exists validate_service_exists
export -f validate_port_available validate_host_reachable validate_no_shell_injection
export -f validate_safe_filename validate_batch validate_interactive validation_error
