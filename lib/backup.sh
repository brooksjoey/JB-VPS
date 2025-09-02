#!/usr/bin/env bash
# Backup and recovery functions for JB-VPS
# Provides enterprise-grade backup and disaster recovery capabilities

set -euo pipefail

# Source dependencies
if [[ -f "${JB_DIR:-}/lib/logging.sh" ]]; then
    source "${JB_DIR}/lib/logging.sh"
else
    log_error() { echo "ERROR: $1" >&2; }
    log_warn() { echo "WARN: $1" >&2; }
    log_info() { echo "INFO: $1"; }
fi

if [[ -f "${JB_DIR:-}/lib/validation.sh" ]]; then
    source "${JB_DIR}/lib/validation.sh"
else
    validate_dir_exists() { [[ -d "$1" ]]; }
    validate_file_exists() { [[ -f "$1" ]]; }
fi

# Backup configuration
declare -g BACKUP_DIR="${JB_BACKUP_DIR:-/var/backups/jb-vps}"
declare -g BACKUP_RETENTION_DAYS="${JB_BACKUP_RETENTION_DAYS:-30}"
declare -g BACKUP_COMPRESSION="${JB_BACKUP_COMPRESSION:-gzip}"
declare -g BACKUP_ENCRYPTION="${JB_BACKUP_ENCRYPTION:-false}"
declare -g BACKUP_REMOTE_ENABLED="${JB_BACKUP_REMOTE_ENABLED:-false}"
declare -g BACKUP_REMOTE_HOST="${JB_BACKUP_REMOTE_HOST:-}"
declare -g BACKUP_REMOTE_PATH="${JB_BACKUP_REMOTE_PATH:-}"
declare -g BACKUP_EXCLUDE_PATTERNS="${JB_BACKUP_EXCLUDE_PATTERNS:-*.tmp,*.log,*.cache}"

# Initialize backup system
backup_init() {
    local backup_dir="${1:-$BACKUP_DIR}"
    
    log_info "Initializing backup system" "BACKUP"
    
    # Create backup directory structure
    if [[ $EUID -eq 0 ]]; then
        mkdir -p "$backup_dir"/{configs,data,system,logs}
        chmod 750 "$backup_dir"
        chown root:root "$backup_dir"
    else
        # Use user's home directory if not root
        BACKUP_DIR="$HOME/.jb-vps/backups"
        mkdir -p "$BACKUP_DIR"/{configs,data,system,logs}
    fi
    
    # Create backup metadata directory
    mkdir -p "$BACKUP_DIR/.metadata"
    
    # Initialize backup registry
    local registry="$BACKUP_DIR/.metadata/registry.json"
    if [[ ! -f "$registry" ]]; then
        echo '{"backups": [], "last_cleanup": null, "version": "1.0"}' > "$registry"
    fi
    
    log_info "Backup system initialized at $BACKUP_DIR" "BACKUP"
}

