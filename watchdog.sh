#!/bin/bash

# Monitoring & Alerting System for Evilginx2 v3.4.1
# Monitors phishlet uptime, SSL expiry, and suspicious activity

set -euo pipefail

# Configuration
CONFIG_FILE="config.conf"
LOG_FILE="logs/watchdog.log"
ALERT_LOG="logs/alerts.log"
STATUS_FILE="logs/watchdog_status.json"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Alert thresholds
MAX_RESPONSE_TIME=5000  # milliseconds
MAX_FAILED_CHECKS=3
SSL_EXPIRY_WARNING=30   # days
SUSPICIOUS_REQUEST_THRESHOLD=100  # requests per minute

# Global variables
ALERT_COUNT=0
FAILED_CHECKS=()
CURRENT_STATUS="OK"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Alert function
alert() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    echo "[$timestamp] [$level] $message" | tee -a "$ALERT_LOG"
    
    # Send notifications based on level
    case "$level" in
        "CRITICAL")
            send_critical_alert "$message"
            ;;
        "WARNING")
            send_warning_alert "$message"
            ;;
        "INFO")
            send_info_alert "$message"
            ;;
    esac
    
    ((ALERT_COUNT++))
}

# Load configuration
load_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        source "$CONFIG_FILE"
    else
        log "WARNING: Configuration file not found: $CONFIG_FILE"
    fi
}

# Send critical alert
send_critical_alert() {
    local message="$1"
    
    # Email notification
    if [[ -n "${ALERT_EMAIL:-}" ]]; then
        echo "CRITICAL ALERT: $message" | mail -s "Evilginx2 Critical Alert" "$ALERT_EMAIL" 2>/dev/null || true
    fi
    
    # Slack notification
    if [[ -n "${SLACK_WEBHOOK:-}" ]]; then
        send_slack_alert "CRITICAL" "$message" "#ff0000"
    fi
    
    # Discord notification
    if [[ -n "${DISCORD_WEBHOOK:-}" ]]; then
        send_discord_alert "CRITICAL" "$message"
    fi
    
    # Telegram notification
    if [[ -n "${TELEGRAM_BOT_TOKEN:-}" && -n "${TELEGRAM_CHAT_ID:-}" ]]; then
        send_telegram_alert "🚨 CRITICAL: $message"
    fi
}

# Send warning alert
send_warning_alert() {
    local message="$1"
    
    # Email notification
    if [[ -n "${ALERT_EMAIL:-}" ]]; then
        echo "WARNING: $message" | mail -s "Evilginx2 Warning" "$ALERT_EMAIL" 2>/dev/null || true
    fi
    
    # Slack notification
    if [[ -n "${SLACK_WEBHOOK:-}" ]]; then
        send_slack_alert "WARNING" "$message" "#ffaa00"
    fi
}

# Send info alert
send_info_alert() {
    local message="$1"
    
    # Slack notification (info only)
    if [[ -n "${SLACK_WEBHOOK:-}" ]]; then
        send_slack_alert "INFO" "$message" "#00ff00"
    fi
}

# Send Slack alert
send_slack_alert() {
    local level="$1"
    local message="$2"
    local color="$3"
    
    local payload=$(cat << EOF
{
    "attachments": [
        {
            "color": "$color",
            "title": "Evilginx2 Alert - $level",
            "text": "$message",
            "ts": $(date +%s)
        }
    ]
}
EOF
)
    
    curl -X POST -H 'Content-type: application/json' \
         --data "$payload" \
         "$SLACK_WEBHOOK" 2>/dev/null || true
}

# Send Discord alert
send_discord_alert() {
    local level="$1"
    local message="$2"
    
    local payload=$(cat << EOF
{
    "embeds": [
        {
            "title": "Evilginx2 Alert - $level",
            "description": "$message",
            "color": 16711680,
            "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%S.000Z)"
        }
    ]
}
EOF
)
    
    curl -X POST -H 'Content-Type: application/json' \
         --data "$payload" \
         "$DISCORD_WEBHOOK" 2>/dev/null || true
}

# Send Telegram alert
send_telegram_alert() {
    local message="$1"
    
    curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage" \
         -d chat_id="$TELEGRAM_CHAT_ID" \
         -d text="$message" 2>/dev/null || true
}

