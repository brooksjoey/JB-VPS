#!/usr/bin/env bash
# Idempotent VPS Bootstrap Script for JB-VPS
# Safely initializes a fresh VPS with all necessary components

set -euo pipefail

# Bootstrap configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JB_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
BOOTSTRAP_LOG="/var/log/jb-vps-bootstrap.log"
BOOTSTRAP_STATE="/var/lib/jb-vps/bootstrap.state"

# Source base library if available
if [[ -f "$JB_DIR/lib/base.sh" ]]; then
    source "$JB_DIR/lib/base.sh"
else
    # Fallback logging
    log_info() { echo "[INFO] $*" | tee -a "$BOOTSTRAP_LOG"; }
    log_warn() { echo "[WARN] $*" | tee -a "$BOOTSTRAP_LOG"; }
    log_error() { echo "[ERROR] $*" | tee -a "$BOOTSTRAP_LOG" >&2; }
    as_root() { if [[ $EUID -eq 0 ]]; then "$@"; else sudo "$@"; fi; }
    detect_os() { [[ -f /etc/os-release ]] && source /etc/os-release; echo "${ID:-unknown}"; }
fi

# Initialize bootstrap logging
bootstrap_init_logging() {
    as_root mkdir -p "$(dirname "$BOOTSTRAP_LOG")" "$(dirname "$BOOTSTRAP_STATE")"
    as_root touch "$BOOTSTRAP_LOG"
    as_root chmod 644 "$BOOTSTRAP_LOG"
    
    log_info "JB-VPS Bootstrap started at $(date)"
    log_info "Target system: $(uname -a)"
    log_info "Bootstrap script: $0"
}

# State management for idempotent operations
bootstrap_get_state() {
    local key="$1"
    if [[ -f "$BOOTSTRAP_STATE" ]]; then
        grep "^$key=" "$BOOTSTRAP_STATE" 2>/dev/null | cut -d'=' -f2- | head -1
    fi
}

bootstrap_set_state() {
    local key="$1"
    local value="$2"
    
    as_root mkdir -p "$(dirname "$BOOTSTRAP_STATE")"
    
    if [[ -f "$BOOTSTRAP_STATE" ]]; then
        if as_root grep -q "^$key=" "$BOOTSTRAP_STATE"; then
            as_root sed -i "s/^$key=.*/$key=$value/" "$BOOTSTRAP_STATE"
        else
            echo "$key=$value" | as_root tee -a "$BOOTSTRAP_STATE" >/dev/null
        fi
    else
        echo "$key=$value" | as_root tee "$BOOTSTRAP_STATE" >/dev/null
    fi
    
    log_info "State updated: $key=$value"
}

# Check if step is already completed
bootstrap_is_completed() {
    local step="$1"
    local state
    state=$(bootstrap_get_state "$step")
    [[ "$state" == "completed" ]]
}

# Mark step as completed
bootstrap_complete_step() {
    local step="$1"
    bootstrap_set_state "$step" "completed"
    log_info "Step completed: $step"
}

# System update and basic packages
bootstrap_system_update() {
    local step="system_update"
    
    if bootstrap_is_completed "$step"; then
        log_info "Skipping $step - already completed"
        return 0
    fi
    
    log_info "Starting system update and basic package installation"
    
    local os
    os=$(detect_os)
    
    case "$os" in
        debian|ubuntu)
            log_info "Updating package lists..."
            as_root apt-get update -y
            
            log_info "Upgrading system packages..."
            as_root DEBIAN_FRONTEND=noninteractive apt-get upgrade -y
            
            log_info "Installing essential packages..."
            as_root DEBIAN_FRONTEND=noninteractive apt-get install -y \
                curl wget git vim nano htop tree jq bc \
                build-essential software-properties-common \
                apt-transport-https ca-certificates gnupg lsb-release \
                unzip zip tar gzip bzip2 xz-utils \
                net-tools dnsutils iputils-ping \
                rsync screen tmux \
                fail2ban ufw \
                python3 python3-pip \
                nodejs npm
            ;;
        fedora)
            log_info "Updating system packages..."
            as_root dnf update -y
            
            log_info "Installing essential packages..."
            as_root dnf install -y \
                curl wget git vim nano htop tree jq bc \
                gcc gcc-c++ make \
                unzip zip tar gzip bzip2 xz \
                net-tools bind-utils iputils \
                rsync screen tmux \
                fail2ban firewalld \
                python3 python3-pip \
                nodejs npm
            ;;
        centos|rhel)
            log_info "Updating system packages..."
            as_root yum update -y
            
            log_info "Installing EPEL repository..."
            as_root yum install -y epel-release
            
            log_info "Installing essential packages..."
            as_root yum install -y \
                curl wget git vim nano htop tree jq bc \
                gcc gcc-c++ make \
                unzip zip tar gzip bzip2 xz \
                net-tools bind-utils iputils \
                rsync screen tmux \
                fail2ban firewalld \
                python3 python3-pip \
                nodejs npm
            ;;
        *)
            log_error "Unsupported operating system: $os"
            return 1
            ;;
    esac
    
    bootstrap_complete_step "$step"
}

