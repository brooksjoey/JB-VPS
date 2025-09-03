#!/usr/bin/env bash
# Add new application script for JB-VPS
set -euo pipefail

# Source base functionality
JB_DIR="${JB_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)}"
source "$JB_DIR/lib/base.sh"

# Add a new application
add_new_app() {
    log_info "Adding a new application" "APPS"
    
    echo "📱 Add a New Application"
    echo "========================"
    echo ""
    echo "Choose an application to install:"
    echo ""
    echo "🌐 Web Services:"
    echo "  1) Nginx - High-performance web server"
    echo "  2) Apache - Popular web server"
    echo ""
    echo "🗄️  Databases:"
    echo "  3) PostgreSQL - Advanced relational database"
    echo "  4) MySQL - Popular relational database"
    echo "  5) MariaDB - MySQL-compatible database"
    echo "  6) SQLite - Lightweight file-based database"
    echo ""
    echo "🔒 Security:"
    echo "  7) Fail2ban - Intrusion prevention system"
    echo "  8) UFW - Uncomplicated firewall"
    echo ""
    echo "🛠️  Development Tools:"
    echo "  9) Git - Version control system"
    echo "  10) Node.js - JavaScript runtime"
    echo "  11) Python3 - Python programming language"
    echo "  12) Docker - Container platform"
    echo ""
    echo "📊 Monitoring:"
    echo "  13) htop - Interactive process viewer"
    echo "  14) JB-VPS Dashboard - Web-based system monitor"
    echo ""
    echo "  0) Back to menu"
    echo ""
    
    read -p "Choose an option (1-14): " -r choice
    
    case "$choice" in
        1) install_nginx ;;
        2) install_apache ;;
        3) install_postgresql ;;
        4) install_mysql ;;
        5) install_mariadb ;;
        6) install_sqlite ;;
        7) install_fail2ban ;;
        8) install_ufw ;;
        9) install_git ;;
        10) install_nodejs ;;
        11) install_python3 ;;
        12) install_docker ;;
        13) install_htop ;;
        14) install_dashboard ;;
        0) return ;;
        *) 
            echo "Invalid option. Please try again."
            read -p "Press Enter to continue..." -r
            add_new_app
            ;;
    esac
}

# Install Nginx
install_nginx() {
    echo "Installing Nginx web server..."
    
    if systemctl is-active --quiet nginx 2>/dev/null; then
        echo "✅ Nginx is already installed and running"
    else
        pkg_install nginx
        systemd_enable_start nginx
        
        # Create basic configuration
        as_root mkdir -p /var/www/html
        as_root chown -R www-data:www-data /var/www/html 2>/dev/null || true
        
        echo "✅ Nginx installed and started successfully"
        echo "   Config: /etc/nginx/"
        echo "   Web root: /var/www/html/"
    fi
    
    read -p "Press Enter to continue..." -r
}

# Install Apache
install_apache() {
    echo "Installing Apache web server..."
    
    if systemctl is-active --quiet apache2 2>/dev/null; then
        echo "✅ Apache is already installed and running"
    else
        pkg_install apache2
        systemd_enable_start apache2
        
        echo "✅ Apache installed and started successfully"
        echo "   Config: /etc/apache2/"
        echo "   Web root: /var/www/html/"
    fi
    
    read -p "Press Enter to continue..." -r
}

# Install PostgreSQL
install_postgresql() {
    echo "Installing PostgreSQL database server..."
    
    if systemctl is-active --quiet postgresql 2>/dev/null; then
        echo "✅ PostgreSQL is already installed and running"
    else
        pkg_install postgresql postgresql-contrib
        systemd_enable_start postgresql
        
        echo "✅ PostgreSQL installed and started successfully"
        echo "   Data directory: /var/lib/postgresql/"
        echo "   Config: /etc/postgresql/"
        echo ""
        echo "To create a database and user, use:"
        echo "   jb menu → Databases → Create a database and user"
    fi
    
    read -p "Press Enter to continue..." -r
}

# Install MySQL
install_mysql() {
    echo "Installing MySQL database server..."
    
    if systemctl is-active --quiet mysql 2>/dev/null; then
        echo "✅ MySQL is already installed and running"
    else
        pkg_install mysql-server
        systemd_enable_start mysql
        
        echo "✅ MySQL installed and started successfully"
        echo "   Data directory: /var/lib/mysql/"
        echo "   Config: /etc/mysql/"
        echo ""
        echo "⚠️  Remember to run 'mysql_secure_installation' to secure your installation"
    fi
    
    read -p "Press Enter to continue..." -r
}

# Install MariaDB
install_mariadb() {
    echo "Installing MariaDB database server..."
    
    if systemctl is-active --quiet mariadb 2>/dev/null; then
        echo "✅ MariaDB is already installed and running"
    else
        pkg_install mariadb-server
        systemd_enable_start mariadb
        
        echo "✅ MariaDB installed and started successfully"
        echo "   Data directory: /var/lib/mysql/"
        echo "   Config: /etc/mysql/"
        echo ""
        echo "⚠️  Remember to run 'mysql_secure_installation' to secure your installation"
    fi
    
    read -p "Press Enter to continue..." -r
}

# Install SQLite
install_sqlite() {
    echo "Installing SQLite database..."
    
    if command -v sqlite3 >/dev/null 2>&1; then
        echo "✅ SQLite is already installed"
        local sqlite_version
        sqlite_version=$(sqlite3 --version | cut -d' ' -f1)
        echo "   Version: $sqlite_version"
    else
        pkg_install sqlite3
        echo "✅ SQLite installed successfully"
        echo "   Command: sqlite3"
        echo "   Usage: sqlite3 database.db"
    fi
    
    read -p "Press Enter to continue..." -r
}

