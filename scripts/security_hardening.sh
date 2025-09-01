#!/usr/bin/env bash
# ex1.sh — Enhanced Security Hardening (Ubuntu/Debian; tuned for Ubuntu 24.04 "noble")
# Enterprise-grade security hardening script
# Design goals: Idempotent, resilient, menu-driven, stays in-shell on errors, clear status & logs.

set -uE -o pipefail

# ---------- Configuration ----------
readonly SCRIPT_NAME="ex1.sh"
readonly SCRIPT_VERSION="1.0.0"
readonly CONFIG_BACKUP_DIR="/root/security-backups"
readonly MAX_BACKUPS=5

# ---------- UI / Logging ----------
BOLD="$(tput bold 2>/dev/null || printf '')"
RED="$(tput setaf 1 2>/dev/null || printf '')"
GREEN="$(tput setaf 2 2>/dev/null || printf '')"
YELLOW="$(tput setaf 3 2>/dev/null || printf '')"
BLUE="$(tput setaf 4 2>/dev/null || printf '')"
RESET="$(tput sgr0 2>/dev/null || printf '')"

# Logging setup
LOG="/var/log/ex1_security.log"
mkdir -p /var/log 2>/dev/null || true
if ! touch "$LOG" 2>/dev/null; then
    LOG="/tmp/ex1_security.log"
    touch "$LOG"
fi

# ---------- Utility Functions ----------
ts() { 
    date '+%F %T' 
}

log_message() {
    local level="$1"
    local message="$2"
    local color="$3"
    echo -e "[$(ts)] ${color}${level}: ${message}${RESET}"
    echo "[$(ts)] ${level}: ${message}" >>"$LOG"
}

info() { 
    log_message "INFO" "$1" "$GREEN"
}

warn() { 
    log_message "WARN" "$1" "$YELLOW"
}

err() { 
    log_message "ERROR" "$1" "$RED"
}

debug() {
    if [ "${DEBUG:-false}" = "true" ]; then
        log_message "DEBUG" "$1" "$BLUE"
    fi
}

# ---------- Error Handling ----------
trap 'error_handler $LINENO' ERR
trap 'interrupt_handler' SIGINT

error_handler() {
    local line="$1"
    err "Unexpected error occurred at line $line. Check $LOG for details."
    info "Returning to menu..."
    return 0
}

interrupt_handler() {
    echo
    warn "Operation interrupted by user. Returning to menu..."
    return 0
}

# ---------- Environment Detection ----------
detect_environment() {
    OS_ID=""
    OS_VER=""
    OS_CODENAME=""
    if [ -r /etc/os-release ]; then
        # shellcheck disable=SC1091
        . /etc/os-release
        OS_ID="${ID:-}"
        OS_VER="${VERSION_ID:-}"
        OS_CODENAME="${VERSION_CODENAME:-}"
    fi
    info "Detected environment: ${OS_ID:-unknown} ${OS_VER:-} (${OS_CODENAME:-})"
}

# ---------- Core Utilities ----------
confirm() {
    local prompt="$1" 
    local def="${2:-default_yes}"
    local ans=""
    
    if [ "$def" = "default_yes" ]; then
        read -r -p "$prompt [Y/n]: " ans || true
        [ -z "${ans:-}" ] || [[ "$ans" =~ ^[Yy]$ ]]
    else
        read -r -p "$prompt [y/N]: " ans || true
        [[ "$ans" =~ ^[Yy]$ ]]
    fi
}

run() {
    local desc="$1"
    shift
    local cmd=("$@")
    
    debug "Executing: ${cmd[*]}"
    echo "[$(ts)] COMMAND: ${cmd[*]}" >>"$LOG"
    
    if "${cmd[@]}" >>"$LOG" 2>&1; then
        info "$desc — SUCCESS"
        return 0
    else
        err "$desc — FAILED (see $LOG)"
        return 1
    fi
}

restart_service() {
    local svc="$1"
    info "Attempting to restart service: $svc"
    
    systemctl daemon-reload >/dev/null 2>&1 || true
    
    # Try reload first, then restart
    if systemctl reload "$svc" >/dev/null 2>&1 || \
       systemctl reload "${svc}d" >/dev/null 2>&1; then
        info "Service $svc reloaded successfully"
        return 0
    fi
    
    if systemctl restart "$svc" >/dev/null 2>&1 || \
       systemctl restart "${svc}d" >/dev/null 2>&1; then
        info "Service $svc restarted successfully"
        return 0
    fi
    
    err "Failed to reload/restart service $svc"
    return 1
}

