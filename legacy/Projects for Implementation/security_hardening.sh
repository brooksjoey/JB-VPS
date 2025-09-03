#!/bin/bash

# Security Hardening
# Automate firewall, fail2ban, and anti-crawler configurations

set -euo pipefail

# Configuration
CONFIG_FILE="config.conf"
LOG_FILE="logs/security_hardening.log"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Load configuration
load_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        source "$CONFIG_FILE"
    else
        log "WARNING: Configuration file not found: $CONFIG_FILE"
    fi
}

# Install required packages
install_packages() {
    log "Installing security packages..."
    
    # Detect OS
    if [[ -f /etc/debian_version ]]; then
        apt-get update
        apt-get install -y ufw fail2ban iptables-persistent nginx-extras
    elif [[ -f /etc/redhat-release ]]; then
        yum install -y firewalld fail2ban iptables-services
    else
        log "Unsupported OS for automatic package installation"
        return 1
    fi
    
    log "Security packages installed successfully"
}

# Configure firewall rules
configure_firewall() {
    log "Configuring firewall rules..."
    
    # UFW configuration (Debian/Ubuntu)
    if command -v ufw &> /dev/null; then
        # Reset UFW
        ufw --force reset
        
        # Default policies
        ufw default deny incoming
        ufw default allow outgoing
        
        # Allow SSH (be careful!)
        ufw allow 22/tcp
        
        # Allow HTTP/HTTPS
        ufw allow 80/tcp
        ufw allow 443/tcp
        
        # Allow DNS
        ufw allow 53
        
        # Rate limiting for SSH
        ufw limit ssh/tcp
        
        # Enable UFW
        ufw --force enable
        
        log "UFW firewall configured"
        
    # Firewalld configuration (CentOS/RHEL)
    elif command -v firewall-cmd &> /dev/null; then
        systemctl start firewalld
        systemctl enable firewalld
        
        # Configure zones
        firewall-cmd --set-default-zone=drop
        firewall-cmd --zone=public --add-service=http --permanent
        firewall-cmd --zone=public --add-service=https --permanent
        firewall-cmd --zone=public --add-service=ssh --permanent
        firewall-cmd --zone=public --add-service=dns --permanent
        
        # Rate limiting
        firewall-cmd --zone=public --add-rich-rule='rule service name="ssh" limit value="3/m" accept' --permanent
        
        firewall-cmd --reload
        
        log "Firewalld configured"
        
    # IPTables configuration (fallback)
    else
        # Backup existing rules
        iptables-save > /tmp/iptables_backup_$(date +%s).rules
        
        # Flush existing rules
        iptables -F
        iptables -X
        iptables -t nat -F
        iptables -t nat -X
        iptables -t mangle -F
        iptables -t mangle -X
        
        # Default policies
        iptables -P INPUT DROP
        iptables -P FORWARD DROP
        iptables -P OUTPUT ACCEPT
        
        # Allow loopback
        iptables -I INPUT -i lo -j ACCEPT
        
        # Allow established connections
        iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
        
        # Allow SSH with rate limiting
        iptables -A INPUT -p tcp --dport 22 -m conntrack --ctstate NEW -m limit --limit 3/min --limit-burst 3 -j ACCEPT
        
        # Allow HTTP/HTTPS
        iptables -A INPUT -p tcp --dport 80 -j ACCEPT
        iptables -A INPUT -p tcp --dport 443 -j ACCEPT
        
        # Allow DNS
        iptables -A INPUT -p udp --dport 53 -j ACCEPT
        iptables -A INPUT -p tcp --dport 53 -j ACCEPT
        
        # Save rules
        if command -v iptables-save &> /dev/null; then
            iptables-save > /etc/iptables/rules.v4
        fi
        
        log "IPTables configured"
    fi
}