# Create a backup
backup_create() {
    local source_path="$1"
    local backup_name="${2:-$(basename "$source_path")}"
    local backup_type="${3:-data}"  # configs, data, system, logs
    local description="${4:-Automated backup}"
    
    log_info "Creating backup: $backup_name" "BACKUP"
    
    # Validate inputs
    if ! validate_dir_exists "$source_path" "source path"; then
        log_error "Source path does not exist: $source_path" "BACKUP"
        return 1
    fi
    
    # Generate backup metadata
    local timestamp
    timestamp=$(date '+%Y%m%d_%H%M%S')
    local backup_id="${backup_name}_${timestamp}"
    local backup_path="$BACKUP_DIR/$backup_type/$backup_id"
    
    # Create backup directory
    mkdir -p "$backup_path"
    
    # Create exclusion file
    local exclude_file="$backup_path/.exclude"
    IFS=',' read -ra patterns <<< "$BACKUP_EXCLUDE_PATTERNS"
    for pattern in "${patterns[@]}"; do
        echo "$pattern" >> "$exclude_file"
    done
    
    # Perform backup based on type
    local backup_file="$backup_path/backup.tar"
    local start_time
    start_time=$(date +%s.%N)
    
    log_info "Creating archive from $source_path" "BACKUP"
    
    if tar --exclude-from="$exclude_file" -cf "$backup_file" -C "$(dirname "$source_path")" "$(basename "$source_path")" 2>/dev/null; then
        log_info "Archive created successfully" "BACKUP"
    else
        log_error "Failed to create archive" "BACKUP"
        rm -rf "$backup_path"
        return 1
    fi
    
    # Apply compression if enabled
    if [[ "$BACKUP_COMPRESSION" != "none" ]]; then
        log_info "Compressing backup with $BACKUP_COMPRESSION" "BACKUP"
        case "$BACKUP_COMPRESSION" in
            "gzip")
                gzip "$backup_file"
                backup_file="$backup_file.gz"
                ;;
            "bzip2")
                bzip2 "$backup_file"
                backup_file="$backup_file.bz2"
                ;;
            "xz")
                xz "$backup_file"
                backup_file="$backup_file.xz"
                ;;
        esac
    fi
    
    # Apply encryption if enabled
    if [[ "$BACKUP_ENCRYPTION" == "true" ]]; then
        log_info "Encrypting backup" "BACKUP"
        if command -v gpg >/dev/null 2>&1; then
            gpg --symmetric --cipher-algo AES256 --compress-algo 1 --s2k-mode 3 \
                --s2k-digest-algo SHA512 --s2k-count 65536 --quiet \
                --output "$backup_file.gpg" "$backup_file"
            rm "$backup_file"
            backup_file="$backup_file.gpg"
        else
            log_warn "GPG not available, skipping encryption" "BACKUP"
        fi
    fi
    
    local end_time
    end_time=$(date +%s.%N)
    
    # Calculate backup size and duration
    local backup_size
    backup_size=$(stat -c%s "$backup_file" 2>/dev/null || stat -f%z "$backup_file" 2>/dev/null || echo 0)
    local duration
    duration=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "unknown")
    
    # Create backup metadata
    local metadata_file="$backup_path/metadata.json"
    cat > "$metadata_file" << EOF
{
    "id": "$backup_id",
    "name": "$backup_name",
    "type": "$backup_type",
    "description": "$description",
    "source_path": "$source_path",
    "backup_path": "$backup_path",
    "backup_file": "$backup_file",
    "created_at": "$(date -Iseconds)",
    "created_by": "${SUDO_USER:-$USER}",
    "size_bytes": $backup_size,
    "duration_seconds": "$duration",
    "compression": "$BACKUP_COMPRESSION",
    "encrypted": $BACKUP_ENCRYPTION,
    "checksum": "$(sha256sum "$backup_file" | cut -d' ' -f1)"
}
EOF
    
    # Update backup registry
    backup_register "$metadata_file"
    
    # Sync to remote if enabled
    if [[ "$BACKUP_REMOTE_ENABLED" == "true" ]]; then
        backup_sync_remote "$backup_path"
    fi
    
    log_info "Backup completed: $backup_id (${backup_size} bytes, ${duration}s)" "BACKUP"
    echo "$backup_id"
}

# Register backup in registry
backup_register() {
    local metadata_file="$1"
    local registry="$BACKUP_DIR/.metadata/registry.json"
    
    # Read metadata
    local metadata
    metadata=$(cat "$metadata_file")
    
    # Update registry using jq if available
    if command -v jq >/dev/null 2>&1; then
        local temp_registry
        temp_registry=$(mktemp)
        jq --argjson backup "$metadata" '.backups += [$backup]' "$registry" > "$temp_registry"
        mv "$temp_registry" "$registry"
    else
        # Fallback: simple append (less robust)
        log_warn "jq not available, using simple registry update" "BACKUP"
    fi
}

