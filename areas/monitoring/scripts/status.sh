#!/usr/bin/env bash
# System status monitoring script for JB-VPS
set -euo pipefail

# Source base functionality
JB_DIR="${JB_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)}"
source "$JB_DIR/lib/base.sh"

# Show comprehensive system status
show_system_status() {
    clear
    echo "🖥️  JB-VPS System Status"
    echo "========================"
    echo ""
    
    # Use core status function if available
    if command -v core_status >/dev/null 2>&1; then
        core_status
    else
        # Fallback implementation
        echo "📋 System Information:"
        echo "  Hostname: $(hostname)"
        echo "  OS: $(grep PRETTY_NAME /etc/os-release 2>/dev/null | cut -d= -f2 | tr -d \"" || echo "Unknown")"
        echo "  Kernel: $(uname -r)"
        echo "  Architecture: $(uname -m)"
        echo "  Uptime: $(uptime -p 2>/dev/null || uptime)"
        echo ""
        
        echo "📊 Resource Usage:"
        local load_avg
        load_avg=$(uptime | awk -F'load average:' '{print $2}' | xargs)
        echo "  Load Average: $load_avg"
        
        if command -v free >/dev/null 2>&1; then
            local memory_info
            memory_info=$(free -h | awk 'NR==2{printf "Used: %s / %s", $3, $2}')
            echo "  Memory: $memory_info"
        fi
        
        if command -v df >/dev/null 2>&1; then
            local disk_usage
            disk_usage=$(df -h / | awk 'NR==2{print $5}')
            echo "  Disk Usage: $disk_usage"
        fi
        echo ""
        
        echo "🔧 Services:"
        if command -v systemctl >/dev/null 2>&1; then
            if systemctl is-active --quiet nginx 2>/dev/null; then
                echo "  ✅ Nginx: Running"
            elif systemctl is-active --quiet apache2 2>/dev/null; then
                echo "  ✅ Apache: Running"
            else
                echo "  ❌ Web Server: Not running"
            fi
            
            if systemctl is-active --quiet ssh 2>/dev/null || systemctl is-active --quiet sshd 2>/dev/null; then
                echo "  ✅ SSH: Running"
            else
                echo "  ❌ SSH: Not running"
            fi
        fi
        echo ""
    fi
    
    echo "Press Enter to continue..."
    read -r
}

# Run the function
show_system_status