# Security hardening
bootstrap_security_hardening() {
    local step="security_hardening"
    
    if bootstrap_is_completed "$step"; then
        log_info "Skipping $step - already completed"
        return 0
    fi
    
    log_info "Applying security hardening measures"
    
    # Configure SSH security
    log_info "Hardening SSH configuration..."
    local ssh_config="/etc/ssh/sshd_config"
    local ssh_backup="/etc/ssh/sshd_config.backup.$(date +%Y%m%d_%H%M%S)"
    
    if [[ -f "$ssh_config" ]]; then
        as_root cp "$ssh_config" "$ssh_backup"
        
        # Apply SSH hardening settings
        as_root tee "$ssh_config.jb-hardening" > /dev/null << 'EOF'
# JB-VPS SSH Hardening Configuration
Protocol 2
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
AuthorizedKeysFile .ssh/authorized_keys
PermitEmptyPasswords no
ChallengeResponseAuthentication no
UsePAM yes
X11Forwarding no
PrintMotd no
AcceptEnv LANG LC_*
Subsystem sftp /usr/lib/openssh/sftp-server
ClientAliveInterval 300
ClientAliveCountMax 2
MaxAuthTries 3
MaxSessions 10
LoginGraceTime 60
EOF
        
        # Merge hardening settings with existing config
        as_root cp "$ssh_config" "$ssh_config.tmp"
        
        # Remove conflicting settings and add hardened ones
        as_root sed -i '/^Protocol\|^PermitRootLogin\|^PasswordAuthentication\|^PubkeyAuthentication\|^PermitEmptyPasswords\|^ChallengeResponseAuthentication\|^X11Forwarding\|^ClientAliveInterval\|^ClientAliveCountMax\|^MaxAuthTries\|^MaxSessions\|^LoginGraceTime/d' "$ssh_config.tmp"
        
        as_root cat "$ssh_config.jb-hardening" >> "$ssh_config.tmp"
        as_root mv "$ssh_config.tmp" "$ssh_config"
        as_root rm "$ssh_config.jb-hardening"
        
        # Validate SSH config
        if as_root sshd -t; then
            log_info "SSH configuration validated successfully"
            as_root systemctl reload sshd || as_root service ssh reload
        else
            log_error "SSH configuration validation failed, restoring backup"
            as_root mv "$ssh_backup" "$ssh_config"
            return 1
        fi
    fi
    
    # Configure firewall
    log_info "Configuring firewall..."
    local os
    os=$(detect_os)
    
    case "$os" in
        debian|ubuntu)
            # Configure UFW
            as_root ufw --force reset
            as_root ufw default deny incoming
            as_root ufw default allow outgoing
            as_root ufw allow ssh
            as_root ufw allow 80/tcp
            as_root ufw allow 443/tcp
            as_root ufw --force enable
            ;;
        fedora|centos|rhel)
            # Configure firewalld
            as_root systemctl enable firewalld
            as_root systemctl start firewalld
            as_root firewall-cmd --permanent --remove-service=dhcpv6-client || true
            as_root firewall-cmd --permanent --add-service=ssh
            as_root firewall-cmd --permanent --add-service=http
            as_root firewall-cmd --permanent --add-service=https
            as_root firewall-cmd --reload
            ;;
    esac
    
    # Configure fail2ban
    log_info "Configuring fail2ban..."
    as_root systemctl enable fail2ban
    as_root systemctl start fail2ban
    
    # Create fail2ban local configuration
    as_root tee /etc/fail2ban/jail.local > /dev/null << 'EOF'
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 3
backend = systemd

