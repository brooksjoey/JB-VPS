# JB-VPS

**Functionality-First VPS Toolkit** — Transform any Linux VPS into a powerful, menu-driven server management system with one command.

## 🚀 Quickstart

```bash
git clone https://github.com/brooksjoey/JB-VPS.git
cd JB-VPS
./install.sh
jb
```

That's it! You'll land in a simple, friendly menu system that lets you control your entire VPS.

## 🎯 What You Get

**From every menu, you can:**
- See exactly what each action will do before running it
- Access help documentation with `0) What is this?`
- Preview changes with `P) Preview`
- Navigate with breadcrumbs showing where you are

**Core functionality areas:**
- **Apps & services** — Install, start/stop, and manage applications
- **Databases** — Set up PostgreSQL, MySQL, SQLite with users and backups
- **Websites & domains** — Host sites, configure domains, manage SSL
- **Files & backups** — Disk space, backup plans, restore operations
- **Users & access** — Add users, SSH keys, admin rights, security
- **Monitoring & health** — System status, resource usage, error logs
- **Developer tools** — Code workspaces, repo deployment, dev environments

## 🛠️ Command Line Interface

```bash
# Interactive menu (default)
jb

# Core commands
jb init                    # Full everyday setup on a fresh VPS
jb status                  # Show comprehensive system status
jb self:update            # Pull latest and re-link

# Environment management
jb env:list               # List encrypted environment profiles
jb env:open <name>        # Decrypt & load profile for current shell

# Web hosting
jb webhost:setup          # Install web server + host a simple site
jb dashboard:install      # Install the VPS dashboard

# Get help
jb help                   # Show all available commands
```

## 🏗️ Architecture

**Functionality-first design:**
- Plain English menus, not admin jargon
- Preview before every action
- Idempotent operations (safe to re-run)
- Automatic backups with rotation
- Comprehensive logging and state tracking

**Plugin system:**
- `plugins/core/` — System initialization, maintenance, security
- `plugins/env/` — Encrypted environment profile management
- `plugins/webhost/` — Web server setup and site hosting
- `plugins/dashboard/` — System monitoring dashboard

**Area-based organization:**
- `areas/*/` — Functional areas with menus, scripts, and documentation
- Each area has its own README explaining what it does
- Scripts are composable and can be called from menus or command line

## 🖥️ Supported Operating Systems

- **Ubuntu/Debian** — Primary support, fully tested
- **Fedora/Arch** — Best-effort support
- **CentOS/RHEL** — Basic support

The system automatically detects your OS and uses the appropriate package manager (`apt`, `dnf`, `pacman`, `yum`).

## 🔒 Security & Safety

**Built-in safety features:**
- Preview mode shows exactly what will happen
- Automatic file backups before changes
- Idempotent operations prevent duplicate configurations
- Comprehensive audit logging
- Encrypted environment profiles for sensitive data

**Optional security hardening:**
- Available as `jb harden` but never blocks normal workflows
- Configures firewall, fail2ban, SSH hardening
- Can be run at any time without disrupting services

## 📊 Monitoring & Dashboards

**System monitoring:**
- Real-time system status with `jb status`
- Resource usage tracking (CPU, memory, disk)
- Service health monitoring
- Error log analysis

**Web dashboard:**
- Install with `jb dashboard:install`
- Accessible at `http://your-server:8080`
- Auto-updating system information
- Clean, responsive interface

## 🔧 Development & Customization

**Easy to extend:**
- Add new plugins in `plugins/your-plugin/plugin.sh`
- Create area-specific scripts in `areas/*/scripts/`
- Use the command registry: `jb_register "cmd" function "description" "category"`

**Configuration management:**
- Settings in `config/jb-vps.conf`
- State tracking in `.state/jb-vps.state`
- Logs in `/var/log/jb-vps/`

## 📁 Directory Structure

```
JB-VPS/
├── install.sh              # One-shot installer
├── bin/jb                   # Main launcher
├── bin/menu.sh             # Interactive menu system
├── lib/base.sh             # Core functionality library
├── plugins/                # Plugin system
│   ├── core/               # System management
│   ├── env/                # Environment profiles
│   ├── webhost/            # Web hosting
│   └── dashboard/          # Monitoring dashboard
├── areas/                  # Functional areas
│   ├── apps/               # Application management
│   ├── web/                # Website hosting
│   ├── monitoring/         # System monitoring
│   └── */                  # Other areas
└── scripts/                # Implementation scripts
```

## 🤝 Contributing

This project follows a **functionality-first philosophy**:

1. **Plain language** — Menus and messages use everyday terms
2. **Preview everything** — Users see what will happen before it happens
3. **Safe by default** — Operations are idempotent and create backups
4. **Comprehensive help** — Every area has clear documentation

When adding features:
- Use the existing plugin and area structure
- Follow the menu conventions (0/P/B/Q options)
- Add appropriate README files
- Test on multiple OS distributions

## 📄 License

This project is open source. See the repository for license details.

---

**Need help?** Run `jb menu` and press `0` in any area for context-specific documentation.
