#!/usr/bin/env bash
# webhost.sh - Interactive HTML Page Hosting for VPS
# No firewall changes - just works with existing setup

set -uE -o pipefail

# ---------- Configuration ----------
readonly SCRIPT_NAME="webhost.sh"
readonly SCRIPT_VERSION="1.0.0"
readonly DEFAULT_PORT=8080
readonly WEB_ROOT="$HOME/webhost"
readonly LOG_FILE="/var/log/webhost.log"

# ---------- UI / Logging ----------
BOLD="$(tput bold 2>/dev/null || printf '')"
RED="$(tput setaf 1 2>/dev/null || printf '')"
GREEN="$(tput setaf 2 2>/dev/null || printf '')"
YELLOW="$(tput setaf 3 2>/dev/null || printf '')"
BLUE="$(tput setaf 4 2>/dev/null || printf '')"
RESET="$(tput sgr0 2>/dev/null || printf '')"

# Logging setup
mkdir -p /var/log 2>/dev/null || true
touch "$LOG_FILE" 2>/dev/null || LOG_FILE="/tmp/webhost.log"

# ---------- Utility Functions ----------
ts() { 
    date '+%F %T' 
}

log_message() {
    local level="$1"
    local message="$2"
    local color="$3"
    echo -e "[$(ts)] ${color}${level}: ${message}${RESET}"
    echo "[$(ts)] ${level}: ${message}" >>"$LOG_FILE"
}

info() { 
    log_message "INFO" "$1" "$GREEN"
}

warn() { 
    log_message "WARN" "$1" "$YELLOW"
}

err() { 
    log_message "ERROR" "$1" "$RED"
}

# ---------- Error Handling ----------
trap 'error_handler $LINENO' ERR
trap 'interrupt_handler' SIGINT

error_handler() {
    local line="$1"
    err "Unexpected error occurred at line $line. Check $LOG_FILE for details."
    return 0
}

interrupt_handler() {
    echo
    warn "Operation interrupted by user."
    return 0
}

# ---------- Core Functions ----------
initialize_environment() {
    # Create web root directory if it doesn't exist
    mkdir -p "$WEB_ROOT" 2>/dev/null || {
        err "Failed to create web root directory: $WEB_ROOT"
        exit 1
    }
    
    # Create a sample HTML file if the directory is empty
    if [ -z "$(ls -A "$WEB_ROOT")" ]; then
        create_sample_html
    fi
    
    info "Web root directory: $WEB_ROOT"
}

create_sample_html() {
    local sample_file="$WEB_ROOT/index.html"
    cat > "$sample_file" << EOF
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>My VPS Web Host</title>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            margin: 0;
            padding: 20px;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: #333;
            min-height: 100vh;
        }
        .container {
            max-width: 800px;
            margin: 0 auto;
            background: white;
            padding: 30px;
            border-radius: 15px;
            box-shadow: 0 10px 30px rgba(0,0,0,0.1);
        }
        h1 {
            color: #764ba2;
            text-align: center;
            margin-bottom: 30px;
        }
        .ip-address {
            background: #f8f9fa;
            padding: 15px;
            border-radius: 8px;
            margin: 20px 0;
            text-align: center;
            font-family: monospace;
            font-size: 1.2em;
        }
        .btn {
            display: inline-block;
            background: #667eea;
            color: white;
            padding: 12px 24px;
            border-radius: 30px;
            text-decoration: none;
            font-weight: bold;
            margin: 10px 5px;
            transition: all 0.3s;
        }
        .btn:hover {
            background: #764ba2;
            transform: translateY(-2px);
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>Welcome to Your VPS Web Server</h1>
        <p>This is a sample HTML page hosted on your VPS. You can replace this file with your own HTML content.</p>
        
        <h2>Your Server's IP Address:</h2>
        <div class="ip-address">SERVER_IP_PLACEHOLDER</div>
        
        <h2>Access Options:</h2>
        <p>You can access this page using:</p>
        <ul>
            <li>Regular IP: http://PUBLIC_IP_PLACEHOLDER:PORT_PLACEHOLDER</li>
            <li>Tailscale: http://TAILSCALE_IP_PLACEHOLDER:PORT_PLACEHOLDER</li>
        </ul>
        
        <h2>Getting Started:</h2>
        <ol>
            <li>Replace this file with your own HTML content</li>
            <li>Access your VPS IP address from any browser</li>
            <li>Use the webhost.sh script to manage your server</li>
        </ol>
    </div>
</body>
</html>
EOF
    
    # Get the server's IP addresses
    local public_ip tailscale_ip
    public_ip=$(get_public_ip)
    tailscale_ip=$(get_tailscale_ip)
    
    sed -i "s/SERVER_IP_PLACEHOLDER/$public_ip/g" "$sample_file"
    sed -i "s/PUBLIC_IP_PLACEHOLDER/$public_ip/g" "$sample_file"
    sed -i "s/TAILSCALE_IP_PLACEHOLDER/$tailscale_ip/g" "$sample_file"
    sed -i "s/PORT_PLACEHOLDER/$DEFAULT_PORT/g" "$sample_file"
    
    info "Created sample HTML file: $sample_file"
}

