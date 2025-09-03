#!/usr/bin/env bash
# JB-VPS One-Shot Installer
# Detects distro, installs dependencies, and sets up the jb command

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log() { printf "${BLUE}[JB-VPS]${NC} %s\n" "$*"; }
log_success() { printf "${GREEN}[✓]${NC} %s\n" "$*"; }
log_warn() { printf "${YELLOW}[!]${NC} %s\n" "$*"; }
log_error() { printf "${RED}[✗]${NC} %s\n" "$*" >&2; }

# Detect OS and set package manager
detect_os() {
    if [[ ! -f /etc/os-release ]]; then
        log_error "Cannot detect OS - /etc/os-release not found"
        exit 1
    fi
    
    source /etc/os-release
    echo "${ID:-unknown}"
}

# Install core dependencies
install_deps() {
    local os="$1"
    local deps=(bash curl git gpg jq tar sudo)
    
    log "Installing core dependencies: ${deps[*]}"
    
    case "$os" in
        debian|ubuntu)
            # Add lsb-release for better OS detection
            deps+=(lsb-release)
            sudo apt-get update -y
            sudo apt-get install -y "${deps[@]}"
            ;;
        fedora)
            # redhat-lsb-core provides lsb_release
            deps+=(redhat-lsb-core)
            sudo dnf install -y "${deps[@]}"
            ;;
        centos|rhel)
            deps+=(redhat-lsb-core)
            sudo yum install -y "${deps[@]}"
            ;;
        arch)
            deps+=(lsb-release)
            sudo pacman -Sy --noconfirm "${deps[@]}"
            ;;
        *)
            log_error "Unsupported OS: $os"
            log_error "Supported: Ubuntu/Debian (primary), Fedora/Arch (best-effort)"
            exit 1
            ;;
    esac
    
    log_success "Dependencies installed successfully"
}

# Set up JB launcher as a symlink for idempotence
setup_launcher() {
    local repo_dir="$1"
    local launcher_path="/usr/local/bin/jb"

    log "Setting up jb launcher at $launcher_path"

    # If a regular file exists, replace it with a symlink
    if [[ -e "$launcher_path" && ! -L "$launcher_path" ]]; then
        log_warn "Existing non-symlink at $launcher_path found; replacing with symlink"
        sudo rm -f "$launcher_path"
    fi

    # Create or update the symlink if needed
    if [[ -L "$launcher_path" ]]; then
        local target
        target="$(readlink -f "$launcher_path" 2>/dev/null || true)"
        if [[ "$target" == "$repo_dir/bin/jb" ]]; then
            log_success "Launcher already points to $target"
        else
            sudo ln -sf "$repo_dir/bin/jb" "$launcher_path"
            log_success "Updated launcher symlink to $repo_dir/bin/jb"
        fi
    else
        sudo ln -s "$repo_dir/bin/jb" "$launcher_path"
        log_success "Created launcher symlink -> $repo_dir/bin/jb"
    fi
}

# Set up environment (exports JB_DIR via /etc/profile.d/jb-dir.sh)
setup_environment() {
    local repo_dir="$1"
    
    log "Setting up environment variables"
    
    # Create profile.d script for system-wide JB_DIR
    sudo tee /etc/profile.d/jb-dir.sh > /dev/null << EOF
# JB-VPS Environment
export JB_DIR="$repo_dir"
EOF
    
    # Also add to current shell
    export JB_DIR="$repo_dir"
    
    log_success "Environment configured (/etc/profile.d/jb-dir.sh)"
}

# Create necessary directories for logs/state/config
setup_directories() {
    log "Creating system directories"
    
    # Create log directory
    sudo mkdir -p /var/log/jb-vps
    sudo chmod 755 /var/log/jb-vps
    
    # Create state directory
    sudo mkdir -p /var/lib/jb-vps
    sudo chmod 755 /var/lib/jb-vps
    # Ensure state file exists with sane perms (idempotent)
    if [[ ! -f /var/lib/jb-vps/jb-vps.state ]]; then
        sudo touch /var/lib/jb-vps/jb-vps.state
        sudo chmod 644 /var/lib/jb-vps/jb-vps.state || true
    fi
    
    # Create config directory in repo
    mkdir -p "$JB_DIR/config"
    
    log_success "System directories created"
}

# Main installation function
main() {
    log "Starting JB-VPS installation..."
    
    # Get current directory (should be the repo root)
    local repo_dir
    repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    
    # Verify we're in the right place
    if [[ ! -f "$repo_dir/bin/jb" ]]; then
        log_error "Installation must be run from the JB-VPS repository root"
        log_error "Expected to find bin/jb at $repo_dir/bin/jb"
        exit 1
    fi
    
    log "Installing from: $repo_dir"
    
    # Detect OS
    local os
    os="$(detect_os)"
    log "Detected OS: $os"
    
    # Check if we have sudo access
    if ! sudo -n true 2>/dev/null; then
        log_warn "This installer requires sudo access"
        log "You may be prompted for your password"
    fi
    
    # Install dependencies
    install_deps "$os"
    
    # Set up launcher
    setup_launcher "$repo_dir"
    
    # Set up environment
    setup_environment "$repo_dir"
    
    # Create directories
    setup_directories
    
    # Ensure bin/jb is executable
    chmod +x "$repo_dir/bin/jb"
    
    log_success "JB-VPS installation completed!"
    echo ""
    log "You can now run: ${GREEN}jb${NC}"
    log "Or start with the menu: ${GREEN}jb menu${NC}"
    echo ""
    log "If 'jb' is not found, try:"
    log "  source /etc/profile.d/jb-vps.sh"
    log "  or restart your shell"
}

# Run main function
main "$@"
