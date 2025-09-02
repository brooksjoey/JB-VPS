#!/bin/bash

# DNS & Domain Automation for Evilginx2 v3.4.1
# Supports Cloudflare API for automated domain and DNS record management

set -euo pipefail

# Configuration
CONFIG_FILE="config.conf"
LOG_FILE="logs/dns_manager.log"

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
        echo -e "${RED}Configuration file not found: $CONFIG_FILE${NC}"
        exit 1
    fi
}

# Cloudflare API wrapper
cf_api_call() {
    local method="$1"
    local endpoint="$2"
    local data="${3:-}"
    
    local url="https://api.cloudflare.com/v4/$endpoint"
    local headers=(
        -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN"
        -H "Content-Type: application/json"
    )
    
    if [[ -n "$data" ]]; then
        curl -s -X "$method" "${headers[@]}" -d "$data" "$url"
    else
        curl -s -X "$method" "${headers[@]}" "$url"
    fi
}

# Get zone ID for domain
get_zone_id() {
    local domain="$1"
    log "Getting zone ID for $domain"
    
    local response=$(cf_api_call "GET" "zones?name=$domain")
    local zone_id=$(echo "$response" | jq -r '.result[0].id // empty')
    
    if [[ -n "$zone_id" && "$zone_id" != "null" ]]; then
        echo "$zone_id"
        return 0
    else
        log "Zone not found for domain: $domain"
        return 1
    fi
}

# Create DNS record
create_dns_record() {
    local zone_id="$1"
    local record_type="$2"
    local name="$3"
    local content="$4"
    local ttl="${5:-300}"
    local proxied="${6:-false}"
    
    log "Creating $record_type record: $name -> $content"
    
    local data=$(jq -n \
        --arg type "$record_type" \
        --arg name "$name" \
        --arg content "$content" \
        --argjson ttl "$ttl" \
        --argjson proxied "$proxied" \
        '{
            type: $type,
            name: $name,
            content: $content,
            ttl: $ttl,
            proxied: $proxied
        }')
    
    local response=$(cf_api_call "POST" "zones/$zone_id/dns_records" "$data")
    local success=$(echo "$response" | jq -r '.success')
    
    if [[ "$success" == "true" ]]; then
        local record_id=$(echo "$response" | jq -r '.result.id')
        log "DNS record created successfully: $record_id"
        echo "$record_id"
        return 0
    else
        local errors=$(echo "$response" | jq -r '.errors[].message')
        log "Failed to create DNS record: $errors"
        return 1
    fi
}

# Update DNS record
update_dns_record() {
    local zone_id="$1"
    local record_id="$2"
    local record_type="$3"
    local name="$4"
    local content="$5"
    local ttl="${6:-300}"
    local proxied="${7:-false}"
    
    log "Updating DNS record: $name -> $content"
    
    local data=$(jq -n \
        --arg type "$record_type" \
        --arg name "$name" \
        --arg content "$content" \
        --argjson ttl "$ttl" \
        --argjson proxied "$proxied" \
        '{
            type: $type,
            name: $name,
            content: $content,
            ttl: $ttl,
            proxied: $proxied
        }')
    
    local response=$(cf_api_call "PUT" "zones/$zone_id/dns_records/$record_id" "$data")
    local success=$(echo "$response" | jq -r '.success')
    
    if [[ "$success" == "true" ]]; then
        log "DNS record updated successfully"
        return 0
    else
        local errors=$(echo "$response" | jq -r '.errors[].message')
        log "Failed to update DNS record: $errors"
        return 1
    fi
}

# Delete DNS record
delete_dns_record() {
    local zone_id="$1"
    local record_id="$2"
    
    log "Deleting DNS record: $record_id"
    
    local response=$(cf_api_call "DELETE" "zones/$zone_id/dns_records/$record_id")
    local success=$(echo "$response" | jq -r '.success')
    
    if [[ "$success" == "true" ]]; then
        log "DNS record deleted successfully"
        return 0
    else
        local errors=$(echo "$response" | jq -r '.errors[].message')
        log "Failed to delete DNS record: $errors"
        return 1
    fi
}

