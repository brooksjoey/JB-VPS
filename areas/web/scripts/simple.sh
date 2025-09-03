#!/usr/bin/env bash
# Simple website hosting script for JB-VPS
set -euo pipefail

# Source base functionality
JB_DIR="${JB_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)}"
source "$JB_DIR/lib/base.sh"

# Host a simple website
host_simple_website() {
    log_info "Setting up a simple website" "WEB"
    
    echo "🌐 Host a Simple Website"
    echo "========================"
    echo ""
    echo "This will:"
    echo "  • Install and configure a web server (nginx)"
    echo "  • Create a sample website"
    echo "  • Make it accessible via your server's IP"
    echo ""
    
    read -p "Continue? [y/N] " -r
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Cancelled."
        return 0
    fi
    
    # Use webhost plugin if available
    if command -v webhost_setup >/dev/null 2>&1; then
        webhost_setup
    else
        # Fallback implementation
        log_info "Installing web server" "WEB"
        pkg_install nginx
        
        # Start and enable nginx
        systemd_enable_start nginx
        
        # Create basic website
        as_root mkdir -p /var/www/html
        as_root chown -R www-data:www-data /var/www/html 2>/dev/null || true
        
        if [[ ! -f /var/www/html/index.html ]]; then
            as_root tee /var/www/html/index.html > /dev/null << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Welcome to My VPS</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; text-align: center; }
        h1 { color: #333; }
        .info { background: #f0f8ff; padding: 20px; border-radius: 8px; margin: 20px 0; }
    </style>
</head>
<body>
    <h1>🚀 Welcome to My VPS!</h1>
    <div class="info">
        <p>Your web server is running successfully.</p>
        <p>Upload your website files to <code>/var/www/html/</code></p>
    </div>
</body>
</html>
EOF
        fi
        
        # Get server IP
        local server_ip
        server_ip=$(curl -s ifconfig.me 2>/dev/null || echo "your-server-ip")
        
        echo ""
        echo "✅ Simple website is now live!"
        echo "   Visit: http://$server_ip"
        echo "   Files: /var/www/html/"
        echo ""
    fi
    
    read -p "Press Enter to continue..." -r
}

# Run the function
host_simple_website