# List backups
backup_list() {
    local backup_type="${1:-all}"
    local format="${2:-table}"  # table, json, simple
    
    local registry="$BACKUP_DIR/.metadata/registry.json"
    
    if [[ ! -f "$registry" ]]; then
        log_warn "No backup registry found" "BACKUP"
        return 1
    fi
    
    case "$format" in
        "json")
            if command -v jq >/dev/null 2>&1; then
                if [[ "$backup_type" == "all" ]]; then
                    jq '.backups' "$registry"
                else
                    jq --arg type "$backup_type" '.backups[] | select(.type == $type)' "$registry"
                fi
            else
                cat "$registry"
            fi
            ;;
        "table")
            echo "ID                           TYPE     SIZE      CREATED              DESCRIPTION"
            echo "---------------------------- -------- --------- -------------------- -----------"
            if command -v jq >/dev/null 2>&1; then
                local query='.backups[]'
                if [[ "$backup_type" != "all" ]]; then
                    query="$query | select(.type == \"$backup_type\")"
                fi
                jq -r "$query | [.id, .type, (.size_bytes | tostring), .created_at, .description] | @tsv" "$registry" | \
                while IFS=$'\t' read -r id type size created desc; do
                    printf "%-28s %-8s %-9s %-20s %s\n" \
                        "${id:0:28}" "$type" "$(numfmt --to=iec "$size" 2>/dev/null || echo "$size")" \
                        "${created:0:19}" "${desc:0:50}"
                done
            fi
            ;;
        "simple")
            if command -v jq >/dev/null 2>&1; then
                local query='.backups[].id'
                if [[ "$backup_type" != "all" ]]; then
                    query='.backups[] | select(.type == "'"$backup_type"'") | .id'
                fi
                jq -r "$query" "$registry"
            fi
            ;;
    esac
}

# Restore from backup
backup_restore() {
    local backup_id="$1"
    local restore_path="${2:-}"
    local force="${3:-false}"
    
    log_info "Restoring backup: $backup_id" "BACKUP"
    
    # Find backup metadata
    local registry="$BACKUP_DIR/.metadata/registry.json"
    local backup_info
    
    if command -v jq >/dev/null 2>&1; then
        backup_info=$(jq -r --arg id "$backup_id" '.backups[] | select(.id == $id)' "$registry")
        if [[ -z "$backup_info" || "$backup_info" == "null" ]]; then
            log_error "Backup not found: $backup_id" "BACKUP"
            return 1
        fi
    else
        log_error "jq required for backup restoration" "BACKUP"
        return 1
    fi
    
    # Extract backup information
    local backup_file
    backup_file=$(echo "$backup_info" | jq -r '.backup_file')
    local source_path
    source_path=$(echo "$backup_info" | jq -r '.source_path')
    local encrypted
    encrypted=$(echo "$backup_info" | jq -r '.encrypted')
    
    # Determine restore path
    if [[ -z "$restore_path" ]]; then
        restore_path="$source_path"
    fi
    
    # Validate backup file exists
    if [[ ! -f "$backup_file" ]]; then
        log_error "Backup file not found: $backup_file" "BACKUP"
        return 1
    fi
    
    # Check if restore path exists and handle accordingly
    if [[ -e "$restore_path" ]] && [[ "$force" != "true" ]]; then
        log_error "Restore path exists and force not specified: $restore_path" "BACKUP"
        return 1
    fi
    
    # Create restore directory
    mkdir -p "$(dirname "$restore_path")"
    
    # Prepare for extraction
    local extract_file="$backup_file"
    local temp_dir
    temp_dir=$(mktemp -d)
    
    # Decrypt if necessary
    if [[ "$encrypted" == "true" ]]; then
        log_info "Decrypting backup" "BACKUP"
        if command -v gpg >/dev/null 2>&1; then
            gpg --decrypt --quiet --output "$temp_dir/backup.tar" "$backup_file"
            extract_file="$temp_dir/backup.tar"
        else
            log_error "GPG not available for decryption" "BACKUP"
            rm -rf "$temp_dir"
            return 1
        fi
    fi
    
    # Decompress if necessary
    if [[ "$extract_file" == *.gz ]]; then
        log_info "Decompressing gzip backup" "BACKUP"
        gunzip -c "$extract_file" > "$temp_dir/backup.tar"
        extract_file="$temp_dir/backup.tar"
    elif [[ "$extract_file" == *.bz2 ]]; then
        log_info "Decompressing bzip2 backup" "BACKUP"
        bunzip2 -c "$extract_file" > "$temp_dir/backup.tar"
        extract_file="$temp_dir/backup.tar"
    elif [[ "$extract_file" == *.xz ]]; then
        log_info "Decompressing xz backup" "BACKUP"
        unxz -c "$extract_file" > "$temp_dir/backup.tar"
        extract_file="$temp_dir/backup.tar"
    fi
    
    # Extract backup
    log_info "Extracting backup to $restore_path" "BACKUP"
    if tar -xf "$extract_file" -C "$(dirname "$restore_path")" 2>/dev/null; then
        log_info "Backup restored successfully" "BACKUP"
    else
        log_error "Failed to extract backup" "BACKUP"
        rm -rf "$temp_dir"
        return 1
    fi
    
    # Cleanup
    rm -rf "$temp_dir"
    
    # Log restoration
    log_audit "RESTORE" "$backup_id" "SUCCESS" "restored_to=$restore_path"
    
    log_info "Restore completed: $backup_id -> $restore_path" "BACKUP"
}