# Install Fail2ban
install_fail2ban() {
    echo "Installing Fail2ban intrusion prevention system..."
    
    if systemctl is-active --quiet fail2ban 2>/dev/null; then
        echo "✅ Fail2ban is already installed and running"
    else
        pkg_install fail2ban
        systemd_enable_start fail2ban
        
        echo "✅ Fail2ban installed and started successfully"
        echo "   Config: /etc/fail2ban/"
        echo "   Logs: /var/log/fail2ban.log"
    fi
    
    read -p "Press Enter to continue..." -r
}

# Install UFW
install_ufw() {
    echo "Installing UFW (Uncomplicated Firewall)..."
    
    if command -v ufw >/dev/null 2>&1; then
        echo "✅ UFW is already installed"
        local ufw_status
        ufw_status=$(ufw status | head -1)
        echo "   Status: $ufw_status"
    else
        pkg_install ufw
        echo "✅ UFW installed successfully"
        echo "   Enable with: ufw enable"
        echo "   Status: ufw status"
    fi
    
    read -p "Press Enter to continue..." -r
}

# Install Git
install_git() {
    echo "Installing Git version control system..."
    
    if command -v git >/dev/null 2>&1; then
        echo "✅ Git is already installed"
        local git_version
        git_version=$(git --version | cut -d' ' -f3)
        echo "   Version: $git_version"
    else
        pkg_install git
        echo "✅ Git installed successfully"
        echo "   Configure with: git config --global user.name 'Your Name'"
        echo "                   git config --global user.email 'your@email.com'"
    fi
    
    read -p "Press Enter to continue..." -r
}

# Install Node.js
install_nodejs() {
    echo "Installing Node.js JavaScript runtime..."
    
    if command -v node >/dev/null 2>&1; then
        echo "✅ Node.js is already installed"
        local node_version
        node_version=$(node --version)
        echo "   Version: $node_version"
        local npm_version
        npm_version=$(npm --version 2>/dev/null || echo "Not available")
        echo "   NPM Version: $npm_version"
    else
        pkg_install nodejs npm
        echo "✅ Node.js and NPM installed successfully"
        echo "   Node: $(node --version 2>/dev/null || echo 'Error getting version')"
        echo "   NPM: $(npm --version 2>/dev/null || echo 'Error getting version')"
    fi
    
    read -p "Press Enter to continue..." -r
}

# Install Python3
install_python3() {
    echo "Installing Python3 programming language..."
    
    if command -v python3 >/dev/null 2>&1; then
        echo "✅ Python3 is already installed"
        local python_version
        python_version=$(python3 --version | cut -d' ' -f2)
        echo "   Version: $python_version"
        local pip_version
        pip_version=$(pip3 --version 2>/dev/null | cut -d' ' -f2 || echo "Not available")
        echo "   Pip Version: $pip_version"
    else
        pkg_install python3 python3-pip
        echo "✅ Python3 and pip installed successfully"
        echo "   Python: $(python3 --version 2>/dev/null || echo 'Error getting version')"
        echo "   Pip: $(pip3 --version 2>/dev/null | cut -d' ' -f2 || echo 'Error getting version')"
    fi
    
    read -p "Press Enter to continue..." -r
}

# Install Docker
install_docker() {
    echo "Installing Docker container platform..."
    
    if command -v docker >/dev/null 2>&1; then
        echo "✅ Docker is already installed"
        local docker_version
        docker_version=$(docker --version | cut -d' ' -f3 | sed 's/,//')
        echo "   Version: $docker_version"
    else
        # Install Docker using official method
        pkg_install curl
        curl -fsSL https://get.docker.com -o get-docker.sh
        as_root sh get-docker.sh
        rm get-docker.sh
        
        # Add current user to docker group if not root
        if [[ $EUID -ne 0 ]]; then
            as_root usermod -aG docker "$USER"
            echo "⚠️  You need to log out and back in for Docker group membership to take effect"
        fi
        
        systemd_enable_start docker
        echo "✅ Docker installed and started successfully"
        echo "   Version: $(docker --version 2>/dev/null || echo 'Error getting version')"
    fi
    
    read -p "Press Enter to continue..." -r
}

# Install htop
install_htop() {
    echo "Installing htop interactive process viewer..."
    
    if command -v htop >/dev/null 2>&1; then
        echo "✅ htop is already installed"
        echo "   Run with: htop"
    else
        pkg_install htop
        echo "✅ htop installed successfully"
        echo "   Run with: htop"
    fi
    
    read -p "Press Enter to continue..." -r
}

# Install JB-VPS Dashboard
install_dashboard() {
    echo "Installing JB-VPS Dashboard..."
    
    if systemctl is-active --quiet jb-dashboard-update.timer 2>/dev/null; then
        echo "✅ JB-VPS Dashboard is already installed and running"
        local server_ip
        server_ip=$(curl -s ifconfig.me 2>/dev/null || echo "your-server-ip")
        echo "   Access at: http://$server_ip:8080"
    else
        if command -v dash_install >/dev/null 2>&1; then
            dash_install
        else
            echo "❌ Dashboard installation function not available"
            echo "   Try: jb dashboard:install"
        fi
    fi
    
    read -p "Press Enter to continue..." -r
}

# Run the function
add_new_app