[sshd]
enabled = true
port = ssh
logpath = %(sshd_log)s
backend = %(sshd_backend)s
EOF
    
    as_root systemctl restart fail2ban
    
    bootstrap_complete_step "$step"
}

# User setup and permissions
bootstrap_user_setup() {
    local step="user_setup"
    
    if bootstrap_is_completed "$step"; then
        log_info "Skipping $step - already completed"
        return 0
    fi
    
    log_info "Setting up user accounts and permissions"
    
    # Create jb-vps user if it doesn't exist
    if ! id "jb-vps" >/dev/null 2>&1; then
        log_info "Creating jb-vps user..."
        as_root useradd -m -s /bin/bash -G sudo jb-vps || true
        
        # Set up SSH directory
        as_root mkdir -p /home/jb-vps/.ssh
        as_root chmod 700 /home/jb-vps/.ssh
        as_root chown jb-vps:jb-vps /home/jb-vps/.ssh
        
        # Copy current user's authorized_keys if available
        if [[ -f "$HOME/.ssh/authorized_keys" ]]; then
            as_root cp "$HOME/.ssh/authorized_keys" /home/jb-vps/.ssh/
            as_root chmod 600 /home/jb-vps/.ssh/authorized_keys
            as_root chown jb-vps:jb-vps /home/jb-vps/.ssh/authorized_keys
        fi
    fi
    
    # Set up JB-VPS directory permissions
    as_root chown -R jb-vps:jb-vps "$JB_DIR"
    as_root chmod -R 755 "$JB_DIR"
    as_root chmod +x "$JB_DIR/bin/jb"
    
    # Add JB-VPS to PATH for all users
    if [[ ! -f /etc/profile.d/jb-vps.sh ]]; then
        as_root tee /etc/profile.d/jb-vps.sh > /dev/null << EOF
# JB-VPS Environment
export JB_DIR="$JB_DIR"
export PATH="\$PATH:$JB_DIR/bin"
EOF
        as_root chmod 644 /etc/profile.d/jb-vps.sh
    fi
    
    bootstrap_complete_step "$step"
}

# Directory structure setup
bootstrap_directory_setup() {
    local step="directory_setup"
    
    if bootstrap_is_completed "$step"; then
        log_info "Skipping $step - already completed"
        return 0
    fi
    
    log_info "Setting up JB-VPS directory structure"
    
    # Create required directories
    local directories=(
        "$JB_DIR/config"
        "$JB_DIR/logs"
        "$JB_DIR/tmp"
        "$JB_DIR/templates/nginx"
        "$JB_DIR/templates/ssh"
        "$JB_DIR/templates/firewall"
        "$JB_DIR/templates/systemd"
        "$JB_DIR/secure/keys"
        "$JB_DIR/secure/configs"
        "$JB_DIR/plugins/security"
        "$JB_DIR/plugins/networking"
        "$JB_DIR/plugins/monitoring"
        "$JB_DIR/plugins/backup"
        "$JB_DIR/scripts/maintenance"
        "$JB_DIR/scripts/recovery"
        "$JB_DIR/docs/user-guide"
        "$JB_DIR/docs/admin-guide"
        "$JB_DIR/docs/api-reference"
        "$JB_DIR/tests/unit"
        "$JB_DIR/tests/integration"
        "/var/lib/jb-vps"
        "/var/log/jb-vps"
        "/var/cache/jb-vps"
    )
    
    for dir in "${directories[@]}"; do
        if [[ ! -d "$dir" ]]; then
            log_info "Creating directory: $dir"
            as_root mkdir -p "$dir"
        fi
    done
    
    # Set appropriate permissions
    as_root chown -R jb-vps:jb-vps "$JB_DIR"
    as_root chown -R jb-vps:jb-vps /var/lib/jb-vps
    as_root chown -R jb-vps:jb-vps /var/log/jb-vps
    as_root chown -R jb-vps:jb-vps /var/cache/jb-vps
    
    # Secure sensitive directories
    as_root chmod 700 "$JB_DIR/secure"
    as_root chmod 700 "$JB_DIR/secure/keys"
    as_root chmod 700 "$JB_DIR/secure/configs"
    
    bootstrap_complete_step "$step"
}

