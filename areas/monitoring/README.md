# Monitoring & Health

## What this area is for

This area helps you monitor your VPS health, performance, and troubleshoot issues. You can check system resources, view logs, and monitor running services.

## Common things you can do here

- Check CPU, memory, and disk usage
- Monitor running processes and services
- View system logs and error messages
- Set up automated monitoring alerts
- Check network connectivity and ports
- Monitor system performance over time

## What each menu choice will do

1. **Show system status** - Displays current system information, uptime, and resource usage
2. **See what's using CPU and memory** - Shows top processes and resource consumption
3. **Check running services** - Lists all systemd services and their status
4. **View recent errors** - Shows recent error messages from system logs

## Where files will be created

- Monitoring configs: `/etc/jb-vps/monitoring/`
- Custom scripts: `/usr/local/bin/jb-monitoring/`
- Alert configurations: `/etc/jb-vps/alerts/`
- Performance data: `/var/lib/jb-vps/monitoring/`

## Logs and files

- System logs: `/var/log/syslog`, `/var/log/messages`
- Service logs: `journalctl -u <service>`
- JB-VPS monitoring log: `/var/log/jb-vps/monitoring.log`
- Performance history: `/var/lib/jb-vps/monitoring/history/`

## Quick health check

The system status option provides a comprehensive overview including:
- Hostname and OS information
- Uptime and load averages
- Memory and disk usage
- Network interface status
- Failed systemd services
- Recent critical log entries

Use `jb help monitoring` for command-line options or navigate through the menu for guided assistance.
