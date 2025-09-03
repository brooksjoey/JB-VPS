# Apps & Services

## What this area is for

This area helps you manage applications and services running on your VPS. You can install new software, control running services, and configure startup behavior.

## Common things you can do here

- View all installed applications and services
- Install new applications from package repositories
- Start, stop, or restart services
- Enable or disable services at boot time
- Check service status and logs
- Configure service settings

## What each menu choice will do

1. **List installed apps** - Shows all installed packages and running services
2. **Add a new app** - Guides you through installing new software packages
3. **Start/Stop/Restart an app** - Controls service states with systemctl
4. **Turn an app on/off at startup** - Manages systemd service enablement

## Where files will be created

- Service configurations: `/etc/systemd/system/`
- Application configs: `/etc/` (varies by application)
- Service logs: `/var/log/` or `/journalctl`
- Package cache: `/var/cache/apt/` or equivalent

## Logs and files

- Main log: `/var/log/jb-vps/apps.log`
- Service status: `systemctl status <service>`
- Service logs: `journalctl -u <service>`
- Package manager logs: `/var/log/apt/` (Debian/Ubuntu) or equivalent

Use `jb help apps` for command-line options or navigate through the menu for guided assistance.