# Service setup
bootstrap_service_setup() {
    local step="service_setup"
    
    if bootstrap_is_completed "$step"; then
        log_info "Skipping $step - already completed"
        return 0
    fi
    
    log_info "Setting up JB-VPS services"
    
    # Create systemd service for JB-VPS monitoring
    as_root tee /etc/systemd/system/jb-vps-monitor.service > /dev/null << EOF
[Unit]
Description=JB-VPS System Monitor
After=network.target

[Service]
Type=simple
User=jb-vps
Group=jb-vps
WorkingDirectory=$JB_DIR
ExecStart=$JB_DIR/bin/jb monitor --daemon
Restart=always
RestartSec=30
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF
    
    # Create systemd timer for maintenance tasks
    as_root tee /etc/systemd/system/jb-vps-maintenance.service > /dev/null << EOF
[Unit]
Description=JB-VPS Maintenance Tasks
After=network.target

[Service]
Type=oneshot
User=jb-vps
Group=jb-vps
WorkingDirectory=$JB_DIR
ExecStart=$JB_DIR/bin/jb maintenance --auto
StandardOutput=journal
StandardError=journal
EOF
    
    as_root tee /etc/systemd/system/jb-vps-maintenance.timer > /dev/null << EOF
[Unit]
Description=Run JB-VPS maintenance tasks daily
Requires=jb-vps-maintenance.service

[Timer]
OnCalendar=daily
Persistent=true

[Install]
WantedBy=timers.target
EOF
    
    # Reload systemd and enable services
    as_root systemctl daemon-reload
    as_root systemctl enable jb-vps-maintenance.timer
    as_root systemctl start jb-vps-maintenance.timer
    
    bootstrap_complete_step "$step"
}

# Configuration setup
bootstrap_configuration_setup() {
    local step="configuration_setup"
    
    if bootstrap_is_completed "$step"; then
        log_info "Skipping $step - already completed"
        return 0
    fi
    
    log_info "Setting up JB-VPS configuration"
    
    # Create main configuration file
    local config_file="$JB_DIR/config/jb-vps.conf"
    if [[ ! -f "$config_file" ]]; then
        cat > "$config_file" << EOF
# JB-VPS Configuration File
# Generated on $(date)

# System settings
JB_VERSION=2.0.0
JB_DEBUG=false
JB_LOG_LEVEL=INFO
JB_LOG_DIR=/var/log/jb-vps
JB_STATE_DIR=/var/lib/jb-vps

# Backup settings
JB_BACKUP_DIR=/var/backups/jb-vps
JB_BACKUP_RETENTION_DAYS=30
JB_BACKUP_COMPRESSION=gzip
JB_BACKUP_ENCRYPTION=false

# Security settings
JB_VALIDATION_STRICT=true
JB_AUDIT_ENABLED=true

# Network settings
JB_DEFAULT_SSH_PORT=22
JB_DEFAULT_HTTP_PORT=80
JB_DEFAULT_HTTPS_PORT=443

# Red Team settings
JB_REDTEAM_ENABLED=true
JB_REDTEAM_AUTH_REQUIRED=true
EOF
        
        chown jb-vps:jb-vps "$config_file"
        chmod 644 "$config_file"
    fi
    
    # Create environment-specific configurations
    local env_dir="$JB_DIR/secure/environments"
    if [[ ! -f "$env_dir/default.env" ]]; then
        cat > "$env_dir/default.env" << EOF
# Default Environment Configuration
# This file contains non-sensitive default settings

export JB_ENVIRONMENT=production
export JB_LOG_LEVEL=INFO
export JB_DEBUG=false
EOF
        
        chown jb-vps:jb-vps "$env_dir/default.env"
        chmod 600 "$env_dir/default.env"
    fi
    
    bootstrap_complete_step "$step"
}

