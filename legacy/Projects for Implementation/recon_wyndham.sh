#!/bin/bash
# === wyndham PROPERTIES RECONNAISSANCE SCRIPT ===
# For authorized red team testing only
# Gathers target information and builds employee profiles

set -euo pipefail
IFS=$'\n\t'

### === CONFIG ===
TARGET_DOMAIN="wyndhamhotels.com"
OUTPUT_DIR="./recon_output"
USER_AGENTS=(
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36"
    "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36"
)

### === COLORS ===
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

### === FUNCTIONS ===
log() { echo -e "${BLUE}[RECON]${NC} $*"; }
success() { echo -e "${GREEN}[✓]${NC} $*"; }
warning() { echo -e "${YELLOW}[!]${NC} $*"; }
error() { echo -e "${RED}[✗]${NC} $*"; }

setup_environment() {
    mkdir -p "$OUTPUT_DIR"/{emails,linkedin,dns,subdomains,employees}
    log "Created reconnaissance directory structure"
}

# Generate random user agent
get_user_agent() {
    echo "${USER_AGENTS[$RANDOM % ${#USER_AGENTS[@]}]}"
}

# DNS reconnaissance
dns_recon() {
    log "Starting DNS reconnaissance for $TARGET_DOMAIN"
    local dns_file="$OUTPUT_DIR/dns/dns_records.txt"
    
    {
        echo "=== DNS RECONNAISSANCE FOR $TARGET_DOMAIN ==="
        echo "Generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
        echo ""
        
        echo "=== A RECORDS ==="
        dig +short A "$TARGET_DOMAIN" || echo "No A records found"
        echo ""
        
        echo "=== MX RECORDS ==="
        dig +short MX "$TARGET_DOMAIN" || echo "No MX records found"
        echo ""
        
        echo "=== TXT RECORDS ==="
        dig +short TXT "$TARGET_DOMAIN" || echo "No TXT records found"
        echo ""
        
        echo "=== NS RECORDS ==="
        dig +short NS "$TARGET_DOMAIN" || echo "No NS records found"
        echo ""
        
    } > "$dns_file"
    
    success "DNS reconnaissance completed: $dns_file"
}

# Subdomain enumeration
subdomain_enum() {
    log "Enumerating subdomains for $TARGET_DOMAIN"
    local subdomain_file="$OUTPUT_DIR/subdomains/subdomains.txt"
    
    # Common subdomain wordlist
    local subdomains=(
        "www" "mail" "ftp" "admin" "login" "portal" "app" "api" "dev" "test"
        "staging" "beta" "secure" "vpn" "remote" "email" "webmail" "owa"
        "exchange" "autodiscover" "lyncdiscover" "sip" "team" "teams"
        "office" "o365" "azure" "okta" "sso" "auth" "identity" "hr"
        "careers" "jobs" "support" "help" "training" "learning"
    )
    
    {
        echo "=== SUBDOMAIN ENUMERATION FOR $TARGET_DOMAIN ==="
        echo "Generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
        echo ""
        
        for sub in "${subdomains[@]}"; do
            local full_domain="${sub}.${TARGET_DOMAIN}"
            if host "$full_domain" >/dev/null 2>&1; then
                echo "[FOUND] $full_domain"
                # Get IP if available
                local ip=$(dig +short A "$full_domain" 2>/dev/null | head -n1)
                if [ -n "$ip" ]; then
                    echo "  └─ IP: $ip"
                fi
            fi
        done
        
    } > "$subdomain_file"
    
    success "Subdomain enumeration completed: $subdomain_file"
}

# Email format detection
detect_email_formats() {
    log "Detecting email formats for $TARGET_DOMAIN"
    local email_file="$OUTPUT_DIR/emails/email_formats.txt"
    
    # Common email formats to test
    local formats=(
        "firstname.lastname@$TARGET_DOMAIN"
        "firstname@$TARGET_DOMAIN"
        "flastname@$TARGET_DOMAIN"
        "firstnamelastname@$TARGET_DOMAIN"
        "firstname_lastname@$TARGET_DOMAIN"
        "f.lastname@$TARGET_DOMAIN"
        "firstname.l@$TARGET_DOMAIN"
    )
    
    {
        echo "=== EMAIL FORMAT DETECTION FOR $TARGET_DOMAIN ==="
        echo "Generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
        echo ""
        echo "Common email formats to test:"
        for format in "${formats[@]}"; do
            echo "  • $format"
        done
        echo ""
        echo "Test with known employees from LinkedIn/public sources"
        
    } > "$email_file"
    
    success "Email format guide created: $email_file"
}

# LinkedIn employee search (manual guidance)
linkedin_search_guide() {
    log "Creating LinkedIn search guide"
    local linkedin_file="$OUTPUT_DIR/linkedin/search_guide.txt"
    
    {
        cat << 'EOF'
=== LINKEDIN SEARCH GUIDE FOR wyndham PROPERTIES ===

Manual LinkedIn Searches (authorized reconnaissance):

1. Company Search:
   - Search: "wyndham Properties" OR "wyndham Hotels"
   - Look for: Current employees, recent hires, departing employees

2. Targeted Role Searches:
   - "IT Director wyndham"
   - "Security Manager wyndham" 
   - "HR Manager wyndham"
   - "Finance Director wyndham"
   - "Operations Manager wyndham"

3. Location-Based Searches:
   - Add location filters for wyndham office locations
   - Focus on headquarters and major regional offices

4. Information to Collect:
   - Full names
   - Job titles
   - Department
   - Location
   - Contact information (if public)
   - Recent posts/activities
   - Professional interests

5. Email Pattern Testing:
   Once you have names, test email formats:
   - john.smith@wyndhamhotels.com
   - jsmith@wyndhamhotels.com
   - j.smith@wyndhamhotels.com
   - smithj@wyndhamhotels.com

6. Target Prioritization:
   High Value Targets:
   - C-level executives
   - IT/Security staff
   - HR personnel
   - Finance team
   - Executive assistants

REMEMBER: This is for authorized testing only!
EOF
    } > "$linkedin_file"
    
    success "LinkedIn search guide created: $linkedin_file"
}

