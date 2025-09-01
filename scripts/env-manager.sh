#!/usr/bin/env bash
# env-manager.sh - Secure Environment Management for my-sys-configs

set -uE -o pipefail

# ---------- Configuration ----------
readonly SCRIPT_NAME="env-manager.sh"
readonly ENV_DIR="$HOME/.secure/env"
readonly BACKUP_DIR="$HOME/.secure/backups"
readonly LOG_FILE="/var/log/env-manager.log"

# ---------- UI / Logging ----------
BOLD="$(tput bold 2>/dev/null || printf '')"
GREEN="$(tput setaf 2 2>/dev/null || printf '')"
RED="$(tput setaf 1 2>/dev/null || printf '')"
YELLOW="$(tput setaf 3 2>/dev/null || printf '')"
BLUE="$(tput setaf 4 2>/dev/null || printf '')"
RESET="$(tput sgr0 2>/dev/null || printf '')"

log_message() {
    local level="$1" message="$2" color="$3"
    echo -e "[$(date '+%F %T')] ${color}${level}: ${message}${RESET}"
    echo "[$(date '+%F %T')] ${level}: ${message}" >>"$LOG_FILE"
}

info() { log_message "INFO" "$1" "$GREEN"; }
warn() { log_message "WARN" "$1" "$YELLOW"; }
err() { log_message "ERROR" "$1" "$RED"; }

# ---------- Initialization ----------
initialize_environment() {
    mkdir -p "$ENV_DIR" "$BACKUP_DIR"
    chmod 700 "$ENV_DIR" "$BACKUP_DIR"
    
    # Create default environment categories
    local categories=("personal" "ai-projects" "red-team" "infrastructure" "backups")
    for category in "${categories[@]}"; do
        if [ ! -f "$ENV_DIR/${category}.env.gpg" ]; then
            touch "$ENV_DIR/${category}.env"
            encrypt_file "$ENV_DIR/${category}.env"
            rm -f "$ENV_DIR/${category}.env"
        fi
    done
}

# ---------- Encryption Functions ----------
encrypt_file() {
    local file="$1"
    if [ -f "$file" ]; then
        gpg --symmetric --cipher-algo AES256 --output "${file}.gpg" "$file" 2>/dev/null
        return $?
    fi
    return 1
}

decrypt_file() {
    local file="$1"
    if [ -f "${file}.gpg" ]; then
        gpg --decrypt --output "$file" "${file}.gpg" 2>/dev/null
        return $?
    fi
    return 1
}

# ---------- Core Functions ----------
add_environment_variable() {
    local category="$1"
    local temp_file=$(mktemp)
    
    decrypt_file "$ENV_DIR/$category"
    
    if [ -f "$ENV_DIR/$category.env" ]; then
        cp "$ENV_DIR/$category.env" "$temp_file"
        echo "" >> "$temp_file"
        
        read -rp "Enter variable name: " var_name
        read -rp "Enter variable value: " var_value
        
        # Remove existing variable if it exists
        grep -v "^${var_name}=" "$temp_file" > "${temp_file}.new"
        mv "${temp_file}.new" "$temp_file"
        
        # Add new variable
        echo "${var_name}=${var_value}" >> "$temp_file"
        
        mv "$temp_file" "$ENV_DIR/$category.env"
        encrypt_file "$ENV_DIR/$category.env"
        rm -f "$ENV_DIR/$category.env"
        
        info "Added ${var_name} to ${category} environment"
    else
        err "Failed to decrypt ${category} environment"
        return 1
    fi
}

view_environment() {
    local category="$1"
    local temp_file=$(mktemp)
    
    decrypt_file "$ENV_DIR/$category"
    
    if [ -f "$ENV_DIR/$category.env" ]; then
        echo -e "\n${BOLD}=== ${category} Environment ===${RESET}"
        cat "$ENV_DIR/$category.env"
        echo -e "\n"
        
        # Clean up
        shred -u "$ENV_DIR/$category.env" 2>/dev/null || rm -f "$ENV_DIR/$category.env"
    else
        err "Failed to decrypt ${category} environment"
        return 1
    fi
}

