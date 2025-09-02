#!/usr/bin/env bash
# SSH Menu Integration Setup Script
# Sets up SSH access and integrates the JB-VPS menu system

set -euo pipefail

# Get the JB-VPS directory
JB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$JB_DIR/lib/base.sh"

# Configuration
SSH_CONFIG_DIR="/etc/ssh"
SSHD_CONFIG="$SSH_CONFIG_DIR/sshd_config"
BASHRC_SNIPPET="$JB_DIR/scripts/bashrc-integration.sh"
PROFILE_SNIPPET="$JB_DIR/scripts/profile-integration.sh"

# Colors for output
C_GREEN='\033[1;32m'
C_BLUE='\033[1;34m'
C_YELLOW='\033[1;33m'
C_RED='\033[1;31m'
C_RESET='\033[0m'

# Main setup function
setup_ssh_menu_integration() {
    log_info "Setting up SSH access and menu integration" "SSH_SETUP"
    
    echo -e "${C_BLUE}🔧 JB-VPS SSH & Menu Integration Setup${C_RESET}"
    echo "======================================"
    echo ""
    
    # Check if running as root or with sudo
    if [[ $EUID -ne 0 ]]; then
        echo -e "${C_RED}This script must be run as root or with sudo${C_RESET}"
        exit 1
    fi
    
    # Step 1: Configure SSH for security
    echo -e "${C_YELLOW}Step 1: Configuring SSH for security...${C_RESET}"
    configure_ssh_security
    
    # Step 2: Set up SSH key authentication
    echo -e "${C_YELLOW}Step 2: Setting up SSH key authentication...${C_RESET}"
    setup_ssh_keys
    
    # Step 3: Create menu integration scripts
    echo -e "${C_YELLOW}Step 3: Creating menu integration scripts...${C_RESET}"
    create_integration_scripts
    
    # Step 4: Set up user profiles
    echo -e "${C_YELLOW}Step 4: Setting up user profiles...${C_RESET}"
    setup_user_profiles
    
    # Step 5: Create JB-VPS command alias
    echo -e "${C_YELLOW}Step 5: Creating JB-VPS command alias...${C_RESET}"
    setup_jb_alias
    
    # Step 6: Test the setup
    echo -e "${C_YELLOW}Step 6: Testing the setup...${C_RESET}"
    test_setup
    
    echo ""
    echo -e "${C_GREEN}✅ SSH and menu integration setup completed!${C_RESET}"
    echo ""
    echo -e "${C_BLUE}Next steps:${C_RESET}"
    echo "1. Add your SSH public key to ~/.ssh/authorized_keys"
    echo "2. Test SSH connection: ssh username@your-server-ip"
    echo "3. Once connected, type 'JB-VPS' to access the menu"
    echo "4. Or use 'jb menu' for the interactive interface"
    echo ""
}

# Configure SSH for security
configure_ssh_security() {
    log_info "Configuring SSH security settings" "SSH_SETUP"
    
    # Backup original sshd_config
    if [[ ! -f "${SSHD_CONFIG}.backup" ]]; then
        cp "$SSHD_CONFIG" "${SSHD_CONFIG}.backup"
        echo "✅ Backed up original SSH configuration"
    fi
    
    # Apply security configurations
    local ssh_security_config="$JB_DIR/profiles/debian-bookworm/sshd_config"
    
    if [[ -f "$ssh_security_config" ]]; then
        # Use the existing security configuration
        cp "$ssh_security_config" "$SSHD_CONFIG"
        echo "✅ Applied security SSH configuration"
    else
        # Create a secure SSH configuration
        cat > "$SSHD_CONFIG" << 'EOF'
# JB-VPS Secure SSH Configuration
Port 22
Protocol 2

# Authentication
PermitRootLogin no
PasswordAuthentication yes
PubkeyAuthentication yes
AuthorizedKeysFile .ssh/authorized_keys
PermitEmptyPasswords no
ChallengeResponseAuthentication no
UsePAM yes

# Security settings
X11Forwarding no
PrintMotd no
AcceptEnv LANG LC_*
Subsystem sftp /usr/lib/openssh/sftp-server

# Connection settings
ClientAliveInterval 300
ClientAliveCountMax 2
MaxAuthTries 3
MaxSessions 10

# Logging
SyslogFacility AUTH
LogLevel INFO
EOF
        echo "✅ Created secure SSH configuration"
    fi
    
    # Restart SSH service
    systemctl restart sshd
    echo "✅ Restarted SSH service"
    
    log_audit "SSH_CONFIG" "security" "SUCCESS" "applied_secure_config=true"
}