# Cleanup and finalization
bootstrap_cleanup() {
    local step="cleanup"
    
    if bootstrap_is_completed "$step"; then
        log_info "Skipping $step - already completed"
        return 0
    fi
    
    log_info "Performing cleanup and finalization"
    
    # Clean package cache
    local os
    os=$(detect_os)
    
    case "$os" in
        debian|ubuntu)
            as_root apt-get autoremove -y
            as_root apt-get autoclean
            ;;
        fedora)
            as_root dnf autoremove -y
            as_root dnf clean all
            ;;
        centos|rhel)
            as_root yum autoremove -y
            as_root yum clean all
            ;;
    esac
    
    # Update locate database
    as_root updatedb || true
    
    # Set final permissions
    as_root chown -R jb-vps:jb-vps "$JB_DIR"
    as_root chmod +x "$JB_DIR/bin/jb"
    
    # Create completion marker
    bootstrap_set_state "bootstrap_completed" "$(date -Iseconds)"
    
    bootstrap_complete_step "$step"
}

# Main bootstrap function
bootstrap_main() {
    echo "🚀 JB-VPS Bootstrap Starting..."
    echo "================================"
    echo ""
    
    # Initialize logging
    bootstrap_init_logging
    
    # Check if already bootstrapped
    if bootstrap_is_completed "bootstrap_completed"; then
        log_info "System already bootstrapped. Use --force to re-run."
        echo "✅ System already bootstrapped!"
        echo ""
        echo "To re-run bootstrap: $0 --force"
        echo "To check status: $JB_DIR/bin/jb status"
        return 0
    fi
    
    # Run bootstrap steps
    local steps=(
        "bootstrap_system_update"
        "bootstrap_security_hardening"
        "bootstrap_user_setup"
        "bootstrap_directory_setup"
        "bootstrap_service_setup"
        "bootstrap_configuration_setup"
        "bootstrap_cleanup"
    )
    
    local total_steps=${#steps[@]}
    local current_step=0
    
    for step_func in "${steps[@]}"; do
        ((current_step++))
        echo ""
        echo "📋 Step $current_step/$total_steps: ${step_func#bootstrap_}"
        echo "----------------------------------------"
        
        if $step_func; then
            echo "✅ Step completed successfully"
        else
            echo "❌ Step failed"
            log_error "Bootstrap step failed: $step_func"
            return 1
        fi
    done
    
    echo ""
    echo "🎉 JB-VPS Bootstrap Completed Successfully!"
    echo "==========================================="
    echo ""
    echo "Next steps:"
    echo "1. Log out and log back in to refresh your environment"
    echo "2. Run: jb help"
    echo "3. Run: jb info"
    echo "4. Configure your first project: jb redteam"
    echo ""
    echo "Documentation: $JB_DIR/docs/"
    echo "Logs: /var/log/jb-vps/"
    echo ""
    
    log_info "Bootstrap completed successfully at $(date)"
}

# Handle command line arguments
case "${1:-}" in
    "--force")
        log_info "Force bootstrap requested, clearing completion state"
        as_root rm -f "$BOOTSTRAP_STATE"
        bootstrap_main
        ;;
    "--status")
        echo "Bootstrap Status:"
        echo "================"
        if [[ -f "$BOOTSTRAP_STATE" ]]; then
            cat "$BOOTSTRAP_STATE"
        else
            echo "No bootstrap state found"
        fi
        ;;
    "--help"|"-h")
        echo "JB-VPS Bootstrap Script"
        echo "======================"
        echo ""
        echo "Usage: $0 [options]"
        echo ""
        echo "Options:"
        echo "  --force    Force re-run bootstrap even if already completed"
        echo "  --status   Show bootstrap status"
        echo "  --help     Show this help message"
        echo ""
        ;;
    "")
        bootstrap_main
        ;;
    *)
        echo "Unknown option: $1"
        echo "Use --help for usage information"
        exit 1
        ;;
esac