ensure_enabled() {
    local svc="$1"
    if systemctl enable --now "$svc" >/dev/null 2>&1 || \
       systemctl enable --now "${svc}d" >/dev/null 2>&1; then
        info "Service $svc enabled and started"
        return 0
    fi
    warn "Failed to enable service $svc"
    return 1
}

write_file_if_changed() {
    local dst="$1"
    local content="$2"
    local mode="${3:-0644}"
    local tmp=""
    
    tmp="$(mktemp)"
    printf '%s\n' "$content" > "$tmp"
    
    if [ -f "$dst" ] && cmp -s "$tmp" "$dst"; then
        rm -f "$tmp"
        info "No changes to ${dst}"
        return 0
    fi
    
    mkdir -p "$(dirname "$dst")"
    
    # Create backup
    if [ -f "$dst" ]; then
        local backup_ext="backup.$(date +%Y%m%d_%H%M%S)"
        cp -a "$dst" "${dst}.${backup_ext}" || {
            rm -f "$tmp"
            err "Failed to create backup of ${dst}"
            return 1
        }
        info "Backup created: ${dst}.${backup_ext}"
    fi
    
    if install -m "$mode" "$tmp" "$dst"; then
        rm -f "$tmp"
        info "Successfully updated ${dst}"
        return 0
    else
        rm -f "$tmp"
        err "Failed to update ${dst}"
        return 1
    fi
}

# ---------- Package Management ----------
apt_update() {
    run "Updating package lists" env DEBIAN_FRONTEND=noninteractive apt-get update
}

apt_install() {
    local pkgs=("$@")
    [ "${#pkgs[@]}" -eq 0 ] && return 0
    
    apt_update
    run "Installing packages: ${pkgs[*]}" \
        env DEBIAN_FRONTEND=noninteractive apt-get -y install --no-install-recommends "${pkgs[@]}"
}

apt_purge_if_present() {
    local to_purge=()
    for p in "$@"; do
        if dpkg -l "$p" >/dev/null 2>&1; then
            to_purge+=("$p")
        fi
    done
    
    [ "${#to_purge[@]}" -eq 0 ] && return 0
    
    run "Purging packages: ${to_purge[*]}" \
        env DEBIAN_FRONTEND=noninteractive apt-get -y purge "${to_purge[@]}"
}

# ---------- Security Features ----------
install_security_packages() {
    info "Installing core security packages"
    
    # Remove conflicting packages
    apt_purge_if_present iptables-persistent netfilter-persistent
    
    local pkgs=(
        ufw fail2ban unattended-upgrades needrestart 
        auditd debsums bzip2 whois python3-pyinotify
        apt-listbugs apt-listchanges
    )
    
    apt_install "${pkgs[@]}"
    
    # Configure unattended-upgrades if not already configured
    if [ ! -f /etc/apt/apt.conf.d/20auto-upgrades ]; then
        write_file_if_changed /etc/apt/apt.conf.d/20auto-upgrades \
            'APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "7";'
    fi
    
    info "Security packages installed successfully"
}

install_optional_packages() {
    while :; do
        cat <<MENU

${BOLD}=== Optional Package Installation ===${RESET}
1) Install Nginx
2) Install Tailscale
3) Install both Nginx and Tailscale
4) Back to main menu
MENU
        read -r -p "Select option: " option
        case "${option:-}" in
            1) 
                apt_install nginx
                info "Nginx installed successfully"
                ;;
            2) 
                install_tailscale
                ;;
            3) 
                apt_install nginx
                install_tailscale
                ;;
            4) 
                break
                ;;
            *) 
                warn "Invalid selection. Please choose 1-4."
                ;;
        esac
    done
}

install_tailscale() {
    if command -v tailscale >/dev/null 2>&1; then
        info "Tailscale already installed"
        return 0
    fi

    # Detect codename (fallback to noble)
    local codename="${OS_CODENAME:-noble}"

    # Add / refresh Tailscale repository & key (idempotent)
    run "Adding Tailscale repository key (${codename})" \
        bash -c 'mkdir -p /usr/share/keyrings &&
                 curl -fsSL "https://pkgs.tailscale.com/stable/ubuntu/'"${codename}"'.noarmor.gpg" |
                 tee /usr/share/keyrings/tailscale-archive-keyring.gpg >/dev/null'

    run "Writing Tailscale apt source (${codename})" \
        bash -c 'printf "deb [signed-by=/usr/share/keyrings/tailscale-archive-keyring.gpg] https://pkgs.tailscale.com/stable/ubuntu '"${codename}"' main\n" > /etc/apt/sources.list.d/tailscale.list'

    apt_install tailscale tailscale-archive-keyring
    ensure_enabled tailscaled

    warn "Remember to run 'tailscale up' to authenticate after setup"
    record_reminder "Run 'tailscale up' to configure Tailscale networking"
}

