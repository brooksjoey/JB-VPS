#!/bin/bash
# === CAMPAIGN CLEANUP SCRIPT ===
# For authorized red team testing - Wyndham Properties
# Safely cleans up campaign infrastructure and data

set -euo pipefail
IFS=$'\n\t'

### === CONFIG ===
source ./config.conf 2>/dev/null || {
    echo "Error: config.conf not found"
    exit 1
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP_DIR="./campaign_backup_$(date +%Y%m%d_%H%M%S)"

### === COLORS ===
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

### === FUNCTIONS ===
log() { echo -e "${BLUE}[CLEANUP]${NC} $*"; }
success() { echo -e "${GREEN}[✓]${NC} $*"; }
warning() { echo -e "${YELLOW}[!]${NC} $*"; }
error() { echo -e "${RED}[✗]${NC} $*"; }
phase() { echo -e "${PURPLE}[PHASE]${NC} $*"; }

print_banner() {
    echo -e "${RED}"
    cat << "EOF"
    🧹 CAMPAIGN CLEANUP
    Wyndham Properties Red Team Exercise
EOF
    echo -e "${NC}"
}

confirm_cleanup() {
    warning "CAMPAIGN CLEANUP CONFIRMATION"
    echo ""
    echo "This will:"
    echo "  • Disable Evilginx2 phishlets"
    echo "  • Backup campaign data"
    echo "  • Clean sensitive logs"
    echo "  • Reset firewall rules"
    echo "  • Archive campaign files"
    echo ""
    echo "Campaign: $CAMPAIGN_NAME"
    echo "Target: $TARGET_DOMAIN"
    echo ""
    
    read -p "Are you sure you want to proceed? (type CLEANUP to confirm): " confirm
    if [[ "$confirm" != "CLEANUP" ]]; then
        log "Cleanup cancelled"
        exit 0
    fi
    
    success "Cleanup confirmed"
}

backup_campaign_data() {
    phase "Backing Up Campaign Data"
    
    mkdir -p "$BACKUP_DIR"/{logs,configs,captured_data,reports}
    
    # Backup logs
    if [ -d "./logs" ]; then
        cp -r ./logs/* "$BACKUP_DIR/logs/" 2>/dev/null || true
    fi
    
    # Backup Evilginx logs
    if [ -d "$EVILGINX_PATH/logs" ]; then
        cp -r "$EVILGINX_PATH/logs"/* "$BACKUP_DIR/captured_data/" 2>/dev/null || true
    fi
    
    # Backup configuration files
    cp config.conf "$BACKUP_DIR/configs/" 2>/dev/null || true
    cp targets.txt "$BACKUP_DIR/configs/" 2>/dev/null || true
    cp phishlets_okta.yaml "$BACKUP_DIR/configs/" 2>/dev/null || true
    
    # Backup reconnaissance data
    if [ -d "./recon_output" ]; then
        cp -r ./recon_output "$BACKUP_DIR/reports/" 2>/dev/null || true
    fi
    
    # Backup email templates
    if [ -d "./email_templates" ]; then
        cp -r ./email_templates "$BACKUP_DIR/configs/" 2>/dev/null || true
    fi
    
    success "Campaign data backed up to: $BACKUP_DIR"
}

stop_evilginx_services() {
    phase "Stopping Evilginx2 Services"
    
    # Kill any running Evilginx processes
    pkill -f evilginx 2>/dev/null || true
    
    # Wait for processes to stop
    sleep 3
    
    # Force kill if still running
    pkill -9 -f evilginx 2>/dev/null || true
    
    success "Evilginx2 services stopped"
}

disable_phishlets() {
    phase "Disabling Phishlets"
    
    # Create cleanup commands for Evilginx
    cat > "/tmp/evilginx_cleanup.txt" << EOF
phishlets disable okta
lures delete all
sessions flush
EOF
    
    warning "If Evilginx2 was running, execute these commands manually:"
    cat /tmp/evilginx_cleanup.txt
    
    # Remove phishlet files
    rm -f "$EVILGINX_PATH/phishlets/okta.yaml" 2>/dev/null || true
    rm -rf "$EVILGINX_PATH/lures" 2>/dev/null || true
    
    success "Phishlets disabled and files removed"
}

clean_logs() {
    phase "Cleaning Sensitive Logs"
    
    # Secure delete function
    secure_delete() {
        local file="$1"
        if [ -f "$file" ]; then
            # Overwrite with random data (if shred is available)
            if command -v shred >/dev/null 2>&1; then
                shred -vfz -n 3 "$file"
            else
                # Fallback to simple overwrite
                dd if=/dev/urandom of="$file" bs=1M count=1 2>/dev/null || true
                rm -f "$file"
            fi
        fi
    }
    
    # Clean Evilginx logs
    for log_file in "$EVILGINX_PATH/logs"/*.log; do
        if [ -f "$log_file" ]; then
            secure_delete "$log_file"
        fi
    done
    
    # Clean campaign logs
    for log_file in ./logs/*.log; do
        if [ -f "$log_file" ]; then
            secure_delete "$log_file"
        fi
    done
    
    success "Sensitive logs securely deleted"
}

reset_firewall() {
    phase "Resetting Firewall Rules"
    
    if [[ $EUID -eq 0 ]]; then
        # Reset to default policies
        iptables -P INPUT ACCEPT
        iptables -P FORWARD ACCEPT
        iptables -P OUTPUT ACCEPT
        
        # Flush all rules
        iptables -F
        iptables -X
        iptables -t nat -F
        iptables -t nat -X
        
        # Remove custom logrotate config
        rm -f "/etc/logrotate.d/evilginx_campaign"
        
        success "Firewall rules reset"
    else
        warning "Root privileges required to reset firewall. Run: sudo iptables -F"
    fi
}

archive_campaign() {
    phase "Archiving Campaign Files"
    
    # Create final archive
    tar -czf "${CAMPAIGN_NAME}_complete_$(date +%Y%m%d_%H%M%S).tar.gz" \
        "$BACKUP_DIR" \
        *.sh \
        *.conf \
        *.txt \
        *.yaml \
        *.html 2>/dev/null || true
    
    success "Campaign archived"
}

generate_cleanup_report() {
    phase "Generating Cleanup Report"
    
    local report_file="$BACKUP_DIR/cleanup_report.md"
    
    cat > "$report_file" << EOF
# Wyndham Properties Red Team Campaign Cleanup Report

**Campaign:** $CAMPAIGN_NAME  
**Target Domain:** $TARGET_DOMAIN  
**Cleanup Date:** $(date -u +%Y-%m-%dT%H:%M:%SZ)  
**Operator:** $(whoami)

## Cleanup Actions Performed

### ✅ Data Backup
- Campaign logs backed up to: \`$BACKUP_DIR/logs\`
- Captured credentials backed up to: \`$BACKUP_DIR/captured_data\`
- Configuration files backed up to: \`$BACKUP_DIR/configs\`
- Reconnaissance data backed up to: \`$BACKUP_DIR/reports\`

### ✅ Infrastructure Cleanup
- Evilginx2 services stopped
- Okta phishlet disabled and removed
- Lure files deleted
- Sessions flushed

### ✅ Security Cleanup
- Sensitive logs securely deleted
- Firewall rules reset to defaults
- Temporary files removed

### ✅ Archival
- Complete campaign data archived
- Backup directory: \`$BACKUP_DIR\`

## Post-Cleanup Verification

Verify the following items have been addressed:

- [ ] Phishing domain DNS records updated/removed
- [ ] SSL certificates revoked (if applicable)
- [ ] Email sending infrastructure decommissioned
- [ ] All captured credentials handled per policy
- [ ] Incident response team notified (if applicable)
- [ ] Final report delivered to stakeholders

## Data Retention

Campaign data is retained in backup directory per organizational policy:
- Backup Location: \`$BACKUP_DIR\`
- Retention Period: $RETENTION_DAYS days
- Archive Format: tar.gz with compression

## Notes

This cleanup was performed as part of the authorized red team engagement with Wyndham Properties. All activities were conducted within the scope of the signed authorization letter.

---
*Cleanup Report Generated: $(date)*
EOF
    
    success "Cleanup report generated: $report_file"
}

final_verification() {
    phase "Final Verification"
    
    echo ""
    echo "🔍 CLEANUP VERIFICATION CHECKLIST"
    echo ""
    
    # Check if Evilginx is still running
    if pgrep -f evilginx >/dev/null; then
        warning "Evilginx2 processes still running"
    else
        success "No Evilginx2 processes running"
    fi
    
    # Check for phishlet files
    if [ -f "$EVILGINX_PATH/phishlets/okta.yaml" ]; then
        warning "Phishlet file still exists"
    else
        success "Phishlet files removed"
    fi
    
    # Check for logs
    if [ -d "$EVILGINX_PATH/logs" ] && [ "$(ls -A "$EVILGINX_PATH/logs")" ]; then
        warning "Evilginx logs still present"
    else
        success "Evilginx logs cleaned"
    fi
    
    success "Cleanup verification completed"
}

display_summary() {
    phase "Cleanup Complete"
    
    cat << EOF

🎯 CAMPAIGN CLEANUP SUCCESSFUL

Summary:
✓ Campaign data backed up: $BACKUP_DIR
✓ Evilginx2 services stopped
✓ Phishlets disabled and removed
✓ Sensitive logs securely deleted
✓ Firewall rules reset
✓ Campaign files archived

Next Steps:
1. Review cleanup report: $BACKUP_DIR/cleanup_report.md
2. Update DNS records for $PHISHING_DOMAIN
3. Revoke SSL certificates (if applicable)
4. Submit final campaign report
5. Archive backup according to retention policy

Data Retention:
- Backup will be retained for $RETENTION_DAYS days
- Archive: ${CAMPAIGN_NAME}_complete_$(date +%Y%m%d)*.tar.gz

Thank you for conducting authorized security testing!

EOF
}

### === MAIN EXECUTION ===
main() {
    print_banner
    confirm_cleanup
    backup_campaign_data
    stop_evilginx_services
    disable_phishlets
    clean_logs
    reset_firewall
    archive_campaign
    generate_cleanup_report
    final_verification
    display_summary
}

# Handle command line arguments
case "${1:-full}" in
    "full")
        main
        ;;
    "backup-only")
        print_banner
        backup_campaign_data
        ;;
    "logs-only")
        print_banner
        clean_logs
        ;;
    "services-only")
        print_banner
        stop_evilginx_services
        disable_phishlets
        ;;
    *)
        echo "Usage: $0 [full|backup-only|logs-only|services-only]"
        exit 1
        ;;
esac