# Check domain health
check_domain_health() {
    local domain="$1"
    local expected_status="${2:-200}"
    
    log "Checking health for domain: $domain"
    
    # HTTP check
    local http_start=$(date +%s%3N)
    local http_response=$(curl -s -o /dev/null -w "%{http_code},%{time_total}" \
                         --max-time 10 "http://$domain" 2>/dev/null || echo "000,0")
    local http_end=$(date +%s%3N)
    
    local http_code=$(echo "$http_response" | cut -d',' -f1)
    local http_time=$(echo "$http_response" | cut -d',' -f2)
    local http_ms=$(echo "$http_time * 1000" | bc -l 2>/dev/null || echo "0")
    
    # HTTPS check
    local https_start=$(date +%s%3N)
    local https_response=$(curl -s -o /dev/null -w "%{http_code},%{time_total}" \
                          --max-time 10 --insecure "https://$domain" 2>/dev/null || echo "000,0")
    local https_end=$(date +%s%3N)
    
    local https_code=$(echo "$https_response" | cut -d',' -f1)
    local https_time=$(echo "$https_response" | cut -d',' -f2)
    local https_ms=$(echo "$https_time * 1000" | bc -l 2>/dev/null || echo "0")
    
    # Analyze results
    local status="OK"
    local issues=()
    
    if [[ "$http_code" == "000" ]]; then
        issues+=("HTTP connection failed")
        status="CRITICAL"
    elif [[ "$http_code" != "301" && "$http_code" != "302" ]]; then
        issues+=("HTTP unexpected status: $http_code")
        status="WARNING"
    fi
    
    if [[ "$https_code" == "000" ]]; then
        issues+=("HTTPS connection failed")
        status="CRITICAL"
    elif [[ "$https_code" != "$expected_status" && "$https_code" != "301" && "$https_code" != "302" ]]; then
        issues+=("HTTPS unexpected status: $https_code")
        status="WARNING"
    fi
    
    if (( $(echo "$https_ms > $MAX_RESPONSE_TIME" | bc -l 2>/dev/null || echo 0) )); then
        issues+=("Slow response time: ${https_ms}ms")
        status="WARNING"
    fi
    
    # Generate report
    local report=$(cat << EOF
{
    "domain": "$domain",
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%S.000Z)",
    "status": "$status",
    "http": {
        "code": $http_code,
        "time_ms": $http_ms
    },
    "https": {
        "code": $https_code,
        "time_ms": $https_ms
    },
    "issues": $(printf '%s\n' "${issues[@]}" | jq -R . | jq -s .)
}
EOF
)
    
    echo "$report"
    
    # Send alerts if needed
    if [[ "$status" == "CRITICAL" ]]; then
        alert "CRITICAL" "Domain $domain is down: $(IFS=', '; echo "${issues[*]}")"
    elif [[ "$status" == "WARNING" ]]; then
        alert "WARNING" "Domain $domain has issues: $(IFS=', '; echo "${issues[*]}")"
    fi
}

# Check SSL certificate expiry
check_ssl_expiry() {
    local domain="$1"
    
    log "Checking SSL certificate for: $domain"
    
    local cert_info=$(openssl s_client -connect "$domain:443" -servername "$domain" </dev/null 2>/dev/null | openssl x509 -noout -dates 2>/dev/null)
    
    if [[ -z "$cert_info" ]]; then
        alert "CRITICAL" "SSL certificate check failed for $domain"
        return 1
    fi
    
    local expiry_date=$(echo "$cert_info" | grep "notAfter" | cut -d= -f2)
    local expiry_epoch=$(date -d "$expiry_date" +%s 2>/dev/null || echo "0")
    local current_epoch=$(date +%s)
    local days_until_expiry=$(( (expiry_epoch - current_epoch) / 86400 ))
    
    local status="OK"
    if [[ $days_until_expiry -le 0 ]]; then
        status="CRITICAL"
        alert "CRITICAL" "SSL certificate for $domain has expired!"
    elif [[ $days_until_expiry -le 7 ]]; then
        status="CRITICAL"
        alert "CRITICAL" "SSL certificate for $domain expires in $days_until_expiry days"
    elif [[ $days_until_expiry -le $SSL_EXPIRY_WARNING ]]; then
        status="WARNING"
        alert "WARNING" "SSL certificate for $domain expires in $days_until_expiry days"
    fi
    
    local report=$(cat << EOF
{
    "domain": "$domain",
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%S.000Z)",
    "status": "$status",
    "expiry_date": "$expiry_date",
    "days_until_expiry": $days_until_expiry
}
EOF
)
    
    echo "$report"
}