# Configure fail2ban
configure_fail2ban() {
    log "Configuring fail2ban..."
    
    # Create custom jail configuration
    cat > /etc/fail2ban/jail.local << 'EOF'
[DEFAULT]
# Ban time (seconds)
bantime = 3600
# Find time (seconds)
findtime = 600
# Max retry attempts
maxretry = 3

# Email notifications
destemail = root@localhost
sender = fail2ban@localhost

# Action on ban
action = %(action_mwl)s

[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime = 3600

[nginx-http-auth]
enabled = true
filter = nginx-http-auth
port = http,https
logpath = /var/log/nginx/error.log
maxretry = 3
bantime = 1800

[nginx-limit-req]
enabled = true
filter = nginx-limit-req
port = http,https
logpath = /var/log/nginx/error.log
maxretry = 10
bantime = 600

[nginx-botsearch]
enabled = true
filter = nginx-botsearch
port = http,https
logpath = /var/log/nginx/access.log
maxretry = 2
bantime = 86400

[recidive]
enabled = true
filter = recidive
logpath = /var/log/fail2ban.log
action = %(action_mwl)s
bantime = 604800
findtime = 86400
maxretry = 5
EOF

    # Create custom filters
    mkdir -p /etc/fail2ban/filter.d
    
    # Bot search filter
    cat > /etc/fail2ban/filter.d/nginx-botsearch.conf << 'EOF'
[Definition]
failregex = ^<HOST> -.*"(GET|POST).*/(wp-admin|wp-login|xmlrpc|admin|phpmyadmin|\.env|\.git|\.svn|\.htaccess).*" (404|403|401)
            ^<HOST> -.*"(GET|POST).*(nmap|nikto|sqlmap|nessus|openvas|w3af|burp|zap).*"
            ^<HOST> -.*"(GET|POST).*(select|union|insert|delete|drop|create|alter).*"
ignoreregex =
EOF

    # Start and enable fail2ban
    systemctl start fail2ban
    systemctl enable fail2ban
    
    log "Fail2ban configured and started"
}

# Configure Nginx anti-crawler measures
configure_nginx_security() {
    log "Configuring Nginx security measures..."
    
    # Create security configuration
    cat > /etc/nginx/conf.d/security.conf << 'EOF'
# Hide Nginx version
server_tokens off;
more_clear_headers Server;

# Limit request methods
map $request_method $not_allowed_method {
    default 1;
    GET 0;
    POST 0;
    HEAD 0;
}

# Rate limiting
limit_req_zone $binary_remote_addr zone=login:10m rate=5r/m;
limit_req_zone $binary_remote_addr zone=global:10m rate=10r/s;
limit_conn_zone $binary_remote_addr zone=conn_limit_per_ip:10m;

# Geo blocking (customize as needed)
geo $blocked_country {
    default 0;
    # Add countries to block
    # CN 1;  # China
    # RU 1;  # Russia
}

# Bot detection
map $http_user_agent $bot {
    default 0;
    ~*nmap 1;
    ~*nikto 1;
    ~*sqlmap 1;
    ~*nessus 1;
    ~*openvas 1;
    ~*w3af 1;
    ~*burp 1;
    ~*zap 1;
    ~*crawler 1;
    ~*spider 1;
    ~*scanner 1;
    ~*bot 1;
}

# Security headers
add_header X-Frame-Options SAMEORIGIN always;
add_header X-Content-Type-Options nosniff always;
add_header X-XSS-Protection "1; mode=block" always;
add_header Referrer-Policy "strict-origin-when-cross-origin" always;
add_header Content-Security-Policy "default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; style-src 'self' 'unsafe-inline';" always;

# Block common attack patterns
location ~* \.(env|git|svn|htaccess|htpasswd)$ {
    return 444;
}

location ~* /(wp-admin|wp-login|xmlrpc|admin|phpmyadmin) {
    return 444;
}

# Block if bot detected
if ($bot) {
    return 444;
}

# Block if country blocked
if ($blocked_country) {
    return 444;
}

# Block if not allowed method
if ($not_allowed_method) {
    return 405;
}
EOF

    # Create honeypot configuration
    cat > /etc/nginx/conf.d/honeypot.conf << 'EOF'
# Honeypot locations to catch scanners
location /admin {
    access_log /var/log/nginx/honeypot.log combined;
    return 444;
}

location /wp-admin {
    access_log /var/log/nginx/honeypot.log combined;
    return 444;
}

location /phpmyadmin {
    access_log /var/log/nginx/honeypot.log combined;
    return 444;
}

location /.env {
    access_log /var/log/nginx/honeypot.log combined;
    return 444;
}

location /robots.txt {
    access_log /var/log/nginx/robots.log combined;
    return 200 "User-agent: *\nDisallow: /\n";
    add_header Content-Type text/plain;
}
EOF

    # Test configuration and reload
    nginx -t && systemctl reload nginx
    
    log "Nginx security configuration applied"
}

# Configure system hardening
configure_system_hardening() {
    log "Applying system hardening..."
    
    # Disable unnecessary services
    local services_to_disable=(
        "avahi-daemon"
        "cups"
        "bluetooth"
        "rpcbind"
        "nfs-server"
        "postfix"
    )
    
    for service in "${services_to_disable[@]}"; do
        if systemctl is-enabled "$service" &>/dev/null; then
            systemctl stop "$service" 2>/dev/null || true
            systemctl disable "$service" 2>/dev/null || true
            log "Disabled service: $service"
        fi
    done
    
    # Secure shared memory
    if ! grep -q "tmpfs /run/shm" /etc/fstab; then
        echo "tmpfs /run/shm tmpfs defaults,noexec,nosuid 0 0" >> /etc/fstab
        log "Secured shared memory"
    fi
    
    # Disable core dumps
    echo "* hard core 0" >> /etc/security/limits.conf
    echo "fs.suid_dumpable = 0" >> /etc/sysctl.conf
    
    # Network security
    cat >> /etc/sysctl.conf << 'EOF'
# Network security
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
net.ipv4.conf.all.rp_filter = 1
net.ipv4.conf.default.rp_filter = 1
net.ipv4.tcp_syncookies = 1
EOF
    
    # Apply sysctl changes
    sysctl -p
    
    log "System hardening applied"
}

# Configure SSH hardening
configure_ssh_hardening() {
    log "Hardening SSH configuration..."
    
    # Backup original config
    cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup.$(date +%s)
    
    # Apply SSH hardening
    cat >> /etc/ssh/sshd_config << 'EOF'

# SSH Hardening
Protocol 2
Port 22
PermitRootLogin no
MaxAuthTries 3
MaxSessions 2
PasswordAuthentication no
PermitEmptyPasswords no
ChallengeResponseAuthentication no
UsePAM yes
X11Forwarding no
PrintMotd no
ClientAliveInterval 300
ClientAliveCountMax 2
AllowUsers $(whoami)
EOF

    # Test SSH config and restart
    sshd -t && systemctl restart sshd
    
    log "SSH hardening applied"
}

# Setup log monitoring
setup_log_monitoring() {
    log "Setting up log monitoring..."
    
    # Create log monitoring script
    cat > /usr/local/bin/security_monitor.sh << 'EOF'
#!/bin/bash

LOG_FILE="/var/log/security_monitor.log"
ALERT_EMAIL="${ALERT_EMAIL:-root@localhost}"

# Function to send alert
send_alert() {
    local message="$1"
    echo "[$(date)] $message" >> "$LOG_FILE"
    
    # Send email if configured
    if [[ -n "$ALERT_EMAIL" ]]; then
        echo "$message" | mail -s "Security Alert" "$ALERT_EMAIL" 2>/dev/null || true
    fi
}

# Monitor authentication logs
tail -F /var/log/auth.log | while read line; do
    # Check for failed login attempts
    if echo "$line" | grep -q "Failed password"; then
        ip=$(echo "$line" | grep -oP 'from \K[0-9.]+')
        send_alert "Failed login attempt from IP: $ip"
    fi
    
    # Check for successful logins
    if echo "$line" | grep -q "Accepted"; then
        ip=$(echo "$line" | grep -oP 'from \K[0-9.]+')
        user=$(echo "$line" | grep -oP 'for \K\w+')
        send_alert "Successful login: $user from IP: $ip"
    fi
done &

# Monitor Nginx logs for attacks
tail -F /var/log/nginx/access.log | while read line; do
    # Check for SQL injection attempts
    if echo "$line" | grep -iE "(union|select|insert|delete|drop|create|alter)"; then
        ip=$(echo "$line" | awk '{print $1}')
        send_alert "SQL injection attempt from IP: $ip - $line"
    fi
    
    # Check for scanner activity
    if echo "$line" | grep -iE "(nmap|nikto|sqlmap|nessus|openvas)"; then
        ip=$(echo "$line" | awk '{print $1}')
        send_alert "Scanner activity detected from IP: $ip - $line"
    fi
done &
EOF

    chmod +x /usr/local/bin/security_monitor.sh
    
    # Create systemd service
    cat > /etc/systemd/system/security-monitor.service << 'EOF'
[Unit]
Description=Security Log Monitor
After=network.target

[Service]
Type=forking
ExecStart=/usr/local/bin/security_monitor.sh
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable security-monitor
    systemctl start security-monitor
    
    log "Log monitoring setup completed"
}

# Create backup and restore functions
create_backup() {
    local backup_dir="/var/backups/security_configs"
    local timestamp=$(date +%Y%m%d_%H%M%S)
    
    mkdir -p "$backup_dir"
    
    # Backup configurations
    cp /etc/nginx/nginx.conf "$backup_dir/nginx.conf.$timestamp" 2>/dev/null || true
    cp /etc/fail2ban/jail.local "$backup_dir/fail2ban.conf.$timestamp" 2>/dev/null || true
    cp /etc/ssh/sshd_config "$backup_dir/sshd_config.$timestamp" 2>/dev/null || true
    
    # Backup firewall rules
    if command -v ufw &> /dev/null; then
        ufw show added > "$backup_dir/ufw_rules.$timestamp"
    elif command -v firewall-cmd &> /dev/null; then
        firewall-cmd --list-all > "$backup_dir/firewalld_rules.$timestamp"
    else
        iptables-save > "$backup_dir/iptables_rules.$timestamp"
    fi
    
    log "Security configuration backup created: $backup_dir/*.$timestamp"
}

# Status check function
check_security_status() {
    echo -e "${BLUE}=== Security Status Check ===${NC}"
    
    # Firewall status
    echo -n "Firewall: "
    if command -v ufw &> /dev/null; then
        if ufw status | grep -q "Status: active"; then
            echo -e "${GREEN}Active (UFW)${NC}"
        else
            echo -e "${RED}Inactive${NC}"
        fi
    elif command -v firewall-cmd &> /dev/null; then
        if firewall-cmd --state &>/dev/null; then
            echo -e "${GREEN}Active (Firewalld)${NC}"
        else
            echo -e "${RED}Inactive${NC}"
        fi
    else
        echo -e "${YELLOW}IPTables (unknown status)${NC}"
    fi
    
    # Fail2ban status
    echo -n "Fail2ban: "
    if systemctl is-active fail2ban &>/dev/null; then
        echo -e "${GREEN}Active${NC}"
        fail2ban-client status | grep "Jail list" | cut -d: -f2 | tr -d ' ' | tr ',' '\n' | sed 's/^/  - /'
    else
        echo -e "${RED}Inactive${NC}"
    fi
    
    # SSH status
    echo -n "SSH: "
    if systemctl is-active ssh &>/dev/null || systemctl is-active sshd &>/dev/null; then
        echo -e "${GREEN}Active${NC}"
        echo "  - Port: $(grep "^Port" /etc/ssh/sshd_config | awk '{print $2}' || echo "22")"
        echo "  - Root login: $(grep "^PermitRootLogin" /etc/ssh/sshd_config | awk '{print $2}' || echo "unknown")"
    else
        echo -e "${RED}Inactive${NC}"
    fi
    
    # Nginx status
    echo -n "Nginx: "
    if systemctl is-active nginx &>/dev/null; then
        echo -e "${GREEN}Active${NC}"
        if [[ -f /etc/nginx/conf.d/security.conf ]]; then
            echo "  - Security config: ${GREEN}Enabled${NC}"
        else
            echo "  - Security config: ${RED}Not configured${NC}"
        fi
    else
        echo -e "${RED}Inactive${NC}"
    fi
    
    # Log monitoring
    echo -n "Log monitoring: "
    if systemctl is-active security-monitor &>/dev/null; then
        echo -e "${GREEN}Active${NC}"
    else
        echo -e "${RED}Inactive${NC}"
    fi
}

# Main menu
show_menu() {
    echo -e "${BLUE}=== Security Hardening for Evilginx2 v3.4.1 ===${NC}"
    echo "1) Install security packages"
    echo "2) Configure firewall"
    echo "3) Configure fail2ban"
    echo "4) Configure Nginx security"
    echo "5) Apply system hardening"
    echo "6) Harden SSH configuration"
    echo "7) Setup log monitoring"
    echo "8) Full security setup (all above)"
    echo "9) Check security status"
    echo "10) Create configuration backup"
    echo "11) Exit"
    echo -n "Select option: "
}

# Main execution
main() {
    mkdir -p logs
    load_config
    
    # Check if running as root
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}This script must be run as root${NC}"
        exit 1
    fi
    
    case "${1:-menu}" in
        "install")
            install_packages
            ;;
        "firewall")
            configure_firewall
            ;;
        "fail2ban")
            configure_fail2ban
            ;;
        "nginx")
            configure_nginx_security
            ;;
        "system")
            configure_system_hardening
            ;;
        "ssh")
            configure_ssh_hardening
            ;;
        "monitoring")
            setup_log_monitoring
            ;;
        "full")
            install_packages
            configure_firewall
            configure_fail2ban
            configure_nginx_security
            configure_system_hardening
            configure_ssh_hardening
            setup_log_monitoring
            log "Full security hardening completed"
            ;;
        "status")
            check_security_status
            ;;
        "backup")
            create_backup
            ;;
        *)
            while true; do
                show_menu
                read -r choice
                
                case $choice in
                    1) install_packages ;;
                    2) configure_firewall ;;
                    3) configure_fail2ban ;;
                    4) configure_nginx_security ;;
                    5) configure_system_hardening ;;
                    6) configure_ssh_hardening ;;
                    7) setup_log_monitoring ;;
                    8)
                        echo "This will apply all security hardening measures. Continue? (y/N)"
                        read -r confirm
                        if [[ "$confirm" =~ ^[Yy]$ ]]; then
                            install_packages
                            configure_firewall
                            configure_fail2ban
                            configure_nginx_security
                            configure_system_hardening
                            configure_ssh_hardening
                            setup_log_monitoring
                            log "Full security hardening completed"
                        fi
                        ;;
                    9) check_security_status ;;
                    10) create_backup ;;
                    11) echo "Exiting..."; exit 0 ;;
                    *) echo -e "${RED}Invalid option${NC}" ;;
                esac
                echo
            done
            ;;
    esac
}

# Run main function
main "$@"
