#!/usr/bin/env bash
# Webhost Plugin for JB-VPS
# Provides web server setup and hosting functionality

set -euo pipefail
source "$JB_DIR/lib/base.sh"

# Parse key=value or --flag arguments
_webhost_parse_args() {
    SERVER="nginx"
    DOMAIN="example.local"
    ROOT=""
    PREVIEW=false
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --server) SERVER="${2:-nginx}"; shift 2 ;;
            --domain) DOMAIN="${2:-example.local}"; shift 2 ;;
            --root) ROOT="${2:-}"; shift 2 ;;
            --preview) PREVIEW=true; shift ;;
            *) break ;;
        esac
    done
    if [[ -z "$ROOT" ]]; then
        ROOT="/var/www/$DOMAIN"
    fi
}

_webhost_preview() {
    echo "=== PREVIEW: Host a simple website ==="
    echo "Server: $SERVER"
    echo "Domain: $DOMAIN"
    echo "Root:   $ROOT"
    echo ""
    echo "Steps to run:"
    echo "  1) Install package: $([[ "$SERVER" == nginx ]] && echo nginx || echo caddy)"
    echo "  2) Create site root $ROOT (0755), owner jb:jb if user exists"
    echo "  3) Create $ROOT/index.html (hello stub) if missing"
    if [[ "$SERVER" == nginx ]]; then
        echo "  4) Write vhost: /etc/nginx/sites-available/$DOMAIN and symlink to sites-enabled/"
        echo "  5) Validate: nginx -t; enable/start/reload nginx"
    else
        echo "  4) Append site block to /etc/caddy/Caddyfile (backup first)"
        echo "  5) Validate: caddy validate; enable/start/reload caddy"
    fi
    echo "  6) Record state: /var/lib/jb-vps/webhost/$DOMAIN.state"
}

_webhost_nginx_vhost() {
    local domain="$1"; local root="$2"; cat <<EOF
server {
    listen 80;
    server_name $domain;
    root $root;
    index index.html;
    location / {
        try_files \$uri \$uri/ =404;
    }
}
EOF
}

_webhost_caddy_block() {
    local domain="$1"; local root="$2"; cat <<EOF

# jb-vps:$domain
$domain:80 {
    root * $root
    file_server
}
EOF
}

# Setup web hosting environment (idempotent, preview supported)
webhost_setup() {
    _webhost_parse_args "$@"

    local state_dir="/var/lib/jb-vps/webhost"
    local state_file="$state_dir/$DOMAIN.state"

    # Idempotence check
    if [[ -f "$state_file" ]]; then
        echo "Already set up, nothing to change.";
        return 0
    fi

    if [[ "$PREVIEW" == true ]]; then
        _webhost_preview
        return 0
    fi

    log_info "Hosting a simple website ($SERVER, $DOMAIN)" "WEBHOST"

    # 1) Install server
    case "$SERVER" in
        nginx) pkg_install nginx ;;
        caddy) pkg_install caddy || pkg_install caddy-server || true ;;
        *) log_error "Unsupported server: $SERVER" "WEBHOST"; return 1 ;;
    esac

    # 2) Create site root
    as_root mkdir -p "$ROOT"
    if id jb >/dev/null 2>&1; then
        as_root chown jb:jb "$ROOT" || true
    fi
    as_root chmod 0755 "$ROOT" || true

    # 3) Create index.html
    if [[ ! -f "$ROOT/index.html" ]]; then
        as_root tee "$ROOT/index.html" >/dev/null << 'EOF'
<!DOCTYPE html><html><head><meta charset="utf-8"><title>JB-VPS</title></head><body><h1>Hello from JB-VPS</h1></body></html>
EOF
    fi

    # 4) Configure vhost
    local rollback_needed=false
    if [[ "$SERVER" == nginx ]]; then
        local sites_avail="/etc/nginx/sites-available/$DOMAIN"
        local sites_enabled="/etc/nginx/sites-enabled/$DOMAIN"
        # Backup existing vhost if present
        if [[ -f "$sites_avail" ]]; then
            backup_file "$sites_avail" >/dev/null || true
        fi
        _webhost_nginx_vhost "$DOMAIN" "$ROOT" | as_root tee "$sites_avail" >/dev/null
        if [[ ! -L "$sites_enabled" ]]; then
            as_root ln -sf "$sites_avail" "$sites_enabled"
        fi
        rollback_needed=true
    else
        local caddyfile="/etc/caddy/Caddyfile"
        backup_file "$caddyfile" >/dev/null || true
        if ! grep -q "jb-vps:$DOMAIN" "$caddyfile" 2>/dev/null; then
            _webhost_caddy_block "$DOMAIN" "$ROOT" | as_root tee -a "$caddyfile" >/dev/null
        fi
        rollback_needed=true
    fi

    # 5) Validate and (enable|start|reload)
    if [[ "$SERVER" == nginx ]]; then
        if ! as_root nginx -t; then
            log_error "nginx configuration test failed" "WEBHOST"
            # rollback
            if [[ -f "/etc/nginx/sites-available/$DOMAIN" ]]; then
                jb_rollback "/etc/nginx/sites-available/$DOMAIN" || true
            fi
            return 1
        fi
        systemd_enable_start nginx
        as_root systemctl reload nginx || true
    else
        if command -v caddy >/dev/null 2>&1; then
            if ! as_root caddy validate --config /etc/caddy/Caddyfile; then
                log_error "caddy configuration validation failed" "WEBHOST"
                jb_rollback "/etc/caddy/Caddyfile" || true
                return 1
            fi
        fi
        systemd_enable_start caddy
        as_root systemctl reload caddy || true
    fi

    # 6) Record state
    as_root mkdir -p "$state_dir"
    echo "completed=$(date '+%Y-%m-%d %H:%M:%S')" | as_root tee "$state_file" >/dev/null

    echo ""
    echo "Website hosted successfully!"
    echo "  Domain: $DOMAIN"
    echo "  Root:   $ROOT"
    if [[ "$SERVER" == nginx ]]; then
        echo "  VHost:  /etc/nginx/sites-available/$DOMAIN (linked to sites-enabled/)"
        echo "  Test:   curl -I http://localhost"
    else
        echo "  Config: /etc/caddy/Caddyfile (block jb-vps:$DOMAIN)"
        echo "  Test:   curl -I http://localhost"
    fi
}

# Register webhost commands
jb_register "webhost:setup" webhost_setup "Host a simple website (nginx default)" "web"
