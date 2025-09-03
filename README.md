JB-VPS

Functionality-First VPS Toolkit — Transform any Linux VPS into a powerful, menu-driven server management system with one command.

⸻

🚀 Quickstart

git clone https://github.com/brooksjoey/JB-VPS.git
cd JB-VPS
./install.sh
jb

Then run jb to launch the interactive menu.

⸻

🎯 Features

Core functionality areas (all with breadcrumbs, previews, and "What is this?" docs):
 • Apps & Services — Install, start, stop, and manage applications
 • Databases — PostgreSQL, MySQL, SQLite, with users and backups
 • Websites & Domains — Host sites, configure domains, manage SSL
 • Files & Backups — Disk usage, backup plans, restore operations
 • Users & Access — Add users, SSH keys, admin rights, security settings
 • Monitoring & Health — System status, resource usage, logs, errors
 • Developer Tools — Repo deployment, code workspaces, environments

From every menu you can:
 • Preview exactly what each action will do before running it
 • Access help documentation instantly
 • Navigate easily with breadcrumbs

⸻

🛠️ Command Line

Interactive menu (default):

jb

Core commands:

jb init          # Fresh VPS setup  
jb status        # Full system status  
jb self:update   # Update toolkit  

Environment management:

jb env:list  
jb env:open <name>  

Web hosting & dashboards:

jb webhost:setup  
jb dashboard:install  

Help:

jb help


⸻

🏗️ Architecture

Functionality-first design
 • Plain English menus, not admin jargon
 • Preview before every action
 • Idempotent operations (safe to re-run)
 • Automatic backups with rotation
 • Comprehensive logging and state tracking

Plugin-based system
 • Each feature is a plugin script under /plugins
 • Easy to add/remove features
 • Consistent CLI: jb <plugin>:<action>

State-aware execution
 • Tracks what's installed and configured
 • Skips redundant steps automatically
 • Re-runnable setup scripts without breakage

⸻

⚡️ JB-VPS is designed to be the friendliest way to manage your VPS.