# Check for suspicious activity
check_suspicious_activity() {
    local domain="$1"
    local log_file="${2:-/var/log/nginx/access.log}"
    
    if [[ ! -f "$log_file" ]]; then
        log "WARNING: Log file not found: $log_file"
        return 1
    fi
    
    log "Checking suspicious activity for: $domain"
    
    local current_time=$(date +%s)
    local one_minute_ago=$((current_time - 60))
    
    # Count requests in the last minute
    local request_count=$(awk -v domain="$domain" -v since="$one_minute_ago" '
        $1 ~ /^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$/ {
            # Extract timestamp from log (assuming common log format)
            gsub(/\[|\]/, "", $4)
            cmd = "date -d \"" $4 "\" +%s 2>/dev/null"
            cmd | getline timestamp
            close(cmd)
            
            if (timestamp >= since && $0 ~ domain) {
                count++
            }
        }
        END { print count + 0 }
    ' "$log_file")
    
    # Check for suspicious patterns
    local suspicious_patterns=(
        "nmap"
        "nikto"
        "sqlmap"
        "nessus"
        "burp"
        "zap"
        "bot"
        "crawler"
        "scanner"
    )
    
    local suspicious_requests=0
    for pattern in "${suspicious_patterns[@]}"; do
        local pattern_count=$(grep -c -i "$pattern" "$log_file" 2>/dev/null || echo "0")
        suspicious_requests=$((suspicious_requests + pattern_count))
    done
    
    # Analyze results
    local status="OK"
    local issues=()
    
    if [[ $request_count -gt $SUSPICIOUS_REQUEST_THRESHOLD ]]; then
        issues+=("High request rate: $request_count requests/minute")
        status="WARNING"
        
        if [[ $request_count -gt $((SUSPICIOUS_REQUEST_THRESHOLD * 2)) ]]; then
            status="CRITICAL"
        fi
    fi
    
    if [[ $suspicious_requests -gt 0 ]]; then
        issues+=("Suspicious requests detected: $suspicious_requests")
        status="WARNING"
        
        if [[ $suspicious_requests -gt 10 ]]; then
            status="CRITICAL"
        fi
    fi
    
    # Check for failed login attempts
    local failed_logins=$(grep -c "401\|403" "$log_file" 2>/dev/null || echo "0")
    if [[ $failed_logins -gt 20 ]]; then
        issues+=("High number of failed requests: $failed_logins")
        status="WARNING"
    fi
    
    local report=$(cat << EOF
{
    "domain": "$domain",
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%S.000Z)",
    "status": "$status",
    "request_count_per_minute": $request_count,
    "suspicious_requests": $suspicious_requests,
    "failed_logins": $failed_logins,
    "issues": $(printf '%s\n' "${issues[@]}" | jq -R . | jq -s .)
}
EOF
)
    
    echo "$report"
    
    # Send alerts if needed
    if [[ "$status" == "CRITICAL" ]]; then
        alert "CRITICAL" "Suspicious activity detected on $domain: $(IFS=', '; echo "${issues[*]}")"
    elif [[ "$status" == "WARNING" ]]; then
        alert "WARNING" "Suspicious activity detected on $domain: $(IFS=', '; echo "${issues[*]}")"
    fi
}

# Check Evilginx2 service status
check_evilginx_service() {
    log "Checking Evilginx2 service status"
    
    local status="OK"
    local issues=()
    
    # Check if process is running
    if ! pgrep -f "evilginx" >/dev/null; then
        issues+=("Evilginx2 process not running")
        status="CRITICAL"
    fi
    
    # Check if listening on expected ports
    local expected_ports=(80 443)
    for port in "${expected_ports[@]}"; do
        if ! netstat -ln | grep ":$port " >/dev/null; then
            issues+=("Port $port not listening")
            status="CRITICAL"
        fi
    done
    
    # Check log file for errors
    local error_count=$(tail -n 100 "logs/evilginx.log" 2>/dev/null | grep -c -i "error\|failed\|exception" || echo "0")
    if [[ $error_count -gt 5 ]]; then
        issues+=("High error count in logs: $error_count")
        status="WARNING"
    fi
    
    local report=$(cat << EOF
{
    "service": "evilginx2",
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%S.000Z)",
    "status": "$status",
    "error_count": $error_count,
    "issues": $(printf '%s\n' "${issues[@]}" | jq -R . | jq -s .)
}
EOF
)
    
    echo "$report"
    
    # Send alerts if needed
    if [[ "$status" == "CRITICAL" ]]; then
        alert "CRITICAL" "Evilginx2 service issues: $(IFS=', '; echo "${issues[*]}")"
    elif [[ "$status" == "WARNING" ]]; then
        alert "WARNING" "Evilginx2 service warnings: $(IFS=', '; echo "${issues[*]}")"
    fi
}