configure_firewall() {
    info "Configuring UFW firewall"
    
    apt_install ufw
    
    # Enable UFW if not active
    if ! ufw status | grep -q "Status: active"; then
        ufw --force enable >/dev/null 2>&1
        info "UFW firewall enabled"
    else
        info "UFW already active"
    fi
    
    # Set default policies
    ufw default deny incoming >/dev/null 2>&1 && info "Default incoming: DENY"
    ufw default allow outgoing >/dev/null 2>&1 && info "Default outgoing: ALLOW"
    
    # Allow SSH
    if ufw app list | grep -q "^OpenSSH$"; then
        ufw allow OpenSSH >/dev/null 2>&1 && info "Allowed OpenSSH"
    else
        ufw allow 22/tcp >/dev/null 2>&1 && info "Allowed SSH (port 22/tcp)"
    fi
    
    # Allow Nginx if installed
    if command -v nginx >/dev/null 2>&1; then
        if ufw app list | grep -q "^Nginx Full$"; then
            ufw allow 'Nginx Full' >/dev/null 2>&1 && info "Allowed Nginx Full (HTTP/HTTPS)"
        else
            ufw allow 80,443/tcp >/dev/null 2>&1 && info "Allowed HTTP/HTTPS (ports 80,443/tcp)"
        fi
    fi
    
    # Allow Tailscale interface
    if ip link show tailscale0 >/dev/null 2>&1; then
        ufw allow in on tailscale0 >/dev/null 2>&1 && info "Allowed inbound on tailscale0 interface"
    fi
    
    ufw reload >/dev/null 2>&1
    info "Firewall configuration completed"
}

configure_fail2ban() {
    info "Configuring Fail2ban intrusion prevention"
    
    apt_install fail2ban
    
    local jail_local="/etc/fail2ban/jail.local"
    local content='[DEFAULT]
banaction = nftables-multiport
backend = systemd
findtime = 10m
bantime = 1h
maxretry = 5
destemail = root@localhost
sender = root@localhost
action = %(action_)s

[sshd]
enabled = true
port = ssh
logpath = %(sshd_log)s
maxretry = 3
findtime = 600
bantime = 3600

[sshd-ddos]
enabled = true
port = ssh
logpath = %(sshd_log)s
maxretry = 5
findtime = 600
bantime = 86400
'

    write_file_if_changed "$jail_local" "$content"
    ensure_enabled fail2ban
    restart_service fail2ban
    
    info "Fail2ban configuration completed"
}

configure_nginx_security() {
    if ! command -v nginx >/dev/null 2>&1; then
        warn "Nginx not installed - skipping security configuration"
        return 0
    fi
    
    info "Configuring Nginx security headers"
    
    local security_conf="/etc/nginx/conf.d/security.conf"
    local content='# Security headers configuration
add_header X-Content-Type-Options "nosniff" always;
add_header X-Frame-Options "SAMEORIGIN" always;
add_header Referrer-Policy "no-referrer-when-downgrade" always;
add_header X-XSS-Protection "1; mode=block" always;
add_header Permissions-Policy "geolocation=(), microphone=(), camera=()" always;

# Additional security settings
server_tokens off;
client_max_body_size 10m;
'

    write_file_if_changed "$security_conf" "$content"
    
    # Test configuration before reloading
    if nginx -t >/dev/null 2>&1; then
        restart_service nginx
        info "Nginx security configuration applied successfully"
    else
        err "Nginx configuration test failed - restoring backup"
        restore_backup "$security_conf"
        return 1
    fi
}

