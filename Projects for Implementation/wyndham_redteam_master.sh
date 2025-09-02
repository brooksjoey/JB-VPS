#!/bin/bash
# === wyndham PROPERTIES RED TEAM MASTER SCRIPT ===
# Coordinates the complete authorized phishing campaign
# For use with signed authorization letter only

set -euo pipefail
IFS=$'\n\t'

### === CONFIG ===
CAMPAIGN_NAME="wyndham_okta_2024"
TARGET_DOMAIN="wyndhamhotels.com"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

### === COLORS ===
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

### === FUNCTIONS ===
log() { echo -e "${BLUE}[MASTER]${NC} $*"; }
success() { echo -e "${GREEN}[✓]${NC} $*"; }
warning() { echo -e "${YELLOW}[!]${NC} $*"; }
error() { echo -e "${RED}[✗]${NC} $*"; }
phase() { echo -e "${PURPLE}[PHASE]${NC} $*"; }

print_banner() {
    echo -e "${CYAN}"
    cat << "EOF"
    ██╗    ██╗██╗   ██╗███╗   ██╗██╗  ██╗ █████╗ ███╗   ███╗
    ██║    ██║╚██╗ ██╔╝████╗  ██║██║  ██║██╔══██╗████╗ ████║
    ██║ █╗ ██║ ╚████╔╝ ██╔██╗ ██║███████║███████║██╔████╔██║
    ██║███╗██║  ╚██╔╝  ██║╚██╗██║██╔══██║██╔══██║██║╚██╔╝██║
    ╚███╔███╔╝   ██║   ██║ ╚████║██║  ██║██║  ██║██║ ╚═╝ ██║
     ╚══╝╚══╝    ╚═╝   ╚═╝  ╚═══╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝     ╚═╝
    
    🎯 RED TEAM CAMPAIGN MASTER CONTROLLER
    Target: wyndham Properties (Authorized Testing)
EOF
    echo -e "${NC}"
}

check_authorization() {
    warning "CRITICAL: AUTHORIZATION CHECK"
    echo ""
    echo "This script is designed for AUTHORIZED red team testing only."
    echo "You must have written permission from wyndham Properties before proceeding."
    echo ""
    read -p "Do you have a signed authorization letter? (yes/no): " auth_check
    
    if [[ ! "$auth_check" =~ ^[Yy][Ee][Ss]$ ]]; then
        error "Unauthorized use is illegal. Exiting."
        exit 1
    fi
    
    success "Authorization confirmed. Proceeding with campaign setup."
}