# List DNS records for domain
list_dns_records() {
    local domain="$1"
    local zone_id=$(get_zone_id "$domain")
    
    if [[ -z "$zone_id" ]]; then
        return 1
    fi
    
    log "Listing DNS records for $domain"
    
    local response=$(cf_api_call "GET" "zones/$zone_id/dns_records")
    local success=$(echo "$response" | jq -r '.success')
    
    if [[ "$success" == "true" ]]; then
        echo "$response" | jq -r '.result[] | "\(.type)\t\(.name)\t\(.content)\t\(.id)"'
        return 0
    else
        local errors=$(echo "$response" | jq -r '.errors[].message')
        log "Failed to list DNS records: $errors"
        return 1
    fi
}

# Setup phishing domain with multiple records
setup_phishing_domain() {
    local domain="$1"
    local server_ip="$2"
    
    log "Setting up phishing domain: $domain"
    
    local zone_id=$(get_zone_id "$domain")
    if [[ -z "$zone_id" ]]; then
        echo -e "${RED}Zone not found for domain: $domain${NC}"
        return 1
    fi
    
    # Create A record for root domain
    local a_record_id=$(create_dns_record "$zone_id" "A" "$domain" "$server_ip" 300 false)
    
    # Create CNAME for www
    local www_record_id=$(create_dns_record "$zone_id" "CNAME" "www.$domain" "$domain" 300 false)
    
    # Create wildcard A record for subdomains
    local wildcard_record_id=$(create_dns_record "$zone_id" "A" "*.$domain" "$server_ip" 300 false)
    
    # Create MX record for email
    local mx_data=$(jq -n \
        --arg name "$domain" \
        --arg content "$domain" \
        --argjson priority 10 \
        --argjson ttl 300 \
        '{
            type: "MX",
            name: $name,
            content: $content,
            priority: $priority,
            ttl: $ttl
        }')
    
    local mx_response=$(cf_api_call "POST" "zones/$zone_id/dns_records" "$mx_data")
    
    # Create SPF record
    local spf_record_id=$(create_dns_record "$zone_id" "TXT" "$domain" "v=spf1 a mx ip4:$server_ip ~all" 300 false)
    
    # Create DMARC record
    local dmarc_record_id=$(create_dns_record "$zone_id" "TXT" "_dmarc.$domain" "v=DMARC1; p=none; rua=mailto:dmarc@$domain" 300 false)
    
    # Save record IDs for cleanup
    cat > "dns_records_$domain.json" << EOF
{
    "domain": "$domain",
    "zone_id": "$zone_id",
    "records": {
        "a_record": "$a_record_id",
        "www_record": "$www_record_id",
        "wildcard_record": "$wildcard_record_id",
        "spf_record": "$spf_record_id",
        "dmarc_record": "$dmarc_record_id"
    },
    "created": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
    
    log "Phishing domain setup completed for $domain"
    echo -e "${GREEN}Domain $domain configured successfully${NC}"
}

# Cleanup phishing domain
cleanup_phishing_domain() {
    local domain="$1"
    local records_file="dns_records_$domain.json"
    
    if [[ ! -f "$records_file" ]]; then
        echo -e "${RED}Records file not found: $records_file${NC}"
        return 1
    fi
    
    log "Cleaning up DNS records for $domain"
    
    local zone_id=$(jq -r '.zone_id' "$records_file")
    local records=$(jq -r '.records | to_entries[] | .value' "$records_file")
    
    while IFS= read -r record_id; do
        if [[ -n "$record_id" && "$record_id" != "null" ]]; then
            delete_dns_record "$zone_id" "$record_id"
        fi
    done <<< "$records"
    
    # Remove records file
    rm "$records_file"
    
    log "DNS cleanup completed for $domain"
    echo -e "${GREEN}Domain $domain cleaned up successfully${NC}"
}

# Setup subdomain for specific phishlet
setup_phishlet_subdomain() {
    local base_domain="$1"
    local subdomain="$2"
    local server_ip="$3"
    
    local full_domain="$subdomain.$base_domain"
    log "Setting up phishlet subdomain: $full_domain"
    
    local zone_id=$(get_zone_id "$base_domain")
    if [[ -z "$zone_id" ]]; then
        echo -e "${RED}Zone not found for domain: $base_domain${NC}"
        return 1
    fi
    
    # Create A record for subdomain
    local record_id=$(create_dns_record "$zone_id" "A" "$full_domain" "$server_ip" 300 false)
    
    if [[ -n "$record_id" ]]; then
        echo -e "${GREEN}Subdomain $full_domain configured successfully${NC}"
        echo "$record_id" > "dns_record_${full_domain//\./_}.txt"
    fi
}

# Monitor DNS propagation
check_dns_propagation() {
    local domain="$1"
    local record_type="${2:-A}"
    local expected_value="$3"
    
    log "Checking DNS propagation for $domain ($record_type)"
    
    local dns_servers=(
        "8.8.8.8"
        "1.1.1.1"
        "208.67.222.222"
        "9.9.9.9"
    )
    
    local propagated=0
    local total=${#dns_servers[@]}
    
    for dns_server in "${dns_servers[@]}"; do
        local result=$(dig @"$dns_server" "$domain" "$record_type" +short | head -n1)
        
        if [[ "$result" == "$expected_value" ]]; then
            echo -e "${GREEN}✓ $dns_server: $result${NC}"
            ((propagated++))
        else
            echo -e "${RED}✗ $dns_server: $result (expected: $expected_value)${NC}"
        fi
    done
    
    echo "Propagation: $propagated/$total servers"
    
    if [[ $propagated -eq $total ]]; then
        echo -e "${GREEN}DNS fully propagated${NC}"
        return 0
    else
        echo -e "${YELLOW}DNS propagation incomplete${NC}"
        return 1
    fi
}

# Bulk domain setup from file
bulk_setup_domains() {
    local domains_file="$1"
    local server_ip="$2"
    
    if [[ ! -f "$domains_file" ]]; then
        echo -e "${RED}Domains file not found: $domains_file${NC}"
        return 1
    fi
    
    log "Starting bulk domain setup from $domains_file"
    
    while IFS= read -r domain; do
        if [[ -n "$domain" && ! "$domain" =~ ^# ]]; then
            echo -e "${BLUE}Setting up domain: $domain${NC}"
            setup_phishing_domain "$domain" "$server_ip"
            sleep 2  # Rate limiting
        fi
    done < "$domains_file"
    
    log "Bulk domain setup completed"
}

# Generate domain report
generate_domain_report() {
    local output_file="domain_report_$(date +%Y%m%d_%H%M%S).txt"
    
    log "Generating domain report"
    
    {
        echo "=== Evilginx2 Domain Report ==="
        echo "Generated: $(date)"
        echo
        
        for records_file in dns_records_*.json; do
            if [[ -f "$records_file" ]]; then
                local domain=$(jq -r '.domain' "$records_file")
                local created=$(jq -r '.created' "$records_file")
                
                echo "Domain: $domain"
                echo "Created: $created"
                echo "Records:"
                list_dns_records "$domain" | while IFS=$'\t' read -r type name content record_id; do
                    echo "  $type $name -> $content"
                done
                echo
            fi
        done
    } > "$output_file"
    
    echo -e "${GREEN}Domain report generated: $output_file${NC}"
}

# Quick domain health check
health_check_domain() {
    local domain="$1"
    
    echo -e "${BLUE}=== Domain Health Check: $domain ===${NC}"
    
    # Check DNS resolution
    echo -n "DNS Resolution: "
    if nslookup "$domain" &>/dev/null; then
        echo -e "${GREEN}OK${NC}"
    else
        echo -e "${RED}FAILED${NC}"
    fi
    
    # Check HTTP response
    echo -n "HTTP Response: "
    local http_code=$(curl -s -o /dev/null -w "%{http_code}" "http://$domain" --max-time 10)
    if [[ "$http_code" =~ ^(200|301|302|401|403)$ ]]; then
        echo -e "${GREEN}$http_code${NC}"
    else
        echo -e "${RED}$http_code${NC}"
    fi
    
    # Check HTTPS response
    echo -n "HTTPS Response: "
    local https_code=$(curl -s -o /dev/null -w "%{http_code}" "https://$domain" --max-time 10 --insecure)
    if [[ "$https_code" =~ ^(200|301|302|401|403)$ ]]; then
        echo -e "${GREEN}$https_code${NC}"
    else
        echo -e "${RED}$https_code${NC}"
    fi
    
    # Check SSL certificate
    echo -n "SSL Certificate: "
    if openssl s_client -connect "$domain:443" -servername "$domain" </dev/null 2>/dev/null | openssl x509 -noout -dates &>/dev/null; then
        local expiry=$(openssl s_client -connect "$domain:443" -servername "$domain" </dev/null 2>/dev/null | openssl x509 -noout -enddate | cut -d= -f2)
        echo -e "${GREEN}Valid (expires: $expiry)${NC}"
    else
        echo -e "${RED}Invalid/Missing${NC}"
    fi
}

# Main menu
show_menu() {
    echo -e "${BLUE}=== DNS Manager for Evilginx2 v3.4.1 ===${NC}"
    echo "1) Setup phishing domain"
    echo "2) List DNS records"
    echo "3) Create DNS record"
    echo "4) Delete DNS record"
    echo "5) Setup phishlet subdomain"
    echo "6) Check DNS propagation"
    echo "7) Cleanup domain"
    echo "8) Bulk setup domains"
    echo "9) Domain health check"
    echo "10) Generate domain report"
    echo "11) Exit"
    echo -n "Select option: "
}

# Main execution
main() {
    mkdir -p logs
    load_config
    
    # Check dependencies
    if ! command -v jq &> /dev/null; then
        echo -e "${RED}jq is required but not installed${NC}"
        exit 1
    fi
    
    if ! command -v curl &> /dev/null; then
        echo -e "${RED}curl is required but not installed${NC}"
        exit 1
    fi
    
    while true; do
        show_menu
        read -r choice
        
        case $choice in
            1)
                echo -n "Enter domain: "
                read -r domain
                echo -n "Enter server IP: "
                read -r server_ip
                setup_phishing_domain "$domain" "$server_ip"
                ;;
            2)
                echo -n "Enter domain: "
                read -r domain
                list_dns_records "$domain"
                ;;
            3)
                echo -n "Enter domain: "
                read -r domain
                echo -n "Enter record type (A/CNAME/TXT/MX): "
                read -r record_type
                echo -n "Enter record name: "
                read -r record_name
                echo -n "Enter record content: "
                read -r record_content
                
                local zone_id=$(get_zone_id "$domain")
                if [[ -n "$zone_id" ]]; then
                    create_dns_record "$zone_id" "$record_type" "$record_name" "$record_content"
                fi
                ;;
            4)
                echo -n "Enter domain: "
                read -r domain
                echo -n "Enter record ID: "
                read -r record_id
                
                local zone_id=$(get_zone_id "$domain")
                if [[ -n "$zone_id" ]]; then
                    delete_dns_record "$zone_id" "$record_id"
                fi
                ;;
            5)
                echo -n "Enter base domain: "
                read -r base_domain
                echo -n "Enter subdomain: "
                read -r subdomain
                echo -n "Enter server IP: "
                read -r server_ip
                setup_phishlet_subdomain "$base_domain" "$subdomain" "$server_ip"
                ;;
            6)
                echo -n "Enter domain: "
                read -r domain
                echo -n "Enter expected value: "
                read -r expected_value
                check_dns_propagation "$domain" "A" "$expected_value"
                ;;
            7)
                echo -n "Enter domain to cleanup: "
                read -r domain
                cleanup_phishing_domain "$domain"
                ;;
            8)
                echo -n "Enter domains file path: "
                read -r domains_file
                echo -n "Enter server IP: "
                read -r server_ip
                bulk_setup_domains "$domains_file" "$server_ip"
                ;;
            9)
                echo -n "Enter domain: "
                read -r domain
                health_check_domain "$domain"
                ;;
            10)
                generate_domain_report
                ;;
            11)
                echo "Exiting..."
                exit 0
                ;;
            *)
                echo -e "${RED}Invalid option${NC}"
                ;;
        esac
        echo
    done
}

# Run main function
main "$@"