apply_system_hardening() {
    info "Applying system-level security hardening"
    
    local sysctl_conf="/etc/sysctl.d/99-ex1-hardening.conf"
    local content='# Network and kernel security hardening
kernel.kptr_restrict = 2
kernel.dmesg_restrict = 1
net.ipv4.tcp_syncookies = 1
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.ip_forward = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.all.accept_source_route = 0
net.ipv4.conf.default.accept_source_route = 0
net.ipv4.conf.all.log_martians = 1
net.ipv4.conf.default.log_martians = 1
net.ipv4.icmp_echo_ignore_broadcasts = 1
net.ipv4.icmp_ignore_bogus_error_responses = 1
kernel.unprivileged_bpf_disabled = 1
net.core.bpf_jit_enable = 0
'

    write_file_if_changed "$sysctl_conf" "$content"
    run "Applying sysctl settings" sysctl --system
    
    # Secure /dev/shm if requested
    if confirm "Secure /dev/shm with noexec,nosuid,nodev mount options?" default_no; then
        secure_dev_shm
    fi
    
    info "System hardening completed"
}

secure_dev_shm() {
    if grep -qE '^\s*tmpfs\s+/dev/shm\s' /etc/fstab; then
        sed -i 's|^\s*tmpfs\s\+/dev/shm\s\+tmpfs\s\+\S*|tmpfs /dev/shm tmpfs defaults,noexec,nosuid,nodev 0 0|' /etc/fstab
    else
        echo 'tmpfs /dev/shm tmpfs defaults,noexec,nosuid,nodev 0 0' >> /etc/fstab
    fi
    warn "/dev/shm secured - reboot required to apply changes"
    record_reminder "Reboot required to apply /dev/shm hardening"
}

safe_ssh_hardening() {
    info "Applying SSH security hardening"
    
    apt_install openssh-server
    
    local sshd_config_dir="/etc/ssh/sshd_config.d"
    local sshd_config_dropin="$sshd_config_dir/99-ex1-security.conf"
    mkdir -p "$sshd_config_dir"
    
    # Create backup of main config
    if [ -f /etc/ssh/sshd_config ] && [ ! -f /etc/ssh/sshd_config.backup ]; then
        cp -a /etc/ssh/sshd_config "/etc/ssh/sshd_config.backup.$(date +%Y%m%d_%H%M%S)"
    fi
    
    local content='# SSH security hardening
Protocol 2
MaxAuthTries 3
MaxSessions 10
ClientAliveInterval 300
ClientAliveCountMax 2
PermitEmptyPasswords no
X11Forwarding no
AllowAgentForwarding no
PermitRootLogin no
PasswordAuthentication yes
ChallengeResponseAuthentication no
'

    write_file_if_changed "$sshd_config_dropin" "$content"
    
    if sshd -t >/dev/null 2>&1; then
        restart_service ssh
        info "SSH security hardening applied successfully"
    else
        err "SSHD configuration test failed - restoring original config"
        restore_backup "/etc/ssh/sshd_config"
        return 1
    fi
}

setup_log_monitoring() {
    info "Setting up security log monitoring"
    
    local monitor_script="/usr/local/bin/security-monitor.sh"
    local service_file="/etc/systemd/system/security-monitor.service"
    local timer_file="/etc/systemd/system/security-monitor.timer"
    local log_file="/var/log/security-monitor.log"
    
    write_file_if_changed "$monitor_script" '#!/usr/bin/env bash
set -euo pipefail

{
    echo "===== Security Monitor Report — $(date "+%F %T") ====="
    echo "--- Recent SSH Authentication Failures ---"
    journalctl -u ssh -n 50 --no-pager | grep -i "fail\|invalid" | tail -20 || true
    
    echo
    echo "--- Fail2ban Status ---"
    fail2ban-client status 2>/dev/null || echo "Fail2ban not available"
    
    echo
    echo "--- UFW Status ---"
    ufw status verbose
    
    echo
    echo "--- System Uptime & Users ---"
    uptime
    who
    
    echo
    echo "--- Critical Log Entries (last hour) ---"
    journalctl --since "1 hour ago" -p crit..emerg --no-pager || true
    
} >> /var/log/security-monitor.log
' 0755

    write_file_if_changed "$service_file" '[Unit]
Description=EX1 Security Monitoring Service
Documentation=https://github.com/yourorg/ex1
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/security-monitor.sh
User=root
Group=root

[Install]
WantedBy=multi-user.target
'

    write_file_if_changed "$timer_file" '[Unit]
Description=EX1 Security Monitoring Timer
Documentation=https://github.com/yourorg/ex1
Requires=security-monitor.service

[Timer]
OnBootSec=2min
OnUnitActiveSec=15min
Unit=security-monitor.service

[Install]
WantedBy=timers.target
'

    run "Reloading systemd" systemctl daemon-reload
    run "Enabling security monitor" systemctl enable --now security-monitor.timer
    
    touch "$log_file" 2>/dev/null || true
    info "Security log monitoring setup completed"
}

