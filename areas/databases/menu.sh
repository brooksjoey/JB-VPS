#!/usr/bin/env bash
# Area menu: Databases (scaffold)
set -euo pipefail

JB_DIR="${JB_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
# shellcheck disable=SC1091
source "$JB_DIR/lib/base.sh"

db_breadcrumb() {
  echo "You are here: Home ▸ Databases"
}

db_show_readme() {
  local readme="$JB_DIR/areas/databases/README.md"
  if [[ -f "$readme" ]]; then
    if command -v less >/dev/null 2>&1; then
      less "$readme"
    else
      cat "$readme"
    fi
  else
    echo "README not found for Databases area: $readme"
  fi
}

# Action handlers used by bin/menu.sh -> run_area_script
menu_databases_install() {
  with_preview "Install a database (PostgreSQL/MySQL/SQLite)" echo "Not yet implemented"
}

# Database creation and user management
menu_databases_create() {
  local db_type db_name db_user db_password db_host db_port
  local preview_only=false rollback_enabled=true
  local state_dir="/var/lib/jb-vps/databases"
  
  # Create state directory if it doesn't exist
  if [[ ! -d "$state_dir" ]]; then
    sudo mkdir -p "$state_dir"
    sudo chown "$(whoami):$(whoami)" "$state_dir"
  fi

  # Select database type
  echo "Select database type:"
  echo "1) PostgreSQL"
  echo "2) MySQL"
  read -rp "Choice [1-2]: " db_choice
  
  case "$db_choice" in
    1) db_type="postgresql" ;;
    2) db_type="mysql" ;;
    *) echo "Invalid choice. Exiting."; return 1 ;;
  esac
  
  # Get database details
  read -rp "Database name: " db_name
  read -rp "Database user: " db_user
  read -rp "Database password: " db_password
  read -rp "Host [localhost]: " db_host
  db_host="${db_host:-localhost}"
  
  # Set default ports
  if [[ "$db_type" == "postgresql" ]]; then
    db_port=5432
  else
    db_port=3306
  fi
  read -rp "Port [$db_port]: " port_input
  db_port="${port_input:-$db_port}"
  
  # Create state file path
  local state_file="$state_dir/${db_type}_${db_name}.state"
  
  # Check for idempotence
  if [[ -f "$state_file" ]]; then
    echo "Database $db_name already exists according to state file."
    read -rp "Do you want to proceed anyway? [y/N]: " proceed
    if [[ ! "$proceed" =~ ^[Yy]$ ]]; then
      echo "Operation cancelled."
      return 0
    fi
  fi
  
  # Define database creation command
  if [[ "$db_type" == "postgresql" ]]; then
    create_db_cmd="create_postgresql_db"
  else
    create_db_cmd="create_mysql_db"
  fi
  
  # Execute with preview
  with_preview "Create $db_type database $db_name with user $db_user" \
    $create_db_cmd "$db_name" "$db_user" "$db_password" "$db_host" "$db_port" "$state_file"
  
  return $?
}

# Create PostgreSQL database and user
create_postgresql_db() {
  local db_name="$1" db_user="$2" db_password="$3" db_host="$4" db_port="$5" state_file="$6"
  local pg_exists pg_user_exists pg_success=false
  
  # Check if PostgreSQL is installed
  if ! command -v psql &> /dev/null; then
    echo "PostgreSQL is not installed. Please install it first."
    return 1
  fi
  
  # Check if database already exists
  pg_exists=$(sudo -u postgres psql -tAc "SELECT 1 FROM pg_database WHERE datname='$db_name'")
  if [[ "$pg_exists" == "1" ]]; then
    echo "Database $db_name already exists in PostgreSQL."
    pg_user_exists=$(sudo -u postgres psql -tAc "SELECT 1 FROM pg_roles WHERE rolname='$db_user'")
    if [[ "$pg_user_exists" == "1" ]]; then
      echo "User $db_user already exists in PostgreSQL."
      # Optionally update permissions if user exists
      read -rp "Reset user permissions? [y/N]: " reset_perms
      if [[ "$reset_perms" =~ ^[Yy]$ ]]; then
        sudo -u postgres psql -c "ALTER USER $db_user WITH PASSWORD '$db_password';"
        sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE $db_name TO $db_user;"
        echo "Updated permissions for user $db_user on database $db_name."
      fi
      return 0
    fi
  fi
  
  # Create database and user
  echo "Creating PostgreSQL database $db_name and user $db_user..."
  
  # Function to roll back changes in case of failure
  rollback_pg() {
    echo "Rolling back changes..."
    sudo -u postgres psql -c "DROP DATABASE IF EXISTS $db_name;" || true
    sudo -u postgres psql -c "DROP USER IF EXISTS $db_user;" || true
    echo "Rollback completed."
  }
  
  # Enable trap for rollback
  trap rollback_pg ERR
  
  # Execute commands
  sudo -u postgres psql -c "CREATE USER $db_user WITH PASSWORD '$db_password';"
  sudo -u postgres psql -c "CREATE DATABASE $db_name;"
  sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE $db_name TO $db_user;"
  
  # Create HBA entry if needed for non-localhost
  if [[ "$db_host" != "localhost" && "$db_host" != "127.0.0.1" ]]; then
    local pg_hba_path=$(sudo -u postgres psql -tAc "SHOW hba_file;")
    sudo cp "$pg_hba_path" "${pg_hba_path}.bak.$(date +%s)"
    echo "host    $db_name    $db_user    $db_host/32    md5" | sudo tee -a "$pg_hba_path" > /dev/null
    sudo systemctl reload postgresql
  fi
  
  # Save state to file
  echo "timestamp: $(date +%s)" > "$state_file"
  echo "type: postgresql" >> "$state_file"
  echo "database: $db_name" >> "$state_file"
  echo "user: $db_user" >> "$state_file"
  echo "host: $db_host" >> "$state_file"
  echo "port: $db_port" >> "$state_file"
  
  # Disable trap
  trap - ERR
  
  echo "PostgreSQL database $db_name and user $db_user created successfully."
  return 0
}

