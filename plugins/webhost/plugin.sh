#!/usr/bin/env bash
# Webhost Plugin for JB-VPS
# Provides web server setup and hosting functionality

set -euo pipefail
source "$JB_DIR/lib/base.sh"

# Setup web hosting environment
webhost_setup() {
    log_info "Setting up web hosting environment" "WEBHOST"
    
    # Check if we already have a web server installed
    if systemctl is-active --quiet nginx 2>/dev/null; then
        log_info "Nginx is already running" "WEBHOST"
    elif systemctl is-active --quiet apache2 2>/dev/null; then
        log_info "Apache is already running" "WEBHOST"
    else
        log_info "Installing and configuring web server" "WEBHOST"
        
        # Install nginx by default
        pkg_install nginx
        
        # Enable and start nginx
        systemd_enable_start nginx
    fi
    
    # Create default web directory structure
    as_root mkdir -p /var/www/html
    as_root chown -R www-data:www-data /var/www/html 2>/dev/null || \
    as_root chown -R nginx:nginx /var/www/html 2>/dev/null || \
    as_root chown -R apache:apache /var/www/html 2>/dev/null || true
    
    # Create a simple index page if none exists
    if [[ ! -f /var/www/html/index.html ]]; then
        as_root tee /var/www/html/index.html > /dev/null << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Welcome to JB-VPS</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 40px; background: #f5f5f5; }
        .container { max-width: 800px; margin: 0 auto; background: white; padding: 40px; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        h1 { color: #333; border-bottom: 3px solid #007bff; padding-bottom: 10px; }
        .status { background: #d4edda; border: 1px solid #c3e6cb; color: #155724; padding: 15px; border-radius: 4px; margin: 20px 0; }
        .info { background: #d1ecf1; border: 1px solid #bee5eb; color: #0c5460; padding: 15px; border-radius: 4px; margin: 20px 0; }
        code { background: #f8f9fa; padding: 2px 6px; border-radius: 3px; font-family: monospace; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🚀 JB-VPS Web Server</h1>
        
        <div class="status">
            <strong>✅ Success!</strong> Your web server is running and ready to host websites.
        </div>
        
        <h2>What's Next?</h2>
        <p>Your web server is now configured and ready to serve websites. Here are some next steps:</p>
        
        <ul>
            <li><strong>Upload your website:</strong> Place your files in <code>/var/www/html/</code></li>
            <li><strong>Configure domains:</strong> Use <code>jb menu</code> → "Websites & domains"</li>
            <li><strong>Add SSL certificates:</strong> Set up HTTPS for your domains</li>
            <li><strong>Monitor your server:</strong> Use <code>jb status</code> to check system health</li>
        </ul>
        
        <div class="info">
            <strong>💡 Tip:</strong> Run <code>jb menu</code> to access the interactive menu system for easy server management.
        </div>
        
        <h2>Server Information</h2>
        <p><strong>Hostname:</strong> <span id="hostname">Loading...</span></p>
        <p><strong>Server Time:</strong> <span id="time">Loading...</span></p>
        
        <script>
            document.getElementById('hostname').textContent = window.location.hostname || 'localhost';
            document.getElementById('time').textContent = new Date().toLocaleString();
        </script>
    </div>
</body>
</html>
EOF
    fi
    
    # Get server IP for display
    local server_ip
    server_ip=$(curl -s ifconfig.me 2>/dev/null || echo "your-server-ip")
    
    log_info "Web hosting setup completed successfully" "WEBHOST"
    echo ""
    echo "🌐 Web server is now running!"
    echo "   Visit: http://$server_ip"
    echo "   Files: /var/www/html/"
    echo ""
    echo "Use 'jb menu' → 'Websites & domains' for more options."
    
    # Use legacy script if available
    local legacy_script="$JB_DIR/tools/webhost/webhost.sh"
    if [[ -x "$legacy_script" ]]; then
        log_info "Running additional webhost configuration" "WEBHOST"
        as_root "$legacy_script" "$@"
    fi
}

# Register webhost commands
jb_register "webhost:setup" webhost_setup "Install web server and host a simple site" "web"
