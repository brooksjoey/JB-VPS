# Users & access

## What this area is for

Manage user accounts and access to your VPS without manual sysadmin commands.

## Common things you can do here

- Add a new user with a home directory
- Grant or revoke admin (sudo) rights
- Set up SSH keys for passwordless login
- Toggle password authentication for SSH

## What each menu choice means

- Add a user: Creates a standard user account idempotently.
- Give or remove admin rights: Adds/removes the user from the sudo/admin group.
- Set up SSH keys: Installs provided public keys and permissions.
- Turn password login on/off: Updates SSH configuration safely with a backup.

## Where files will be created

- User homes: `/home/<user>`
- SSH keys: `/home/<user>/.ssh/authorized_keys`
- Logs: `/var/log/jb-vps/`
- State: `/var/lib/jb-vps/`

All actions are previewable and idempotent.

