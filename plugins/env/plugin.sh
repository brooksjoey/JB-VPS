#!/usr/bin/env bash
# Environment Management Plugin for JB-VPS
# Handles encrypted environment profiles

set -euo pipefail
source "$JB_DIR/lib/base.sh"

ENV_DIR="$JB_DIR/secure/environments"

# Ensure environment directory exists
mkdir -p "$ENV_DIR"

# List available encrypted environment profiles
env_list() {
    log_info "Available encrypted environment profiles:" "ENV"
    
    if [[ ! -d "$ENV_DIR" ]]; then
        log_warn "Environment directory not found: $ENV_DIR" "ENV"
        return 1
    fi
    
    local profiles
    profiles=$(ls -1 "$ENV_DIR"/*.env.gpg 2>/dev/null | sed "s#.*/##; s#\\.env\\.gpg$##" || true)
    
    if [[ -z "$profiles" ]]; then
        echo "No encrypted environment profiles found."
        echo ""
        echo "To create an encrypted profile:"
        echo "  1. Create a .env file with your variables"
        echo "  2. Encrypt it: gpg -c myprofile.env"
        echo "  3. Move to: $ENV_DIR/myprofile.env.gpg"
        echo "  4. Remove the unencrypted file"
        return 0
    fi
    
    echo "$profiles" | while read -r profile; do
        echo "  • $profile"
    done
    
    echo ""
    echo "Use 'jb env:open <name>' to decrypt and load a profile"
}

# Open (decrypt and load) an environment profile
env_open() {
    need gpg
    
    local name="${1:-}"
    
    if [[ -z "$name" ]]; then
        log_error "Usage: jb env:open <name>" "ENV"
        echo ""
        echo "Available profiles:"
        env_list
        return 1
    fi
    
    local env_file="$ENV_DIR/$name.env.gpg"
    
    if [[ ! -f "$env_file" ]]; then
        log_error "Environment profile not found: $name" "ENV"
        echo "Available profiles:"
        env_list
        return 1
    fi
    
    log_info "Decrypting and loading environment profile: $name" "ENV"
    
    # Create a temporary file for decryption (root-only access)
    local temp_file
    temp_file=$(mktemp --mode=600)
    
    # Ensure cleanup on exit
    trap "rm -f '$temp_file'" EXIT
    
    # Decrypt to temporary file
    if ! gpg --quiet --decrypt "$env_file" > "$temp_file" 2>/dev/null; then
        log_error "Failed to decrypt environment profile: $name" "ENV"
        log_error "Check your GPG key and passphrase" "ENV"
        return 1
    fi
    
    # Validate the decrypted content
    if ! grep -q "=" "$temp_file" 2>/dev/null; then
        log_warn "Environment profile appears to be empty or invalid: $name" "ENV"
    fi
    
    # Export variables for current shell session
    log_info "Loading environment variables from profile: $name" "ENV"
    
    # Source the environment file
    set -a  # Automatically export all variables
    source "$temp_file"
    set +a
    
    # Count loaded variables
    local var_count
    var_count=$(grep -c "=" "$temp_file" 2>/dev/null || echo "0")
    
    log_info "Loaded $var_count environment variables from profile: $name" "ENV"
    
    # Clean up
    rm -f "$temp_file"
    trap - EXIT
    
    echo "Environment profile '$name' loaded successfully."
    echo "Variables are now available in this shell session."
}

# Write/decrypt an environment profile to a file
env_write() {
    need gpg
    
    local name="${1:-}"
    local output_file="${2:-}"
    
    if [[ -z "$name" ]] || [[ -z "$output_file" ]]; then
        log_error "Usage: jb env:write <name> <output_file>" "ENV"
        return 1
    fi
    
    local env_file="$ENV_DIR/$name.env.gpg"
    
    if [[ ! -f "$env_file" ]]; then
        log_error "Environment profile not found: $name" "ENV"
        return 1
    fi
    
    log_info "Decrypting environment profile '$name' to '$output_file'" "ENV"
    
    if gpg --quiet --decrypt "$env_file" > "$output_file" 2>/dev/null; then
        chmod 600 "$output_file"  # Secure permissions
        log_info "Environment profile decrypted to: $output_file" "ENV"
    else
        log_error "Failed to decrypt environment profile: $name" "ENV"
        return 1
    fi
}

# Legacy function for backward compatibility
env_eval() {
    log_warn "env:eval is deprecated, use env:open instead" "ENV"
    env_open "$@"
}

# Register environment commands
jb_register "env:list" env_list "List available encrypted environment profiles" "env"
jb_register "env:open" env_open "Decrypt and load environment profile for current shell" "env"
jb_register "env:write" env_write "Decrypt environment profile to file" "env"
jb_register "env:eval" env_eval "Legacy alias for env:open" "env"