# ---------- Backup and Restore ----------
create_backup() {
    info "Creating security configuration backup"
    
    mkdir -p "$CONFIG_BACKUP_DIR"
    local timestamp="$(date +%Y%m%d_%H%M%S)"
    local backup_file="$CONFIG_BACKUP_DIR/security-backup-$timestamp.tar.gz"
    
    local backup_paths=(
        /etc/ufw
        /etc/fail2ban
        /etc/nginx
        /etc/ssh
        /etc/sysctl.d
        /etc/systemd/system/security-monitor.*
        /usr/local/bin/security-monitor.sh
        /etc/fstab
    )
    
    local existing_paths=()
    for path in "${backup_paths[@]}"; do
        if [ -e "$path" ]; then
            existing_paths+=("$path")
        fi
    done
    
    if [ ${#existing_paths[@]} -eq 0 ]; then
        warn "No security configurations found to backup"
        return 0
    fi
    
    if run "Creating backup archive" tar -czf "$backup_file" "${existing_paths[@]}"; then
        info "Backup created: $backup_file"
        cleanup_old_backups
        return 0
    else
        err "Backup creation failed"
        return 1
    fi
}

cleanup_old_backups() {
    local backups=()
    mapfile -t backups < <(find "$CONFIG_BACKUP_DIR" -name "security-backup-*.tar.gz" -type f 2>/dev/null | sort)
    
    if [ ${#backups[@]} -gt $MAX_BACKUPS ]; then
        local to_remove=$(( ${#backups[@]} - MAX_BACKUPS ))
        for (( i=0; i<to_remove; i++ )); do
            rm -f "${backups[$i]}"
            debug "Removed old backup: ${backups[$i]}"
        done
    fi
}

restore_backup() {
    local file_path="$1"
    local backup_file=""
    
    backup_file="$(ls -1t "${file_path}.backup."* 2>/dev/null | head -1)"
    if [ -n "$backup_file" ] && [ -f "$backup_file" ]; then
        cp -a "$backup_file" "$file_path"
        info "Restored backup: $backup_file"
        return 0
    fi
    return 1
}

# ---------- Status and Monitoring ----------
check_status() {
    echo
    echo "${BOLD}=== Security Status Report ===${RESET}"
    echo
    
    # Firewall status
    if ufw status | grep -q "Status: active"; then
        echo "🔥 Firewall:    ${GREEN}ACTIVE${RESET}"
    else
        echo "🔥 Firewall:    ${RED}INACTIVE${RESET}"
    fi
    
    # Fail2ban status
    if systemctl is-active --quiet fail2ban; then
        echo "🛡️  Fail2ban:    ${GREEN}ACTIVE${RESET}"
    else
        echo "🛡️  Fail2ban:    ${YELLOW}INACTIVE${RESET}"
    fi
    
    # SSH status
    if systemctl is-active --quiet ssh 2>/dev/null || systemctl is-active --quiet sshd 2>/dev/null; then
        echo "🔐 SSH:         ${GREEN}ACTIVE${RESET}"
        if sshd -T 2>/dev/null | grep -qi 'passwordauthentication yes'; then
            echo "   Auth:        ${GREEN}PASSWORD ENABLED${RESET}"
        else
            echo "   Auth:        ${YELLOW}PASSWORD DISABLED${RESET}"
        fi
    else
        echo "🔐 SSH:         ${RED}INACTIVE${RESET}"
    fi
    
    # Nginx status
    if command -v nginx >/dev/null 2>&1; then
        if systemctl is-active --quiet nginx; then
            echo "🌐 Nginx:       ${GREEN}ACTIVE${RESET}"
        else
            echo "🌐 Nginx:       ${YELLOW}INACTIVE${RESET}"
        fi
    else
        echo "🌐 Nginx:       ${YELLOW}NOT INSTALLED${RESET}"
    fi
    
    # Tailscale status
    if command -v tailscale >/dev/null 2>&1; then
        if tailscale status >/dev/null 2>&1; then
            echo "📡 Tailscale:   ${GREEN}CONNECTED${RESET}"
        else
            echo "📡 Tailscale:   ${YELLOW}INSTALLED (NOT CONNECTED)${RESET}"
        fi
    else
        echo "📡 Tailscale:   ${YELLOW}NOT INSTALLED${RESET}"
    fi
    
    # Log monitoring
    if systemctl is-active --quiet security-monitor.timer 2>/dev/null; then
        echo "📊 Log Monitor: ${GREEN}ACTIVE${RESET}"
    else
        echo "📊 Log Monitor: ${YELLOW}INACTIVE${RESET}"
    fi
    
    echo
    kernel_reboot_reminder
    show_reminders
}

# ---------- Reminders System ----------
readonly REMINDERS_DIR="/var/lib/ex1"
readonly REMINDERS_FILE="$REMINDERS_DIR/reminders.log"

init_reminders() {
    mkdir -p "$REMINDERS_DIR" 2>/dev/null || true
    touch "$REMINDERS_FILE" 2>/dev/null || true
}

record_reminder() {
    local reminder="$1"
    init_reminders
    echo "$(ts): $reminder" >> "$REMINDERS_FILE"
    info "Reminder recorded: $reminder"
}

show_reminders() {
    init_reminders
    if [ -s "$REMINDERS_FILE" ]; then
        echo "${BOLD}=== Security Reminders ===${RESET}"
        cat "$REMINDERS_FILE"
        echo "${BOLD}=========================${RESET}"
    else
        info "No security reminders"
    fi
}

clear_reminders() {
    if [ -f "$REMINDERS_FILE" ]; then
        rm -f "$REMINDERS_FILE"
        info "Reminders cleared"
    fi
}

kernel_reboot_reminder() {
    local running_kernel installed_kernels latest_kernel
    
    running_kernel="$(uname -r)"
    installed_kernels="$(dpkg -l | awk '/linux-image-.*-generic/{print $3}' | sort -V | tail -1 2>/dev/null || true)"
    
    if [ -n "$installed_kernels" ] && [ "${running_kernel%%-*}" != "${installed_kernels%%-*}" ]; then
        warn "Kernel update pending. Running: $running_kernel, Newest: $installed_kernels"
        record_reminder "Reboot required to activate new kernel ($installed_kernels)"
    fi
}

tailscale_reminder_if_needed() {
    if command -v tailscale >/dev/null 2>&1 && ! tailscale status >/dev/null 2>&1; then
        record_reminder "Run 'tailscale up' to configure Tailscale networking"
    fi
}

# ---------- Main Operations ----------
full_setup() {
    info "Starting comprehensive security setup"
    
    install_security_packages
    configure_firewall
    configure_fail2ban
    configure_nginx_security
    apply_system_hardening
    safe_ssh_hardening
    setup_log_monitoring
    
    kernel_reboot_reminder
    tailscale_reminder_if_needed
    
    info "Comprehensive security setup completed successfully"
    show_reminders
}

# ---------- Main Menu ----------
main_menu() {
    while true; do
        echo
        cat <<MENU
${BOLD}=== Enterprise Security Hardening Menu ===${RESET}
${GREEN} 1) Install security packages
 2) Install optional packages (Nginx/Tailscale)
 3) Configure firewall (UFW)
 4) Configure Fail2ban (intrusion prevention)
 5) Configure Nginx security headers
 6) Apply system hardening (sysctl)
 7) Safe SSH hardening
 8) Setup log monitoring
 9) Full security setup (all above)