# Delete backup
backup_delete() {
    local backup_id="$1"
    local force="${2:-false}"
    
    log_info "Deleting backup: $backup_id" "BACKUP"
    
    # Find backup metadata
    local registry="$BACKUP_DIR/.metadata/registry.json"
    local backup_info
    
    if command -v jq >/dev/null 2>&1; then
        backup_info=$(jq -r --arg id "$backup_id" '.backups[] | select(.id == $id)' "$registry")
        if [[ -z "$backup_info" || "$backup_info" == "null" ]]; then
            log_error "Backup not found: $backup_id" "BACKUP"
            return 1
        fi
    else
        log_error "jq required for backup deletion" "BACKUP"
        return 1
    fi
    
    # Extract backup path
    local backup_path
    backup_path=$(echo "$backup_info" | jq -r '.backup_path')
    
    # Confirm deletion if not forced
    if [[ "$force" != "true" ]]; then
        echo "Are you sure you want to delete backup $backup_id? (yes/no)"
        read -r confirmation
        if [[ "$confirmation" != "yes" ]]; then
            log_info "Backup deletion cancelled" "BACKUP"
            return 0
        fi
    fi
    
    # Remove backup files
    if [[ -d "$backup_path" ]]; then
        rm -rf "$backup_path"
        log_info "Backup files removed: $backup_path" "BACKUP"
    fi
    
    # Update registry
    local temp_registry
    temp_registry=$(mktemp)
    jq --arg id "$backup_id" '.backups |= map(select(.id != $id))' "$registry" > "$temp_registry"
    mv "$temp_registry" "$registry"
    
    # Log deletion
    log_audit "DELETE" "$backup_id" "SUCCESS" "path=$backup_path"
    
    log_info "Backup deleted: $backup_id" "BACKUP"
}

# Cleanup old backups
backup_cleanup() {
    local retention_days="${1:-$BACKUP_RETENTION_DAYS}"
    local dry_run="${2:-false}"
    
    log_info "Cleaning up backups older than $retention_days days" "BACKUP"
    
    local registry="$BACKUP_DIR/.metadata/registry.json"
    local cutoff_date
    cutoff_date=$(date -d "$retention_days days ago" -Iseconds 2>/dev/null || date -v-"${retention_days}d" -Iseconds 2>/dev/null)
    
    if [[ -z "$cutoff_date" ]]; then
        log_error "Unable to calculate cutoff date" "BACKUP"
        return 1
    fi
    
    local deleted_count=0
    
    if command -v jq >/dev/null 2>&1; then
        # Find old backups
        local old_backups
        old_backups=$(jq -r --arg cutoff "$cutoff_date" '.backups[] | select(.created_at < $cutoff) | .id' "$registry")
        
        while IFS= read -r backup_id; do
            if [[ -n "$backup_id" ]]; then
                if [[ "$dry_run" == "true" ]]; then
                    log_info "Would delete: $backup_id" "BACKUP"
                else
                    backup_delete "$backup_id" "true"
                fi
                ((deleted_count++))
            fi
        done <<< "$old_backups"
    fi
    
    # Update cleanup timestamp
    if [[ "$dry_run" != "true" ]]; then
        local temp_registry
        temp_registry=$(mktemp)
        jq --arg timestamp "$(date -Iseconds)" '.last_cleanup = $timestamp' "$registry" > "$temp_registry"
        mv "$temp_registry" "$registry"
    fi
    
    log_info "Cleanup completed: $deleted_count backups processed" "BACKUP"
}