# Check system resources
check_system_resources() {
    log "Checking system resources"
    
    local status="OK"
    local issues=()
    
    # Check disk usage
    local disk_usage=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
    if [[ $disk_usage -gt 90 ]]; then
        issues+=("High disk usage: ${disk_usage}%")
        status="CRITICAL"
    elif [[ $disk_usage -gt 80 ]]; then
        issues+=("Disk usage warning: ${disk_usage}%")
        status="WARNING"
    fi
    
    # Check memory usage
    local memory_usage=$(free | grep Mem | awk '{printf "%.0f", $3/$2 * 100.0}')
    if [[ $memory_usage -gt 95 ]]; then
        issues+=("High memory usage: ${memory_usage}%")
        status="CRITICAL"
    elif [[ $memory_usage -gt 85 ]]; then
        issues+=("Memory usage warning: ${memory_usage}%")
        status="WARNING"
    fi
    
    # Check load average
    local load_avg=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | sed 's/,//')
    local cpu_count=$(nproc)
    local load_percentage=$(echo "scale=0; $load_avg * 100 / $cpu_count" | bc 2>/dev/null || echo "0")
    
    if [[ $load_percentage -gt 200 ]]; then
        issues+=("High system load: ${load_avg}")
        status="CRITICAL"
    elif [[ $load_percentage -gt 150 ]]; then
        issues+=("System load warning: ${load_avg}")
        status="WARNING"
    fi
    
    local report=$(cat << EOF
{
    "system": "resources",
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%S.000Z)",
    "status": "$status",
    "disk_usage_percent": $disk_usage,
    "memory_usage_percent": $memory_usage,
    "load_average": "$load_avg",
    "issues": $(printf '%s\n' "${issues[@]}" | jq -R . | jq -s .)
}
EOF
)
    
    echo "$report"
    
    # Send alerts if needed
    if [[ "$status" == "CRITICAL" ]]; then
        alert "CRITICAL" "System resource issues: $(IFS=', '; echo "${issues[*]}")"
    elif [[ "$status" == "WARNING" ]]; then
        alert "WARNING" "System resource warnings: $(IFS=', '; echo "${issues[*]}")"
    fi
}

# Generate status report
generate_status_report() {
    local domains=("${@}")
    
    log "Generating comprehensive status report"
    
    local reports=()
    
    # Check each domain
    for domain in "${domains[@]}"; do
        local domain_health=$(check_domain_health "$domain")
        local ssl_status=$(check_ssl_expiry "$domain")
        local suspicious_activity=$(check_suspicious_activity "$domain")
        
        reports+=("$domain_health")
        reports+=("$ssl_status")
        reports+=("$suspicious_activity")
    done
    
    # Check service and system
    local service_status=$(check_evilginx_service)
    local system_status=$(check_system_resources)
    
    reports+=("$service_status")
    reports+=("$system_status")
    
    # Combine all reports
    local combined_report=$(printf '%s\n' "${reports[@]}" | jq -s '{
        "timestamp": "'"$(date -u +%Y-%m-%dT%H:%M:%S.000Z)"'",
        "alert_count": '"$ALERT_COUNT"',
        "overall_status": "'"$CURRENT_STATUS"'",
        "checks": .
    }')
    
    echo "$combined_report" > "$STATUS_FILE"
    echo "$combined_report"
}

# Run single check cycle
run_check_cycle() {
    local domains=("${@}")
    
    log "Starting monitoring check cycle"
    ALERT_COUNT=0
    CURRENT_STATUS="OK"
    
    generate_status_report "${domains[@]}" > /dev/null
    
    # Determine overall status
    if [[ $ALERT_COUNT -gt 0 ]]; then
        if grep -q "CRITICAL" "$STATUS_FILE"; then
            CURRENT_STATUS="CRITICAL"
        elif grep -q "WARNING" "$STATUS_FILE"; then
            CURRENT_STATUS="WARNING"
        fi
    fi
    
    log "Check cycle completed. Status: $CURRENT_STATUS, Alerts: $ALERT_COUNT"
}