# Set up SSH key authentication
setup_ssh_keys() {
    log_info "Setting up SSH key authentication" "SSH_SETUP"
    
    # Get the current user (the one who ran sudo)
    local target_user="${SUDO_USER:-$USER}"
    local user_home
    user_home=$(getent passwd "$target_user" | cut -d: -f6)
    
    if [[ -z "$user_home" ]] || [[ ! -d "$user_home" ]]; then
        echo "⚠️  Could not determine user home directory"
        return 1
    fi
    
    local ssh_dir="$user_home/.ssh"
    
    # Create .ssh directory if it doesn't exist
    if [[ ! -d "$ssh_dir" ]]; then
        mkdir -p "$ssh_dir"
        chown "$target_user:$target_user" "$ssh_dir"
        chmod 700 "$ssh_dir"
        echo "✅ Created .ssh directory for $target_user"
    fi
    
    # Create authorized_keys file if it doesn't exist
    local auth_keys="$ssh_dir/authorized_keys"
    if [[ ! -f "$auth_keys" ]]; then
        touch "$auth_keys"
        chown "$target_user:$target_user" "$auth_keys"
        chmod 600 "$auth_keys"
        echo "✅ Created authorized_keys file"
    fi
    
    # Generate SSH key pair if none exists
    local private_key="$ssh_dir/id_rsa"
    if [[ ! -f "$private_key" ]]; then
        echo "Generating SSH key pair for $target_user..."
        sudo -u "$target_user" ssh-keygen -t rsa -b 4096 -f "$private_key" -N "" -C "$target_user@$(hostname)"
        echo "✅ Generated SSH key pair"
        
        # Add public key to authorized_keys
        cat "${private_key}.pub" >> "$auth_keys"
        echo "✅ Added public key to authorized_keys"
    fi
    
    echo "📋 SSH key information:"
    echo "  Private key: $private_key"
    echo "  Public key: ${private_key}.pub"
    echo "  Authorized keys: $auth_keys"
    
    log_audit "SSH_KEYS" "$target_user" "SUCCESS" "generated_keys=true"
}

# Create integration scripts
create_integration_scripts() {
    log_info "Creating menu integration scripts" "SSH_SETUP"
    
    # Create bashrc integration script
    cat > "$BASHRC_SNIPPET" << 'EOF'
#!/usr/bin/env bash
# JB-VPS Bashrc Integration
# Automatically sourced when user logs in via SSH

# JB-VPS environment setup
export JB_DIR="/workspaces/JB-VPS"
export PATH="$JB_DIR/bin:$PATH"

# JB-VPS aliases
alias jb="$JB_DIR/bin/jb"
alias JB-VPS="$JB_DIR/bin/jb menu"
alias vps-menu="$JB_DIR/bin/jb menu"
alias vps-status="$JB_DIR/bin/jb status"
alias vps-info="$JB_DIR/bin/jb info"

# Welcome message function
jb_welcome() {
    if [[ -t 1 ]] && [[ "${JB_WELCOME_SHOWN:-}" != "true" ]]; then
        export JB_WELCOME_SHOWN=true
        
        echo ""
        echo "🖥️  Welcome to JB-VPS!"
        echo "====================="
        echo ""
        echo "Quick commands:"
        echo "  JB-VPS     - Open interactive menu"
        echo "  jb status  - System status"
        echo "  jb help    - Show all commands"
        echo ""
        echo "Type 'JB-VPS' to get started!"
        echo ""
    fi
}

# Show welcome message on login
if [[ -n "${SSH_CONNECTION:-}" ]] || [[ -n "${SSH_CLIENT:-}" ]]; then
    jb_welcome
fi
EOF
    
    chmod +x "$BASHRC_SNIPPET"
    echo "✅ Created bashrc integration script"
    
    # Create profile integration script
    cat > "$PROFILE_SNIPPET" << 'EOF'
#!/usr/bin/env bash
# JB-VPS Profile Integration
# Sets up environment for JB-VPS

# Source JB-VPS bashrc integration if it exists
if [[ -f "/workspaces/JB-VPS/scripts/bashrc-integration.sh" ]]; then
    source "/workspaces/JB-VPS/scripts/bashrc-integration.sh"
fi
EOF
    
    chmod +x "$PROFILE_SNIPPET"
    echo "✅ Created profile integration script"
    
    log_audit "INTEGRATION_SCRIPTS" "created" "SUCCESS" "bashrc=true,profile=true"
}

# Set up user profiles
setup_user_profiles() {
    log_info "Setting up user profiles" "SSH_SETUP"
    
    local target_user="${SUDO_USER:-$USER}"
    local user_home
    user_home=$(getent passwd "$target_user" | cut -d: -f6)
    
    # Add to user's .bashrc
    local bashrc="$user_home/.bashrc"
    local integration_line="source $BASHRC_SNIPPET"
    
    if [[ -f "$bashrc" ]] && ! grep -q "$integration_line" "$bashrc"; then
        echo "" >> "$bashrc"
        echo "# JB-VPS Integration" >> "$bashrc"
        echo "$integration_line" >> "$bashrc"
        echo "✅ Added JB-VPS integration to .bashrc"
    fi
    
    # Add to user's .profile
    local profile="$user_home/.profile"
    local profile_integration_line="source $PROFILE_SNIPPET"
    
    if [[ -f "$profile" ]] && ! grep -q "$profile_integration_line" "$profile"; then
        echo "" >> "$profile"
        echo "# JB-VPS Profile Integration" >> "$profile"
        echo "$profile_integration_line" >> "$profile"
        echo "✅ Added JB-VPS integration to .profile"
    fi
    
    # Set up global profile integration
    local global_profile="/etc/profile.d/jb-vps.sh"
    cat > "$global_profile" << EOF
#!/usr/bin/env bash
# JB-VPS Global Profile Integration

# Only run for interactive shells
if [[ \$- == *i* ]]; then
    # Source JB-VPS profile integration if it exists
    if [[ -f "$PROFILE_SNIPPET" ]]; then
        source "$PROFILE_SNIPPET"
    fi
fi
EOF
    
    chmod +x "$global_profile"
    echo "✅ Created global profile integration"
    
    log_audit "USER_PROFILES" "$target_user" "SUCCESS" "bashrc=true,profile=true,global=true"
}