10) Check security status
11) Create configuration backup
12) Show security reminders
13) Clear reminders
14) Exit${RESET}
MENU
        
        read -r -p "Select option (1-14): " choice
        
        case "${choice:-}" in
            1) install_security_packages ;;
            2) install_optional_packages ;;
            3) configure_firewall ;;
            4) configure_fail2ban ;;
            5) configure_nginx_security ;;
            6) apply_system_hardening ;;
            7) safe_ssh_hardening ;;
            8) setup_log_monitoring ;;
            9) full_setup ;;
            10) check_status ;;
            11) create_backup ;;
            12) show_reminders ;;
            13) clear_reminders ;;
            14) 
                info "Exiting security hardening tool"
                exit 0
                ;;
            *) 
                warn "Invalid selection. Please choose 1-14."
                ;;
        esac
        
        echo
        read -r -p "Press Enter to continue..."
    done
}

# ---------- Initialization ----------
initialize_script() {
    if [ "$(id -u)" -ne 0 ]; then
        err "This script must be run as root. Use: sudo bash $0"
        exit 1
    fi
    
    detect_environment
    init_reminders
    
    # Clean up any conflicting packages
    apt_purge_if_present iptables-persistent netfilter-persistent
    
    info "Enterprise Security Hardening Tool v$SCRIPT_VERSION initialized"
    info "Log file: $LOG"
}

# ---------- Main Execution ----------
initialize_script
main_menu

# Clean exit
exit 0