# Create MySQL database and user
create_mysql_db() {
  local db_name="$1" db_user="$2" db_password="$3" db_host="$4" db_port="$5" state_file="$6"
  local mysql_success=false
  
  # Check if MySQL is installed
  if ! command -v mysql &> /dev/null; then
    echo "MySQL is not installed. Please install it first."
    return 1
  fi
  
  # Check if database already exists
  local db_exists=$(mysql -sN -e "SELECT COUNT(*) FROM information_schema.schemata WHERE schema_name='$db_name';")
  if [[ "$db_exists" -gt 0 ]]; then
    echo "Database $db_name already exists in MySQL."
    local user_exists=$(mysql -sN -e "SELECT COUNT(*) FROM mysql.user WHERE user='$db_user';")
    if [[ "$user_exists" -gt 0 ]]; then
      echo "User $db_user already exists in MySQL."
      # Optionally update permissions if user exists
      read -rp "Reset user permissions? [y/N]: " reset_perms
      if [[ "$reset_perms" =~ ^[Yy]$ ]]; then
        mysql -e "ALTER USER '$db_user'@'$db_host' IDENTIFIED BY '$db_password';"
        mysql -e "GRANT ALL PRIVILEGES ON $db_name.* TO '$db_user'@'$db_host';"
        mysql -e "FLUSH PRIVILEGES;"
        echo "Updated permissions for user $db_user on database $db_name."
      fi
      return 0
    fi
  fi
  
  # Create database and user
  echo "Creating MySQL database $db_name and user $db_user..."
  
  # Function to roll back changes in case of failure
  rollback_mysql() {
    echo "Rolling back changes..."
    mysql -e "DROP DATABASE IF EXISTS $db_name;" || true
    mysql -e "DROP USER IF EXISTS '$db_user'@'$db_host';" || true
    echo "Rollback completed."
  }
  
  # Enable trap for rollback
  trap rollback_mysql ERR
  
  # Execute commands
  mysql -e "CREATE DATABASE $db_name;"
  mysql -e "CREATE USER '$db_user'@'$db_host' IDENTIFIED BY '$db_password';"
  mysql -e "GRANT ALL PRIVILEGES ON $db_name.* TO '$db_user'@'$db_host';"
  mysql -e "FLUSH PRIVILEGES;"
  
  # Save state to file
  echo "timestamp: $(date +%s)" > "$state_file"
  echo "type: mysql" >> "$state_file"
  echo "database: $db_name" >> "$state_file"
  echo "user: $db_user" >> "$state_file"
  echo "host: $db_host" >> "$state_file"
  echo "port: $db_port" >> "$state_file"
  
  # Disable trap
  trap - ERR
  
  echo "MySQL database $db_name and user $db_user created successfully."
  return 0
}

menu_databases_backup() {
  with_preview "Back up a database" echo "Not yet implemented"
}

menu_databases_restore() {
  with_preview "Restore a backup" echo "Not yet implemented"
}

# Optional standalone loop
databases_menu() {
  while true; do
    clear
    db_breadcrumb
    echo ""
    echo "Databases"
    echo "1) Install a database (PostgreSQL/MySQL/SQLite)"
    echo "2) Create a database and user"
    echo "3) Back up a database"
    echo "4) Restore a backup"
    echo ""
    echo "0) What is this?"
    echo "P) Preview"
    echo "B) Back"
    echo "Q) Quit"
    read -rp "Choose an option: " choice
    case "$choice" in
      1) menu_databases_install ;;
      2) menu_databases_create ;;
      3) menu_databases_backup ;;
      4) menu_databases_restore ;;
      0) db_show_readme ;;
      [Pp]) echo "Preview shows planned actions before execution."; read -rp "Press Enter to continue..." _ ;;
      [Bb]) return 0 ;;
      [Qq]) exit 0 ;;
      *) echo "Invalid option"; sleep 1 ;;
    esac
  done
}