# Continuous monitoring mode
continuous_monitoring() {
    local domains=("${@}")
    local interval="${MONITOR_INTERVAL:-300}"  # Default 5 minutes
    
    log "Starting continuous monitoring with ${interval}s interval"
    
    while true; do
        run_check_cycle "${domains[@]}"
        
        # Send periodic status updates
        if [[ $(($(date +%s) % 3600)) -lt $interval ]]; then
            alert "INFO" "Watchdog status: $CURRENT_STATUS (${#domains[@]} domains monitored)"
        fi
        
        sleep "$interval"
    done
}

# Test alert systems
test_alerts() {
    log "Testing alert systems"
    
    alert "INFO" "Test info alert - systems operational"
    sleep 2
    alert "WARNING" "Test warning alert - minor issue detected"
    sleep 2
    alert "CRITICAL" "Test critical alert - immediate attention required"
    
    log "Alert test completed"
}

# Main menu
show_menu() {
    echo -e "${BLUE}=== Evilginx2 Watchdog Monitor v3.4.1 ===${NC}"
    echo "1) Run single check cycle"
    echo "2) Start continuous monitoring"
    echo "3) Test alert systems"
    echo "4) View current status"
    echo "5) Check specific domain"
    echo "6) Generate status report"
    echo "7) View alert log"
    echo "8) Exit"
    echo -n "Select option: "
}

# Main execution
main() {
    mkdir -p logs reports exports
    load_config
    
    # Get domains from config or command line
    local domains=()
    if [[ -n "${PHISHING_DOMAINS:-}" ]]; then
        IFS=',' read -ra domains <<< "$PHISHING_DOMAINS"
    elif [[ $# -gt 1 ]]; then
        domains=("${@:2}")
    fi
    
    case "${1:-menu}" in
        "check")
            run_check_cycle "${domains[@]}"
            ;;
        "monitor")
            continuous_monitoring "${domains[@]}"
            ;;
        "test")
            test_alerts
            ;;
        "status")
            if [[ -f "$STATUS_FILE" ]]; then
                cat "$STATUS_FILE" | jq .
            else
                echo "No status file found. Run a check first."
            fi
            ;;
        *)
            while true; do
                show_menu
                read -r choice
                
                case $choice in
                    1)
                        if [[ ${#domains[@]} -eq 0 ]]; then
                            echo -n "Enter domains (comma-separated): "
                            read -r domain_input
                            IFS=',' read -ra domains <<< "$domain_input"
                        fi
                        run_check_cycle "${domains[@]}"
                        ;;
                    2)
                        if [[ ${#domains[@]} -eq 0 ]]; then
                            echo -n "Enter domains (comma-separated): "
                            read -r domain_input
                            IFS=',' read -ra domains <<< "$domain_input"
                        fi
                        echo -n "Enter check interval in seconds (default 300): "
                        read -r interval
                        MONITOR_INTERVAL=${interval:-300}
                        continuous_monitoring "${domains[@]}"
                        ;;
                    3)
                        test_alerts
                        ;;
                    4)
                        if [[ -f "$STATUS_FILE" ]]; then
                            cat "$STATUS_FILE" | jq .
                        else
                            echo "No status file found. Run a check first."
                        fi
                        ;;
                    5)
                        echo -n "Enter domain to check: "
                        read -r domain
                        check_domain_health "$domain" | jq .
                        check_ssl_expiry "$domain" | jq .
                        ;;
                    6)
                        if [[ ${#domains[@]} -eq 0 ]]; then
                            echo -n "Enter domains (comma-separated): "
                            read -r domain_input
                            IFS=',' read -ra domains <<< "$domain_input"
                        fi
                        generate_status_report "${domains[@]}" | jq .
                        ;;
                    7)
                        if [[ -f "$ALERT_LOG" ]]; then
                            tail -n 50 "$ALERT_LOG"
                        else
                            echo "No alerts logged yet."
                        fi
                        ;;
                    8)
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

# Setup signal handlers
trap 'log "Watchdog interrupted"; exit 0' INT TERM

# Check dependencies
if ! command -v jq &> /dev/null; then
    echo -e "${RED}jq is required but not installed${NC}"
    exit 1
fi

if ! command -v bc &> /dev/null; then
    echo -e "${RED}bc is required but not installed${NC}"
    exit 1
fi

# Run main function
main "$@"