get_public_ip() {
    local ip
    ip=$(curl -s https://api.ipify.org 2>/dev/null || echo "unknown")
    [ "$ip" = "unknown" ] && ip=$(hostname -I | awk '{print $1}' | head -n1)
    [ -z "$ip" ] && ip="127.0.0.1"
    echo "$ip"
}

get_tailscale_ip() {
    if command -v tailscale >/dev/null 2>&1 && tailscale status >/dev/null 2>&1; then
        tailscale ip -4 2>/dev/null || echo "100.x.x.x (Tailscale)"
    else
        echo "Not connected"
    fi
}

start_web_server() {
    local port="${1:-$DEFAULT_PORT}"
    
    # Check if port is available
    if lsof -Pi ":$port" -sTCP:LISTEN -t >/dev/null ; then
        err "Port $port is already in use. Please choose a different port."
        return 1
    fi
    
    info "Starting web server on port $port"
    info "Web root: $WEB_ROOT"
    
    local public_ip tailscale_ip
    public_ip=$(get_public_ip)
    tailscale_ip=$(get_tailscale_ip)
    
    echo
    echo "${BOLD}${GREEN}Web server started successfully!${RESET}"
    echo "${BOLD}Access your server from:${RESET}"
    echo "  🌐 Public: http://$public_ip:$port"
    if [ "$tailscale_ip" != "Not connected" ]; then
        echo "  🔒 Tailscale: http://$tailscale_ip:$port"
    fi
    echo "  💻 Local: http://localhost:$port"
    echo
    echo "${BOLD}ℹ️  No firewall changes made - using existing network setup${RESET}"
    echo
    echo "Press Ctrl+C to stop the server"
    echo
    
    # Start Python web server
    cd "$WEB_ROOT" || exit 1
    python3 -m http.server "$port"
}

list_html_files() {
    info "HTML files available in $WEB_ROOT:"
    echo
    
    local files=()
    while IFS= read -r -d $'\0' file; do
        files+=("$file")
    done < <(find "$WEB_ROOT" -maxdepth 1 -name "*.html" -type f -print0)
    
    if [ ${#files[@]} -eq 0 ]; then
        echo "  No HTML files found."
        return 0
    fi
    
    for ((i=0; i<${#files[@]}; i++)); do
        echo "  $((i+1)). $(basename "${files[$i]}")"
    done
}

create_new_html() {
    read -r -p "Enter filename (without .html extension): " filename
    filename="${filename// /_}"  # Replace spaces with underscores
    
    if [[ -z "$filename" ]]; then
        err "Filename cannot be empty."
        return 1
    fi
    
    local filepath="$WEB_ROOT/${filename}.html"
    
    if [[ -f "$filepath" ]]; then
        warn "File already exists: $(basename "$filepath")"
        read -r -p "Overwrite? (y/N): " overwrite
        if [[ ! "$overwrite" =~ ^[Yy]$ ]]; then
            info "Operation cancelled."
            return 0
        fi
    fi
    
    cat > "$filepath" << EOF
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>${filename}</title>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            margin: 0;
            padding: 40px;
            background: #f5f5f5;
            color: #333;
        }
        .container {
            max-width: 800px;
            margin: 0 auto;
            background: white;
            padding: 30px;
            border-radius: 10px;
            box-shadow: 0 5px 15px rgba(0,0,0,0.1);
        }
        h1 {
            color: #3366cc;
            border-bottom: 2px solid #3366cc;
            padding-bottom: 10px;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>${filename}</h1>
        <p>This is your new HTML page. Edit this file at: <code>${filepath}</code></p>
        <p>You can access this page from your iPad browser using your VPS IP address and port.</p>
    </div>
</body>
</html>
EOF
    
    info "Created new HTML file: ${filename}.html"
}

open_in_browser() {
    local port="${1:-$DEFAULT_PORT}"
    local public_ip tailscale_ip
    public_ip=$(get_public_ip)
    tailscale_ip=$(get_tailscale_ip)
    
    echo
    echo "${BOLD}To view your website:${RESET}"
    echo
    echo "1. On your iPad, open Safari, Chrome, or iCab"
    echo "2. Enter one of these addresses:"
    echo
    echo "   ${GREEN}Regular: http://$public_ip:$port${RESET}"
    if [ "$tailscale_ip" != "Not connected" ]; then
        echo "   ${BLUE}Tailscale: http://$tailscale_ip:$port${RESET}"
    fi
    echo
    echo "3. Press Enter to load the page"
    echo
    read -r -p "Press Enter to continue..."
}

# ---------- Main Menu ----------
show_menu() {
    echo
    echo "${BOLD}=== VPS Web Hosting Manager ===${RESET}"
    echo "${GREEN} 1) Start web server (port $DEFAULT_PORT)"
    echo " 2) Start web server on custom port"
    echo " 3) List HTML files"
    echo " 4) Create new HTML file"
    echo " 5) Open in browser instructions"
    echo " 6) Open file manager"
    echo " 7) View log"
    echo " 8) Exit${RESET}"
    echo
}

main_menu() {
    initialize_environment
    
    while true; do
        show_menu
        read -r -p "Select option (1-8): " choice
        
        case "${choice:-}" in
            1)
                start_web_server "$DEFAULT_PORT"
                ;;
            2)
                read -r -p "Enter port number: " custom_port
                if [[ "$custom_port" =~ ^[0-9]+$ ]] && [ "$custom_port" -ge 1024 ] && [ "$custom_port" -le 65535 ]; then
                    start_web_server "$custom_port"
                else
                    err "Invalid port number. Must be between 1024 and 65535."
                fi
                ;;
            3)
                list_html_files
                ;;
            4)
                create_new_html
                ;;
            5)
                open_in_browser "$DEFAULT_PORT"
                ;;
            6)
                info "Opening file manager for: $WEB_ROOT"
                if command -v mc >/dev/null 2>&1; then
                    mc "$WEB_ROOT"
                elif command -v nnn >/dev/null 2>&1; then
                    nnn "$WEB_ROOT"
                else
                    echo "No file manager found. You can navigate to: $WEB_ROOT"
                    echo "Files in that directory:"
                    ls -la "$WEB_ROOT"
                fi
                ;;
            7)
                echo
                echo "${BOLD}=== Log File Contents ===${RESET}"
                if [ -f "$LOG_FILE" ] && [ -s "$LOG_FILE" ]; then
                    cat "$LOG_FILE"
                else
                    echo "Log file is empty or doesn't exist."
                fi
                ;;
            8)
                info "Exiting web hosting manager."
                exit 0
                ;;
            *)
                warn "Invalid selection. Please choose 1-8."
                ;;
        esac
        
        echo
        read -r -p "Press Enter to continue..."
    done
}

# ---------- Initialization ----------
check_dependencies() {
    if ! command -v python3 >/dev/null 2>&1; then
        err "Python 3 is required but not installed. Please install it with:"
        err "  sudo apt update && sudo apt install python3"
        exit 1
    fi
}

# ---------- Main Execution ----------
main() {
    echo "${BOLD}VPS Web Hosting Manager v$SCRIPT_VERSION${RESET}"
    echo "This script helps you host HTML pages on your VPS"
    echo "and access them from your iPad browser."
    echo
    
    check_dependencies
    main_menu
}

main "$@"