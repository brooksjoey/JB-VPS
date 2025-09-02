#!/bin/bash

# SSL/TLS Certificate Automation for Evilginx2 v3.4.1
# Supports both acme.sh and certbot for automated certificate management

set -euo pipefail

# Configuration
CONFIG_FILE="config.conf"
CERT_DIR="/etc/letsencrypt/live"
ACME_DIR="$HOME/.acme.sh"
LOG_FILE="logs/ssl_cert_manager.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Load configuration
load_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        source "$CONFIG_FILE"
    else
        echo -e "${RED}Configuration file not found: $CONFIG_FILE${NC}"
        exit 1
    fi
}

# Check if domain is valid
validate_domain() {
    local domain="$1"
    if [[ ! "$domain" =~ ^[a-zA-Z0-9][a-zA-Z0-9-]*[a-zA-Z0-9]*\.[a-zA-Z]{2,}$ ]]; then
        echo -e "${RED}Invalid domain format: $domain${NC}"
        return 1
    fi
    return 0
}

# Install acme.sh if not present
install_acme() {
    if [[ ! -d "$ACME_DIR" ]]; then
        log "Installing acme.sh..."
        curl https://get.acme.sh | sh -s email="$ADMIN_EMAIL"
        source ~/.bashrc
    fi
}

# Install certbot if not present
install_certbot() {
    if ! command -v certbot &> /dev/null; then
        log "Installing certbot..."
        if [[ -f /etc/debian_version ]]; then
            apt-get update && apt-get install -y certbot
        elif [[ -f /etc/redhat-release ]]; then
            yum install -y certbot || dnf install -y certbot
        else
            log "Unsupported OS for automatic certbot installation"
            exit 1
        fi
    fi
}

# Get certificate using acme.sh
get_cert_acme() {
    local domain="$1"
    local dns_provider="${2:-dns_cf}"
    
    log "Obtaining certificate for $domain using acme.sh with $dns_provider"
    
    export CF_Token="$CLOUDFLARE_API_TOKEN"
    export CF_Account_ID="$CLOUDFLARE_ACCOUNT_ID"
    
    "$ACME_DIR/acme.sh" --issue --dns "$dns_provider" -d "$domain" -d "*.$domain"
    
    if [[ $? -eq 0 ]]; then
        log "Certificate obtained successfully for $domain"
        return 0
    else
        log "Failed to obtain certificate for $domain"
        return 1
    fi
}

# Get certificate using certbot
get_cert_certbot() {
    local domain="$1"
    local method="${2:-standalone}"
    
    log "Obtaining certificate for $domain using certbot with $method method"
    
    if [[ "$method" == "dns-cloudflare" ]]; then
        echo "dns_cloudflare_api_token = $CLOUDFLARE_API_TOKEN" > /tmp/cloudflare.ini
        chmod 600 /tmp/cloudflare.ini
        certbot certonly --dns-cloudflare --dns-cloudflare-credentials /tmp/cloudflare.ini -d "$domain" -d "*.$domain" --non-interactive --agree-tos --email "$ADMIN_EMAIL"
        rm /tmp/cloudflare.ini
    else
        certbot certonly --standalone -d "$domain" --non-interactive --agree-tos --email "$ADMIN_EMAIL"
    fi
    
    if [[ $? -eq 0 ]]; then
        log "Certificate obtained successfully for $domain"
        return 0
    else
        log "Failed to obtain certificate for $domain"
        return 1
    fi
}

# Install certificate for Evilginx2
install_cert_evilginx() {
    local domain="$1"
    local cert_method="$2"
    
    if [[ "$cert_method" == "acme" ]]; then
        cert_path="$ACME_DIR/$domain"
        fullchain="$cert_path/fullchain.cer"
        privkey="$cert_path/$domain.key"
    else
        cert_path="$CERT_DIR/$domain"
        fullchain="$cert_path/fullchain.pem"
        privkey="$cert_path/privkey.pem"
    fi
    
    if [[ -f "$fullchain" && -f "$privkey" ]]; then
        log "Installing certificate for $domain in Evilginx2"
        
        # Copy certificates to Evilginx2 directory
        mkdir -p "certs/$domain"
        cp "$fullchain" "certs/$domain/fullchain.pem"
        cp "$privkey" "certs/$domain/privkey.pem"
        
        # Set proper permissions
        chmod 600 "certs/$domain/privkey.pem"
        chmod 644 "certs/$domain/fullchain.pem"
        
        log "Certificate installed successfully for $domain"
        return 0
    else
        log "Certificate files not found for $domain"
        return 1
    fi
}

