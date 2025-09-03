# Databases

## What this area is for

Manage databases on your VPS in a simple, predictable way.

## Common things you can do here

- Install a database server (PostgreSQL, MySQL/MariaDB, or SQLite tools)
- Create a database and user with sensible defaults
- Back up a database with timestamped filenames
- Restore a backup safely and predictably

## What each menu choice means

- Install a database (PostgreSQL/MySQL/SQLite): Installs packages and enables the service.
- Create a database and user: Creates credentials and a database idempotently.
- Back up a database: Produces a compressed backup with rotation.
- Restore a backup: Restores from a selected backup file.

## Where files will be created

- Backups: typically under `/var/lib/jb-vps/backups/databases/`
- Logs: `/var/log/jb-vps/`
- Configuration: managed via the system packages and JB-VPS helpers.

All actions are previewable and idempotent.

