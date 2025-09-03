#!/usr/bin/env bash
# Dashboard Plugin for JB-VPS
# Provides web dashboard installation and management

set -euo pipefail
source "$JB_DIR/lib/base.sh"

# Install the VPS dashboard
dash_install() {
    log_info "Installing JB-VPS dashboard" "DASHBOARD"
    
    local dashboard_dir="$JB_DIR/dashboards/vps-dashboard"
    
    if [[ ! -d "$dashboard_dir" ]]; then
        log_error "Dashboard directory not found: $dashboard_dir" "DASHBOARD"
        return 1
    fi
    
    # Ensure we have systemd
    need systemctl || die "systemd required for dashboard installation"
    
    # Check if we have a web server running
    if ! systemctl is-active --quiet nginx 2>/dev/null && ! systemctl is-active --quiet apache2 2>/dev/null; then
        log_info "No web server detected, setting up nginx first" "DASHBOARD"
        if command -v webhost_setup >/dev/null 2>&1; then
            webhost_setup
        else
            pkg_install nginx
            systemd_enable_start nginx
        fi
    fi
    
    # Install dashboard files
    log_info "Installing dashboard files" "DASHBOARD"
    as_root mkdir -p /var/www/dashboard
    as_root cp -r "$dashboard_dir"/* /var/www/dashboard/
    as_root chown -R www-data:www-data /var/www/dashboard 2>/dev/null || \
    as_root chown -R nginx:nginx /var/www/dashboard 2>/dev/null || true
    
    # Create nginx configuration for dashboard
    local nginx_config="/etc/nginx/sites-available/jb-dashboard"
    as_root tee "$nginx_config" > /dev/null << 'EOF'
server {
    listen 8080;
    server_name _;
    
    root /var/www/dashboard;
    index index.html;
    
    location / {
        try_files $uri $uri/ =404;
    }
    
    location /api/sysinfo {
        add_header Content-Type application/json;
        alias /var/lib/jb-vps/dashboard/sysinfo.json;
    }
    
    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
}
EOF
    
    # Enable the site
    as_root ln -sf "$nginx_config" /etc/nginx/sites-enabled/jb-dashboard
    as_root systemctl reload nginx
    
    # Set up system info generation
    as_root mkdir -p /var/lib/jb-vps/dashboard
    
    # Create systemd service for dashboard updates
    as_root tee /etc/systemd/system/jb-dashboard-update.service > /dev/null << 'EOF'
[Unit]
Description=JB-VPS Dashboard Data Update
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/jb dashboard:sysinfo
User=root
EOF
    
    # Create systemd timer for regular updates
    as_root tee /etc/systemd/system/jb-dashboard-update.timer > /dev/null << 'EOF'
[Unit]
Description=Update JB-VPS Dashboard Data
Requires=jb-dashboard-update.service

[Timer]
OnCalendar=*:0/5
Persistent=true

[Install]
WantedBy=timers.target
EOF
    
    # Enable and start the timer
    as_root systemctl daemon-reload
    as_root systemctl enable jb-dashboard-update.timer
    as_root systemctl start jb-dashboard-update.timer
    
    # Generate initial system info
    dash_sysinfo
    
    # Get server IP for display
    local server_ip
    server_ip=$(curl -s ifconfig.me 2>/dev/null || echo "your-server-ip")
    
    log_info "Dashboard installation completed successfully" "DASHBOARD"
    echo ""
    echo "📊 JB-VPS Dashboard is now available!"
    echo "   Visit: http://$server_ip:8080"
    echo "   Updates every 5 minutes automatically"
    echo ""
    
    # Use legacy installer if available
    local legacy_installer="$dashboard_dir/scripts/install_dashboard.sh"
    if [[ -x "$legacy_installer" ]]; then
        log_info "Running additional dashboard setup" "DASHBOARD"
        (cd "$dashboard_dir" && as_root ./scripts/install_dashboard.sh)
    fi
}

# Generate system information for dashboard
dash_sysinfo() {
    log_debug "Generating dashboard system information" "DASHBOARD"
    
    local output_file="/var/lib/jb-vps/dashboard/sysinfo.json"
    as_root mkdir -p "$(dirname "$output_file")"
    
    # Use enhanced system info if available
    if command -v get_system_info >/dev/null 2>&1; then
        get_system_info json | as_root tee "$output_file" > /dev/null
    else
        # Fallback to legacy script
        local legacy_script="$JB_DIR/dashboards/vps-dashboard/scripts/sysinfo.sh"
        if [[ -x "$legacy_script" ]]; then
            as_root "$legacy_script" | as_root tee "$output_file" > /dev/null
        else
            # Basic fallback
            as_root tee "$output_file" > /dev/null << EOF
{
  "hostname": "$(hostname)",
  "kernel": "$(uname -r)",
  "os": "$(grep PRETTY_NAME /etc/os-release 2>/dev/null | cut -d= -f2 | tr -d \"" || echo "Unknown")",
  "uptime": "$(uptime -p 2>/dev/null || uptime)",
  "timestamp": "$(date -Iseconds)"
}
EOF
        fi
    fi
    
    log_debug "Dashboard system information updated" "DASHBOARD"
}

# Register dashboard commands
jb_register "dashboard:install" dash_install "Install the VPS dashboard" "dashboard"
jb_register "dashboard:sysinfo" dash_sysinfo "Update dashboard system information" "dashboard"
