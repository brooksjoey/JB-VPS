#!/usr/bin/env bash
# List installed applications script for JB-VPS
set -euo pipefail

# Source base functionality
JB_DIR="${JB_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)}"
source "$JB_DIR/lib/base.sh"

# List installed applications
list_installed_apps() {
    log_info "Listing installed applications" "APPS"
    
    echo "📱 Installed Applications"
    echo "========================"
    echo ""
    
    echo "🌐 Web Services:"
    if systemctl is-active --quiet nginx 2>/dev/null; then
        echo "  ✅ Nginx - Web server"
        local nginx_version
        nginx_version=$(nginx -v 2>&1 | cut -d'/' -f2 | cut -d' ' -f1)
        echo "     Version: $nginx_version"
        echo "     Status: $(systemctl is-active nginx)"
        echo "     Config: /etc/nginx/"
    elif systemctl is-active --quiet apache2 2>/dev/null; then
        echo "  ✅ Apache - Web server"
        local apache_version
        apache_version=$(apache2 -v 2>/dev/null | head -1 | cut -d'/' -f2 | cut -d' ' -f1)
        echo "     Version: $apache_version"
        echo "     Status: $(systemctl is-active apache2)"
        echo "     Config: /etc/apache2/"
    else
        echo "  ❌ No web server installed"
    fi
    echo ""
    
    echo "🗄️  Database Services:"
    if systemctl is-active --quiet postgresql 2>/dev/null; then
        echo "  ✅ PostgreSQL - Database server"
        local pg_version
        pg_version=$(sudo -u postgres psql -c "SELECT version();" 2>/dev/null | grep PostgreSQL | cut -d' ' -f2 || echo "Unknown")
        echo "     Version: $pg_version"
        echo "     Status: $(systemctl is-active postgresql)"
        echo "     Data: /var/lib/postgresql/"
    elif systemctl is-active --quiet mysql 2>/dev/null; then
        echo "  ✅ MySQL - Database server"
        local mysql_version
        mysql_version=$(mysql --version 2>/dev/null | cut -d' ' -f6 | cut -d',' -f1 || echo "Unknown")
        echo "     Version: $mysql_version"
        echo "     Status: $(systemctl is-active mysql)"
        echo "     Data: /var/lib/mysql/"
    elif systemctl is-active --quiet mariadb 2>/dev/null; then
        echo "  ✅ MariaDB - Database server"
        local mariadb_version
        mariadb_version=$(mysql --version 2>/dev/null | cut -d' ' -f6 | cut -d',' -f1 || echo "Unknown")
        echo "     Version: $mariadb_version"
        echo "     Status: $(systemctl is-active mariadb)"
        echo "     Data: /var/lib/mysql/"
    else
        echo "  ❌ No database server installed"
    fi
    echo ""
    
    echo "🔒 Security Services:"
    if systemctl is-active --quiet fail2ban 2>/dev/null; then
        echo "  ✅ Fail2ban - Intrusion prevention"
        echo "     Status: $(systemctl is-active fail2ban)"
        echo "     Config: /etc/fail2ban/"
    else
        echo "  ❌ Fail2ban not installed"
    fi
    
    if command -v ufw >/dev/null 2>&1; then
        if ufw status | grep -q "Status: active"; then
            echo "  ✅ UFW - Firewall (active)"
        else
            echo "  ⚠️  UFW - Firewall (inactive)"
        fi
    elif systemctl is-active --quiet firewalld 2>/dev/null; then
        echo "  ✅ Firewalld - Firewall"
        echo "     Status: $(systemctl is-active firewalld)"
    else
        echo "  ❌ No firewall configured"
    fi
    echo ""
    
    echo "🛠️  Development Tools:"
    local dev_tools=("git" "curl" "wget" "vim" "nano" "htop" "tree" "jq")
    for tool in "${dev_tools[@]}"; do
        if command -v "$tool" >/dev/null 2>&1; then
            echo "  ✅ $tool"
        else
            echo "  ❌ $tool"
        fi
    done
    echo ""
    
    echo "📊 Monitoring:"
    if systemctl is-active --quiet jb-dashboard-update.timer 2>/dev/null; then
        echo "  ✅ JB-VPS Dashboard - System monitoring"
        echo "     Status: $(systemctl is-active jb-dashboard-update.timer)"
    else
        echo "  ❌ JB-VPS Dashboard not installed"
    fi
    echo ""
    
    echo "Use 'jb menu' → 'Apps & services' → 'Add a new app' to install more applications."
    echo ""
    read -p "Press Enter to continue..." -r
}

# Run the function
list_installed_apps