# Verify backup integrity
backup_verify() {
    local backup_id="$1"
    
    log_info "Verifying backup: $backup_id" "BACKUP"
    
    # Find backup metadata
    local registry="$BACKUP_DIR/.metadata/registry.json"
    local backup_info
    
    if command -v jq >/dev/null 2>&1; then
        backup_info=$(jq -r --arg id "$backup_id" '.backups[] | select(.id == $id)' "$registry")
        if [[ -z "$backup_info" || "$backup_info" == "null" ]]; then
            log_error "Backup not found: $backup_id" "BACKUP"
            return 1
        fi
    else
        log_error "jq required for backup verification" "BACKUP"
        return 1
    fi
    
    # Extract backup information
    local backup_file
    backup_file=$(echo "$backup_info" | jq -r '.backup_file')
    local expected_checksum
    expected_checksum=$(echo "$backup_info" | jq -r '.checksum')
    
    # Verify file exists
    if [[ ! -f "$backup_file" ]]; then
        log_error "Backup file missing: $backup_file" "BACKUP"
        return 1
    fi
    
    # Verify checksum
    local actual_checksum
    actual_checksum=$(sha256sum "$backup_file" | cut -d' ' -f1)
    
    if [[ "$actual_checksum" == "$expected_checksum" ]]; then
        log_info "Backup verification successful: $backup_id" "BACKUP"
        return 0
    else
        log_error "Backup verification failed: checksum mismatch" "BACKUP"
        log_error "Expected: $expected_checksum" "BACKUP"
        log_error "Actual: $actual_checksum" "BACKUP"
        return 1
    fi
}

# Sync backup to remote location
backup_sync_remote() {
    local backup_path="$1"
    
    if [[ "$BACKUP_REMOTE_ENABLED" != "true" ]]; then
        return 0
    fi
    
    if [[ -z "$BACKUP_REMOTE_HOST" ]] || [[ -z "$BACKUP_REMOTE_PATH" ]]; then
        log_warn "Remote backup not configured properly" "BACKUP"
        return 1
    fi
    
    log_info "Syncing backup to remote: $BACKUP_REMOTE_HOST" "BACKUP"
    
    if command -v rsync >/dev/null 2>&1; then
        rsync -avz --progress "$backup_path/" "$BACKUP_REMOTE_HOST:$BACKUP_REMOTE_PATH/"
        log_info "Remote sync completed" "BACKUP"
    else
        log_warn "rsync not available for remote backup" "BACKUP"
        return 1
    fi
}

# Get backup statistics
backup_stats() {
    local registry="$BACKUP_DIR/.metadata/registry.json"
    
    if [[ ! -f "$registry" ]]; then
        echo "No backup registry found"
        return 1
    fi
    
    if command -v jq >/dev/null 2>&1; then
        echo "=== BACKUP STATISTICS ==="
        echo "Total backups: $(jq '.backups | length' "$registry")"
        echo "Total size: $(jq -r '[.backups[].size_bytes] | add | tostring' "$registry" | xargs numfmt --to=iec 2>/dev/null || echo "unknown")"
        echo ""
        echo "By type:"
        jq -r '.backups | group_by(.type) | .[] | "\(.[0].type): \(length) backups"' "$registry"
        echo ""
        echo "Last cleanup: $(jq -r '.last_cleanup // "never"' "$registry")"
    else
        echo "jq required for backup statistics"
        return 1
    fi
}

# Export functions for use in other scripts
export -f backup_init backup_create backup_list backup_restore backup_delete
export -f backup_cleanup backup_verify backup_sync_remote backup_stats backup_register