check_prerequisites() {
    phase "Checking Prerequisites"
    
    local missing_tools=()
    
    # Check for required tools
    command -v dig >/dev/null 2>&1 || missing_tools+=("dig")
    command -v curl >/dev/null 2>&1 || missing_tools+=("curl")
    command -v host >/dev/null 2>&1 || missing_tools+=("host")
    
    # Check for Evilginx2
    if [ ! -f "/opt/evilginx/evilginx" ]; then
        warning "Evilginx2 not found at /opt/evilginx/"
    fi
    
    # Check for campaign scripts
    local scripts=("launch_okta_campaign.sh" "generate_okta_email.sh" "recon_wyndham.sh")
    for script in "${scripts[@]}"; do
        if [ ! -f "$SCRIPT_DIR/$script" ]; then
            missing_tools+=("$script")
        fi
    done
    
    if [ ${#missing_tools[@]} -gt 0 ]; then
        error "Missing required tools/files:"
        printf '  • %s\n' "${missing_tools[@]}"
        exit 1
    fi
    
    success "All prerequisites satisfied"
}

show_campaign_status() {
    phase "Campaign Status Overview"
    
    echo ""
    echo "📋 CAMPAIGN CONFIGURATION"
    echo "  Campaign Name: $CAMPAIGN_NAME"
    echo "  Target Domain: $TARGET_DOMAIN"
    echo "  Script Directory: $SCRIPT_DIR"
    echo ""
    
    echo "📁 AVAILABLE TOOLS"
    echo "  ✓ Reconnaissance Script (recon_wyndham.sh)"
    echo "  ✓ Campaign Launcher (launch_okta_campaign.sh)"
    echo "  ✓ Email Generator (generate_okta_email.sh)"
    echo "  ✓ Okta Phishlet (phishlets_okta.yaml)"
    echo "  ✓ HTML Lure Template (okta.html)"
    echo ""
    
    echo "🎯 CAMPAIGN PHASES"
    echo "  1. Reconnaissance & Target Gathering"
    echo "  2. Infrastructure Setup"
    echo "  3. Email Template Generation"
    echo "  4. Campaign Launch"
    echo "  5. Monitoring & Harvesting"
    echo ""
}

run_reconnaissance() {
    phase "Phase 1: Reconnaissance"
    
    echo "Starting reconnaissance against $TARGET_DOMAIN..."
    echo ""
    
    if [ -f "$SCRIPT_DIR/recon_wyndham.sh" ]; then
        "$SCRIPT_DIR/recon_wyndham.sh"
        success "Reconnaissance completed"
        echo ""
        echo "📊 Next steps:"
        echo "  • Review files in ./recon_output/"
        echo "  • Manually search LinkedIn for employees"
        echo "  • Populate target list with real email addresses"
    else
        error "Reconnaissance script not found"
        return 1
    fi
}

setup_infrastructure() {
    phase "Phase 2: Infrastructure Setup"
    
    echo "Setting up Evilginx2 campaign infrastructure..."
    echo ""
    
    warning "MANUAL STEPS REQUIRED:"
    echo "  1. Register your phishing domain"
    echo "  2. Configure DNS to point to this server"
    echo "  3. Update domain in launch_okta_campaign.sh"
    echo "  4. Ensure SSL certificates are ready"
    echo ""
    
    read -p "Have you completed the infrastructure setup? (yes/no): " infra_check
    
    if [[ "$infra_check" =~ ^[Yy][Ee][Ss]$ ]]; then
        if [ -f "$SCRIPT_DIR/launch_okta_campaign.sh" ]; then
            "$SCRIPT_DIR/launch_okta_campaign.sh"
            success "Infrastructure setup completed"
        else
            error "Campaign launcher not found"
            return 1
        fi
    else
        warning "Complete infrastructure setup before proceeding"
        return 1
    fi
}

generate_emails() {
    phase "Phase 3: Email Template Generation"
    
    echo "Generating phishing email templates..."
    echo ""
    
    if [ -f "$SCRIPT_DIR/generate_okta_email.sh" ]; then
        "$SCRIPT_DIR/generate_okta_email.sh"
        success "Email templates generated"
        echo ""
        echo "📧 Available templates:"
        echo "  • Suspicious login alert"
        echo "  • Password reset request"
        echo "  • MFA setup requirement"
        echo ""
        echo "📝 Remember to:"
        echo "  • Customize templates with your domain"
        echo "  • Test emails before sending"
        echo "  • Prepare target list"
    else
        error "Email generator not found"
        return 1
    fi
}

campaign_checklist() {
    phase "Pre-Launch Checklist"
    
    echo ""
    echo "✅ FINAL CHECKLIST BEFORE LAUNCH"
    echo ""
    
    local checklist=(
        "Authorization letter from wyndham Properties signed and filed"
        "Phishing domain registered and DNS configured"
        "Evilginx2 server properly configured with SSL"
        "Target employee list populated with real email addresses"
        "Email templates customized and tested"
        "Monitoring and logging systems ready"
        "Incident response plan prepared"
        "Campaign timeline and scope documented"
    )
    
    for item in "${checklist[@]}"; do
        echo "  ☐ $item"
    done
    
    echo ""
    warning "Only proceed if ALL items are completed!"
}

show_menu() {
    echo ""
    echo "🎮 CAMPAIGN CONTROL MENU"
    echo ""
    echo "1) Run Reconnaissance"
    echo "2) Setup Infrastructure" 
    echo "3) Generate Email Templates"
    echo "4) Show Pre-Launch Checklist"
    echo "5) View Campaign Status"
    echo "6) Exit"
    echo ""
    read -p "Select option [1-6]: " choice
    
    case $choice in
        1) run_reconnaissance ;;
        2) setup_infrastructure ;;
        3) generate_emails ;;
        4) campaign_checklist ;;
        5) show_campaign_status ;;
        6) log "Exiting master controller"; exit 0 ;;
        *) warning "Invalid option. Please try again." ;;
    esac
}

### === MAIN EXECUTION ===
main() {
    print_banner
    check_authorization
    check_prerequisites
    show_campaign_status
    
    # Interactive menu loop
    while true; do
        show_menu
        echo ""
        read -p "Press Enter to continue..."
    done
}

# Handle script arguments
case "${1:-menu}" in
    "recon")
        print_banner
        check_authorization
        run_reconnaissance
        ;;
    "setup")
        print_banner
        check_authorization
        setup_infrastructure
        ;;
    "emails")
        print_banner
        check_authorization
        generate_emails
        ;;
    "checklist")
        print_banner
        campaign_checklist
        ;;
    "status")
        print_banner
        show_campaign_status
        ;;
    *)
        main "$@"
        ;;
esac