# Renew certificates
renew_certificates() {
    log "Starting certificate renewal process"
    
    if [[ -d "$ACME_DIR" ]]; then
        log "Renewing acme.sh certificates"
        "$ACME_DIR/acme.sh" --cron --home "$ACME_DIR"
    fi
    
    if command -v certbot &> /dev/null; then
        log "Renewing certbot certificates"
        certbot renew --quiet
    fi
    
    # Restart services if needed
    if systemctl is-active --quiet nginx; then
        systemctl reload nginx
    fi
    
    if systemctl is-active --quiet haproxy; then
        systemctl reload haproxy
    fi
    
    log "Certificate renewal completed"
}

# Check certificate expiry
check_cert_expiry() {
    local domain="$1"
    local cert_file="certs/$domain/fullchain.pem"
    
    if [[ -f "$cert_file" ]]; then
        local expiry_date=$(openssl x509 -enddate -noout -in "$cert_file" | cut -d= -f2)
        local expiry_epoch=$(date -d "$expiry_date" +%s)
        local current_epoch=$(date +%s)
        local days_until_expiry=$(( (expiry_epoch - current_epoch) / 86400 ))
        
        echo "$days_until_expiry"
    else
        echo "-1"
    fi
}

# Monitor certificate expiry
monitor_certificates() {
    log "Monitoring certificate expiry"
    
    for cert_dir in certs/*/; do
        if [[ -d "$cert_dir" ]]; then
            domain=$(basename "$cert_dir")
            days_left=$(check_cert_expiry "$domain")
            
            if [[ "$days_left" -lt 30 && "$days_left" -gt 0 ]]; then
                log "WARNING: Certificate for $domain expires in $days_left days"
                # Send alert email or notification here
            elif [[ "$days_left" -le 0 ]]; then
                log "CRITICAL: Certificate for $domain has expired!"
                # Send critical alert here
            else
                log "Certificate for $domain is valid for $days_left days"
            fi
        fi
    done
}

# Setup auto-renewal cron job
setup_auto_renewal() {
    log "Setting up auto-renewal cron job"
    
    # Add cron job for certificate renewal (runs daily at 2 AM)
    (crontab -l 2>/dev/null; echo "0 2 * * * $(realpath "$0") renew >> $LOG_FILE 2>&1") | crontab -
    
    # Add cron job for certificate monitoring (runs weekly)
    (crontab -l 2>/dev/null; echo "0 9 * * 1 $(realpath "$0") monitor >> $LOG_FILE 2>&1") | crontab -
    
    log "Auto-renewal cron jobs configured"
}

# Main menu
show_menu() {
    echo -e "${BLUE}=== SSL/TLS Certificate Manager for Evilginx2 v3.4.1 ===${NC}"
    echo "1) Obtain certificate (acme.sh)"
    echo "2) Obtain certificate (certbot)"
    echo "3) Renew all certificates"
    echo "4) Monitor certificate expiry"
    echo "5) Setup auto-renewal"
    echo "6) Check domain certificate status"
    echo "7) Exit"
    echo -n "Select option: "
}

# Main execution
main() {
    # Create required directories
    mkdir -p logs certs
    
    load_config
    
    case "${1:-}" in
        "renew")
            renew_certificates
            ;;
        "monitor")
            monitor_certificates
            ;;
        *)
            while true; do
                show_menu
                read -r choice
                
                case $choice in
                    1)
                        echo -n "Enter domain: "
                        read -r domain
                        if validate_domain "$domain"; then
                            install_acme
                            if get_cert_acme "$domain"; then
                                install_cert_evilginx "$domain" "acme"
                            fi
                        fi
                        ;;
                    2)
                        echo -n "Enter domain: "
                        read -r domain
                        if validate_domain "$domain"; then
                            install_certbot
                            echo "1) Standalone"
                            echo "2) DNS (Cloudflare)"
                            echo -n "Select method: "
                            read -r method_choice
                            
                            if [[ "$method_choice" == "2" ]]; then
                                if get_cert_certbot "$domain" "dns-cloudflare"; then
                                    install_cert_evilginx "$domain" "certbot"
                                fi
                            else
                                if get_cert_certbot "$domain" "standalone"; then
                                    install_cert_evilginx "$domain" "certbot"
                                fi
                            fi
                        fi
                        ;;
                    3)
                        renew_certificates
                        ;;
                    4)
                        monitor_certificates
                        ;;
                    5)
                        setup_auto_renewal
                        ;;
                    6)
                        echo -n "Enter domain: "
                        read -r domain
                        days_left=$(check_cert_expiry "$domain")
                        if [[ "$days_left" -eq -1 ]]; then
                            echo -e "${RED}No certificate found for $domain${NC}"
                        else
                            echo -e "${GREEN}Certificate for $domain expires in $days_left days${NC}"
                        fi
                        ;;
                    7)
                        echo "Exiting..."
                        exit 0
                        ;;
                    *)
                        echo -e "${RED}Invalid option${NC}"
                        ;;
                esac
                echo
            done
            ;;
    esac
}

# Run main function
main "$@"