# Generate target employee template
generate_employee_template() {
    log "Creating employee target template"
    local template_file="$OUTPUT_DIR/employees/employee_template.csv"
    
    {
        echo "name,title,department,email,phone,location,linkedin,notes"
        echo "John Smith,IT Director,Information Technology,john.smith@wyndhamhotels.com,,Corporate HQ,https://linkedin.com/in/johnsmith,High value target - IT access"
        echo "Jane Doe,HR Manager,Human Resources,jane.doe@wyndhamhotels.com,,Regional Office,https://linkedin.com/in/janedoe,Access to employee data"
        echo "Mike Johnson,Security Analyst,IT Security,mjohnson@wyndhamhotels.com,,Corporate HQ,https://linkedin.com/in/mikejohnson,Security team member"
        
    } > "$template_file"
    
    success "Employee template created: $template_file"
}

# Web application reconnaissance
webapp_recon() {
    log "Performing web application reconnaissance"
    local webapp_file="$OUTPUT_DIR/webapp_info.txt"
    
    {
        echo "=== WEB APPLICATION RECONNAISSANCE ==="
        echo "Generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
        echo ""
        
        echo "=== HTTP HEADERS FOR $TARGET_DOMAIN ==="
        curl -s -I "https://$TARGET_DOMAIN" -A "$(get_user_agent)" || echo "Could not retrieve headers"
        echo ""
        
        echo "=== COMMON PATHS TO TEST ==="
        local paths=(
            "/login" "/admin" "/portal" "/sso" "/auth" 
            "/okta" "/adfs" "/office365" "/o365"
            "/hr" "/careers" "/employee" "/staff"
            "/api" "/api/v1" "/rest" "/graphql"
        )
        
        for path in "${paths[@]}"; do
            echo "  • https://$TARGET_DOMAIN$path"
        done
        
        echo ""
        echo "=== TECHNOLOGY DETECTION ==="
        echo "Use tools like Wappalyzer, whatweb, or manual inspection"
        echo "Look for:"
        echo "  • Authentication systems (Okta, ADFS, etc.)"
        echo "  • CMS platforms"
        echo "  • Web frameworks"
        echo "  • JavaScript libraries"
        echo "  • Server information"
        
    } > "$webapp_file"
    
    success "Web application reconnaissance completed: $webapp_file"
}

# Generate reconnaissance report
generate_report() {
    log "Generating reconnaissance summary report"
    local report_file="$OUTPUT_DIR/recon_summary.md"
    
    {
        cat << EOF
# wyndham Properties Reconnaissance Report

**Campaign:** Authorized Red Team Testing  
**Target:** $TARGET_DOMAIN  
**Generated:** $(date -u +%Y-%m-%dT%H:%M:%SZ)

## Executive Summary

This reconnaissance was conducted as part of an authorized red team engagement for wyndham Properties. All activities were performed within the scope of the signed authorization letter.

## Reconnaissance Scope

### DNS Information
- Primary domain: $TARGET_DOMAIN
- DNS records collected and analyzed
- Subdomain enumeration performed

### Email Intelligence
- Email format patterns identified
- Target employee list development
- LinkedIn reconnaissance guidance provided

### Web Application Assessment
- HTTP headers analyzed
- Common authentication paths identified
- Technology stack reconnaissance

## Next Steps

1. **Review all collected intelligence**
2. **Validate email addresses using OSINT tools**
3. **Develop target employee list**
4. **Configure phishing infrastructure**
5. **Test email templates**
6. **Launch controlled phishing campaign**

## Files Generated

\`\`\`
$OUTPUT_DIR/
├── dns/dns_records.txt
├── subdomains/subdomains.txt
├── emails/email_formats.txt
├── linkedin/search_guide.txt
├── employees/employee_template.csv
├── webapp_info.txt
└── recon_summary.md
\`\`\`

---
*This report is for authorized testing purposes only*
EOF
    } > "$report_file"
    
    success "Reconnaissance report generated: $report_file"
}

### === MAIN EXECUTION ===
main() {
    echo -e "${PURPLE}"
    cat << "EOF"
    🔍 wyndham PROPERTIES RECONNAISSANCE
    Authorized Red Team Intelligence Gathering
EOF
    echo -e "${NC}"
    
    warning "AUTHORIZATION REMINDER: Ensure you have written permission!"
    log "Target: $TARGET_DOMAIN"
    log "Output: $OUTPUT_DIR"
    
    setup_environment
    dns_recon
    subdomain_enum
    detect_email_formats
    linkedin_search_guide
    generate_employee_template
    webapp_recon
    generate_report
    
    success "Reconnaissance phase completed!"
    
    echo ""
    log "Next steps:"
    echo "  1. Review generated files in $OUTPUT_DIR"
    echo "  2. Manually perform LinkedIn searches using the guide"
    echo "  3. Populate employee_template.csv with real targets"
    echo "  4. Validate email addresses"
    echo "  5. Configure your phishing domain"
    echo "  6. Launch the Okta campaign"
    
    echo ""
    warning "Remember: All activities must stay within authorized scope!"
}

main "$@"