load_environment() {
    local category="$1"
    local temp_file=$(mktemp)
    
    decrypt_file "$ENV_DIR/$category"
    
    if [ -f "$ENV_DIR/$category.env" ]; then
        # Load variables into current shell
        while IFS='=' read -r key value; do
            if [[ ! $key =~ ^# && -n $key ]]; then
                export "${key}=${value}"
            fi
        done < "$ENV_DIR/$category.env"
        
        # Clean up
        shred -u "$ENV_DIR/$category.env" 2>/dev/null || rm -f "$ENV_DIR/$category.env"
        
        info "Loaded ${category} environment"
        return 0
    else
        err "Failed to decrypt ${category} environment"
        return 1
    fi
}

# ---------- Backup Functions ----------
create_backup() {
    local backup_file="$BACKUP_DIR/env-backup-$(date +%Y%m%d_%H%M%S).tar.gz"
    tar -czf "$backup_file" -C "$ENV_DIR" .
    info "Created backup: $backup_file"
}

restore_backup() {
    local backup_file="$1"
    if [ -f "$backup_file" ]; then
        tar -xzf "$backup_file" -C "$ENV_DIR"
        info "Restored from backup: $backup_file"
    else
        err "Backup file not found: $backup_file"
        return 1
    fi
}

# ---------- Main Menu ----------
show_menu() {
    echo -e "\n${BOLD}=== Environment Manager ===${RESET}"
    echo "${GREEN} 1) View environment"
    echo " 2) Add variable"
    echo " 3) Load environment"
    echo " 4) Create backup"
    echo " 5) List backups"
    echo " 6) Restore backup"
    echo " 7) Initialize environments"
    echo " 8) Exit${RESET}"
    echo
}

main_menu() {
    initialize_environment
    
    while true; do
        show_menu
        read -r -p "Select option (1-8): " choice
        
        case "${choice:-}" in
            1)
                echo -e "\n${BOLD}Available environments:${RESET}"
                ls "$ENV_DIR" | grep "\.gpg$" | sed 's/\.env\.gpg//' | nl
                read -rp "Select environment number: " env_num
                env_name=$(ls "$ENV_DIR" | grep "\.gpg$" | sed 's/\.env\.gpg//' | sed -n "${env_num}p")
                if [ -n "$env_name" ]; then
                    view_environment "$env_name"
                else
                    err "Invalid selection"
                fi
                ;;
            2)
                echo -e "\n${BOLD}Available environments:${RESET}"
                ls "$ENV_DIR" | grep "\.gpg$" | sed 's/\.env\.gpg//' | nl
                read -rp "Select environment number: " env_num
                env_name=$(ls "$ENV_DIR" | grep "\.gpg$" | sed 's/\.env\.gpg//' | sed -n "${env_num}p")
                if [ -n "$env_name" ]; then
                    add_environment_variable "$env_name"
                else
                    err "Invalid selection"
                fi
                ;;
            3)
                echo -e "\n${BOLD}Available environments:${RESET}"
                ls "$ENV_DIR" | grep "\.gpg$" | sed 's/\.env\.gpg//' | nl
                read -rp "Select environment number: " env_num
                env_name=$(ls "$ENV_DIR" | grep "\.gpg$" | sed 's/\.env\.gpg//' | sed -n "${env_num}p")
                if [ -n "$env_name" ]; then
                    load_environment "$env_name"
                else
                    err "Invalid selection"
                fi
                ;;
            4)
                create_backup
                ;;
            5)
                echo -e "\n${BOLD}Available backups:${RESET}"
                ls -la "$BACKUP_DIR" | grep "\.tar\.gz$" | nl
                ;;
            6)
                echo -e "\n${BOLD}Available backups:${RESET}"
                ls -la "$BACKUP_DIR" | grep "\.tar\.gz$" | nl
                read -rp "Select backup number: " backup_num
                backup_file=$(ls -1 "$BACKUP_DIR" | grep "\.tar\.gz$" | sed -n "${backup_num}p")
                if [ -n "$backup_file" ]; then
                    restore_backup "$BACKUP_DIR/$backup_file"
                else
                    err "Invalid selection"
                fi
                ;;
            7)
                initialize_environment
                info "Environments initialized"
                ;;
            8)
                info "Exiting environment manager"
                exit 0
                ;;
            *)
                warn "Invalid selection"
                ;;
        esac
        
        echo
        read -r -p "Press Enter to continue..."
    done
}

# ---------- Check Dependencies ----------
check_dependencies() {
    if ! command -v gpg >/dev/null 2>&1; then
        err "GPG is required but not installed. Please install it with:"
        err "  sudo apt update && sudo apt install gnupg"
        exit 1
    fi
    
    if ! command -v shred >/dev/null 2>&1; then
        warn "shred command not available - using less secure file deletion"
    fi
}

# ---------- Main Execution ----------
main() {
    echo "${BOLD}Environment Manager v1.0${RESET}"
    echo "Secure management for API keys, tokens, and credentials"
    echo
    
    check_dependencies
    main_menu
}

main "$@"