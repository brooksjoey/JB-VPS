# JB-VPS User Guide

Welcome to JB-VPS v2.0 - Enterprise Linux VPS Automation Platform

## Table of Contents

1. [Quick Start](#quick-start)
2. [Installation](#installation)
3. [Basic Usage](#basic-usage)
4. [Core Features](#core-features)
5. [Red Team Operations](#red-team-operations)
6. [System Management](#system-management)
7. [Configuration](#configuration)
8. [Troubleshooting](#troubleshooting)

## Quick Start

### First Time Setup

1. **Clone the repository:**
   ```bash
   git clone https://github.com/brooksjoey/JB-VPS
   cd JB-VPS
   ```

2. **Run the bootstrap script:**
   ```bash
   sudo ./scripts/bootstrap/vps-bootstrap.sh
   ```

3. **Verify installation:**
   ```bash
   jb status
   ```

4. **Explore available commands:**
   ```bash
   jb help
   ```

### Daily Usage

- **Check system status:** `jb status`
- **Run maintenance:** `jb maintenance`
- **Access Red Team tools:** `jb redteam`
- **View system information:** `jb info`

## Installation

### Prerequisites

- Linux VPS (Ubuntu 20.04+, Debian 11+, CentOS 8+, Fedora 35+)
- Root or sudo access
- Internet connection
- At least 2GB RAM and 10GB disk space

### Automated Installation

The bootstrap script handles everything automatically:

```bash
# Download and run bootstrap
curl -fsSL https://raw.githubusercontent.com/brooksjoey/JB-VPS/main/scripts/bootstrap/vps-bootstrap.sh | sudo bash
```

### Manual Installation

1. **Clone repository:**
   ```bash
   git clone https://github.com/brooksjoey/JB-VPS /opt/jb-vps
   cd /opt/jb-vps
   ```

2. **Set permissions:**
   ```bash
   sudo chown -R $USER:$USER /opt/jb-vps
   chmod +x bin/jb
   chmod +x scripts/bootstrap/vps-bootstrap.sh
   ```

3. **Run bootstrap:**
   ```bash
   sudo ./scripts/bootstrap/vps-bootstrap.sh
   ```

4. **Add to PATH:**
   ```bash
   echo 'export PATH="$PATH:/opt/jb-vps/bin"' >> ~/.bashrc
   source ~/.bashrc
   ```

## Basic Usage

### Command Structure

```bash
jb <command> [options] [arguments]
```

### Essential Commands

| Command | Description | Example |
|---------|-------------|---------|
| `jb help` | Show all available commands | `jb help` |
| `jb status` | Display system status | `jb status` |
| `jb info` | Show detailed system information | `jb info` |
| `jb bootstrap` | Initialize/reinstall system | `jb bootstrap --force` |
| `jb maintenance` | Run system maintenance | `jb maintenance` |
| `jb config` | Manage configuration | `jb config show` |

### Getting Help

- **General help:** `jb help`
- **Category help:** `jb help core`
- **Command help:** `jb <command> --help`
- **Documentation:** Browse `/docs/` directory

## Core Features

### System Management

#### Bootstrap & Initialization
- **Purpose:** Set up a fresh VPS with security hardening and essential tools
- **Usage:** `jb bootstrap`
- **Features:**
  - System updates and package installation
  - Security hardening (SSH, firewall, fail2ban)
  - User account setup
  - Service configuration
  - Directory structure creation

#### Status Monitoring
- **Purpose:** Check system health and service status
- **Usage:** `jb status`
- **Information Displayed:**
  - System information (OS, kernel, uptime)
  - Resource usage (CPU, memory, disk)
  - Service status (JB-VPS services, security tools)
  - Bootstrap completion status

#### Maintenance Tasks
- **Purpose:** Perform routine system maintenance
- **Usage:** `jb maintenance`
- **Tasks Performed:**
  - Package cache cleanup
  - Log rotation
  - Temporary file cleanup
  - Database updates
  - Backup cleanup

### Security Features

#### Automated Hardening
- SSH configuration hardening
- Firewall setup (UFW/firewalld)
- Fail2ban configuration
- User permission management
- Security monitoring

#### Audit Logging
- All privileged operations logged
- User action tracking
- Security event monitoring
- Compliance reporting

### Backup System

#### Automated Backups
- **Create backup:** `jb backup create /path/to/data`
- **List backups:** `jb backup list`
- **Restore backup:** `jb backup restore <backup-id>`
- **Features:**
  - Compression and encryption
  - Retention policies
  - Remote synchronization
  - Integrity verification

## Red Team Operations

### Overview

JB-VPS includes a comprehensive Red Team operations center with user-friendly menus and proper authorization controls.

### Accessing Red Team Tools

```bash
jb redteam
# or
jb rt
```

### Main Categories

1. **Intelligence Gathering**
   - Domain and website analysis
   - Employee discovery
   - Social media intelligence
   - Technical infrastructure scanning

2. **Campaign Infrastructure**
   - Domain registration and setup
   - SSL certificate management
   - Email server configuration
   - Phishing website deployment

3. **Social Engineering**
   - Email template generation
   - Phone script creation
   - SMS/text message templates
   - Persona development

4. **Web-based Attacks**
   - Phishing page creation
   - Malicious link generation
   - Document weaponization
   - Web cloning tools

5. **Campaign Management**
   - Campaign creation and tracking
   - Statistics and reporting
   - Archive management

6. **Security & Cleanup**
   - Authorization management
   - Campaign cleanup
   - Secure data deletion
   - Audit trail review

### Authorization Requirements

⚠️ **IMPORTANT:** All Red Team operations require proper authorization:

- Written permission from target organization
- Signed authorization letters
- Clear scope of work
- Emergency contact procedures

The system will prompt for authorization before allowing any operations.

### Best Practices

1. **Always obtain written authorization** before starting any engagement
2. **Document everything** - maintain detailed logs and reports
3. **Follow legal guidelines** - understand local laws and regulations
4. **Practice operational security** - protect sensitive data and methods
5. **Clean up after engagements** - remove all infrastructure and data

## System Management

### Configuration Management

#### View Configuration
```bash
jb config show
```

#### Set Configuration Values
```bash
jb config set JB_LOG_LEVEL DEBUG
jb config set JB_BACKUP_RETENTION_DAYS 60
```

#### Configuration Files
- Main config: `/opt/jb-vps/config/jb-vps.conf`
- Environment configs: `/opt/jb-vps/secure/environments/`
- User configs: `~/.jb-vps/config`

### Service Management

#### System Services
- **Maintenance Timer:** Runs daily maintenance tasks
- **System Monitor:** Monitors system health (optional)

#### Service Commands
```bash
# Check service status
systemctl status jb-vps-maintenance.timer

# Start/stop services
sudo systemctl start jb-vps-monitor.service
sudo systemctl stop jb-vps-monitor.service

# View service logs
journalctl -u jb-vps-maintenance.service
```

### Log Management

#### Log Locations
- System logs: `/var/log/jb-vps/`
- Audit logs: `/var/log/jb-vps/audit.log`
- Error logs: `/var/log/jb-vps/error.log`
- Bootstrap logs: `/var/log/jb-vps-bootstrap.log`

#### Log Commands
```bash
# View recent logs
jb logs

# View specific log types
jb logs --type audit
jb logs --type error

# Follow logs in real-time
jb logs --follow
```

## Configuration

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `JB_DIR` | Installation directory | `/opt/jb-vps` |
| `JB_LOG_LEVEL` | Logging level | `INFO` |
| `JB_DEBUG` | Enable debug mode | `false` |
| `JB_BACKUP_DIR` | Backup directory | `/var/backups/jb-vps` |
| `JB_VALIDATION_STRICT` | Strict validation mode | `true` |

### Configuration File Format

```bash
# JB-VPS Configuration File
JB_VERSION=2.0.0
JB_DEBUG=false
JB_LOG_LEVEL=INFO
JB_BACKUP_RETENTION_DAYS=30
JB_REDTEAM_ENABLED=true
```

### Customization

#### Adding Custom Commands
1. Create plugin in `plugins/custom/`
2. Register commands using `jb_register`
3. Restart JB-VPS or reload plugins

#### Custom Templates
- Add templates to `templates/` directory
- Use in scripts and automation
- Version control with git

## Troubleshooting

### Common Issues

#### Command Not Found
```bash
# Check if JB-VPS is in PATH
echo $PATH | grep jb-vps

# Add to PATH if missing
export PATH="$PATH:/opt/jb-vps/bin"
```

#### Permission Denied
```bash
# Check file permissions
ls -la /opt/jb-vps/bin/jb

# Fix permissions
sudo chmod +x /opt/jb-vps/bin/jb
sudo chown -R jb-vps:jb-vps /opt/jb-vps
```

#### Bootstrap Fails
```bash
# Check bootstrap status
jb bootstrap --status

# View bootstrap logs
sudo tail -f /var/log/jb-vps-bootstrap.log

# Force re-run bootstrap
sudo jb bootstrap --force
```

#### Service Issues
```bash
# Check service status
systemctl status jb-vps-maintenance.timer

# Restart services
sudo systemctl restart jb-vps-maintenance.timer

# Check service logs
journalctl -u jb-vps-maintenance.service -f
```

### Debug Mode

Enable debug mode for detailed logging:

```bash
# Temporary debug mode
JB_DEBUG=true jb status

# Permanent debug mode
jb config set JB_DEBUG true
```

### Getting Support

1. **Check logs:** Review system and error logs
2. **Search documentation:** Browse `/docs/` directory
3. **Check GitHub issues:** Visit repository issues page
4. **Create issue:** Report bugs with detailed information

### Log Analysis

#### Common Log Patterns
```bash
# Find errors in logs
grep ERROR /var/log/jb-vps/jb-vps.log

# Check audit trail
grep AUDIT /var/log/jb-vps/audit.log

# Monitor real-time activity
tail -f /var/log/jb-vps/jb-vps.log
```

#### Performance Issues
```bash
# Check system resources
jb status

# Monitor system load
jb monitor

# Review performance logs
grep PERF /var/log/jb-vps/jb-vps.log
```

---

## Next Steps

- Read the [Administrator Guide](../admin-guide/README.md) for advanced configuration
- Explore the [API Reference](../api-reference/README.md) for automation
- Check out example workflows in the `examples/` directory
- Join the community discussions on GitHub

For more detailed information, see the complete documentation in the `/docs/` directory.