# Set up JB-VPS command alias
setup_jb_alias() {
    log_info "Setting up JB-VPS command alias" "SSH_SETUP"
    
    # Create a global command for JB-VPS
    local jb_command="/usr/local/bin/JB-VPS"
    
    cat > "$jb_command" << EOF
#!/usr/bin/env bash
# JB-VPS Global Command
# Provides easy access to JB-VPS menu system

export JB_DIR="$JB_DIR"
exec "\$JB_DIR/bin/jb" menu "\$@"
EOF
    
    chmod +x "$jb_command"
    echo "✅ Created global JB-VPS command"
    
    # Create additional aliases
    local aliases=(
        "vps-menu:$JB_DIR/bin/jb menu"
        "vps-status:$JB_DIR/bin/jb status"
        "vps-info:$JB_DIR/bin/jb info"
        "vps-help:$JB_DIR/bin/jb help"
    )
    
    for alias_def in "${aliases[@]}"; do
        local alias_name="${alias_def%%:*}"
        local alias_command="${alias_def#*:}"
        local alias_file="/usr/local/bin/$alias_name"
        
        cat > "$alias_file" << EOF
#!/usr/bin/env bash
# JB-VPS Alias: $alias_name
export JB_DIR="$JB_DIR"
exec $alias_command "\$@"
EOF
        chmod +x "$alias_file"
    done
    
    echo "✅ Created VPS command aliases"
    
    log_audit "COMMAND_ALIASES" "global" "SUCCESS" "jb_vps=true,aliases=true"
}

# Test the setup
test_setup() {
    log_info "Testing SSH and menu setup" "SSH_SETUP"
    
    local errors=0
    
    # Test SSH configuration
    if sshd -t; then
        echo "✅ SSH configuration is valid"
    else
        echo "❌ SSH configuration has errors"
        ((errors++))
    fi
    
    # Test JB-VPS command
    if command -v JB-VPS >/dev/null 2>&1; then
        echo "✅ JB-VPS command is available"
    else
        echo "❌ JB-VPS command not found"
        ((errors++))
    fi
    
    # Test jb command
    if command -v jb >/dev/null 2>&1; then
        echo "✅ jb command is available"
    else
        echo "❌ jb command not found"
        ((errors++))
    fi
    
    # Test integration scripts
    if [[ -f "$BASHRC_SNIPPET" ]] && [[ -x "$BASHRC_SNIPPET" ]]; then
        echo "✅ Bashrc integration script is ready"
    else
        echo "❌ Bashrc integration script missing or not executable"
        ((errors++))
    fi
    
    # Test AI system
    if [[ -d "$JB_DIR/plugins/ai" ]]; then
        echo "✅ AI system is available"
    else
        echo "❌ AI system not found"
        ((errors++))
    fi
    
    # Test menu system
    if [[ -f "$JB_DIR/plugins/menu/plugin.sh" ]]; then
        echo "✅ Menu system is available"
    else
        echo "❌ Menu system not found"
        ((errors++))
    fi
    
    if [[ $errors -eq 0 ]]; then
        echo "✅ All tests passed!"
        log_audit "SETUP_TEST" "all" "SUCCESS" "errors=0"
    else
        echo "⚠️  $errors test(s) failed"
        log_audit "SETUP_TEST" "all" "PARTIAL" "errors=$errors"
    fi
}

# Show usage information
show_usage() {
    echo "JB-VPS SSH & Menu Integration Setup"
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  --help, -h     Show this help message"
    echo "  --test         Run tests only"
    echo "  --ssh-only     Configure SSH only"
    echo "  --menu-only    Configure menu integration only"
    echo ""
    echo "This script sets up:"
    echo "  • Secure SSH configuration"
    echo "  • SSH key authentication"
    echo "  • Menu system integration"
    echo "  • User profile configuration"
    echo "  • Global command aliases"
}

# Main execution
main() {
    case "${1:-}" in
        "--help"|"-h")
            show_usage
            exit 0
            ;;
        "--test")
            test_setup
            exit 0
            ;;
        "--ssh-only")
            configure_ssh_security
            setup_ssh_keys
            exit 0
            ;;
        "--menu-only")
            create_integration_scripts
            setup_user_profiles
            setup_jb_alias
            exit 0
            ;;
        "")
            setup_ssh_menu_integration
            ;;
        *)
            echo "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
}

# Run main function
main "$@"
