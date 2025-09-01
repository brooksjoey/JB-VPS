#!/usr/bin/env bash
# JB-VPS structure bootstrapper
# Creates the full directory tree + placeholder files and safe defaults.
# Usage: bash scripts/mkdir_structure.sh
set -euo pipefail

Cyan()  { printf "\033[36m%s\033[0m" "$*"; }
Green() { printf "\033[32m%s\033[0m" "$*"; }
Warn()  { printf "\033[33m%s\033[0m" "$*"; }
Info()  { Cyan "[JB-VPS] "; printf "%s\n" "$1"; }

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

mkd() {
  mkdir -p "$1"
  Info "dir  $(Green "$1")"
}

mkf() {
  local path="$1"; shift || true
  local content="${*:-}"
  if [[ -e "$path" ]]; then
    Info "keep $(Warn "$path (exists)")"
  else
    printf "%s" "$content" > "$path"
    Info "file $(Green "$path")"
  fi
}

mkx() {
  chmod +x "$1" 2>/dev/null || true
  Info "exec $(Green "$1")"
}

# 1) Directories
mkd "bin"
mkd "lib"
mkd "plugins/core"
mkd "plugins/env"
mkd "plugins/webhost"
mkd "plugins/dashboard"
mkd "scripts"
mkd "tools/webhost/html scripts"
mkd "dashboards/vps-dashboard/assets"
mkd "dashboards/vps-dashboard/data"
mkd "dashboards/vps-dashboard/scripts"
mkd "services/my-timers"
mkd "secure/environments"
mkd "profiles/debian-bookworm"
mkd ".github/workflows"

# 2) Top-level files
mkf ".gitignore" "# Logs and systemd dumps
*.log
*.swp
*.tmp
.env
dashboards/**/data/*.json
secure/environments/*.env
secure/environments/*.env.gpg~
"
mkf "README.md" "# JB-VPS
(README placeholder; the full README is provided in our chat. Copy it here.)
"
# 3) bin/jb entrypoint (placeholder; you’ll wire real logic later or paste the version I gave earlier)
mkf "bin/jb" '#!/usr/bin/env bash
set -euo pipefail
JB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$JB_DIR/lib/base.sh"
# Load every plugin (each should call jb_register)
shopt -s nullglob
for p in "$JB_DIR/plugins"/*/plugin.sh; do
  source "$p"
done
shopt -u nullglob

cmd="${1:-help}"; shift || true
if [[ -z "${JB_CMDS_FUNC[$cmd]:-}" ]]; then
  jb_help; exit 1
fi
"${JB_CMDS_FUNC[$cmd]}" "$@"
'
mkx "bin/jb"

# 4) lib/base.sh with registry + helpers (ready to use)
mkf "lib/base.sh" '#!/usr/bin/env bash
set -euo pipefail
declare -A JB_CMDS_FUNC
declare -A JB_CMDS_HELP
jb_register(){ JB_CMDS_FUNC["$1"]="$2"; JB_CMDS_HELP["$1"]="$3"; }
jb_help(){
  echo "JB-VPS — command index"; echo "Usage: jb <command> [args]"; echo;
  for k in "${!JB_CMDS_FUNC[@]}"; do printf "  %-20s %s\n" "$k" "${JB_CMDS_HELP[$k]}"; done | sort
}
log(){ printf "\033[36m[JB]\033[0m %s\n" "$*"; }
warn(){ printf "\033[33m[!]\033[0m %s\n" "$*"; }
die(){ printf "\033[31m[x]\033[0m %s\n" "$*" >&2; exit 1; }
need(){ command -v "$1" >/dev/null 2>&1 || die "Missing dependency: $1"; }
as_root(){ if [[ $EUID -ne 0 ]]; then sudo -n "$@" || sudo "$@"; else "$@"; fi; }
detect_os(){ [[ -f /etc/os-release ]] && source /etc/os-release; echo "${ID:-unknown}"; }
pkg_install(){
  local os; os="$(detect_os)"
  case "$os" in
    debian|ubuntu) as_root apt-get update -y; as_root apt-get install -y "$@";;
    fedora) as_root dnf install -y "$@";;
    centos|rhel) as_root yum install -y "$@";;
    arch) as_root pacman -Sy --noconfirm "$@";;
    *) die "Unsupported OS: $os";;
  esac
}
'
mkx "lib/base.sh"

# 5) Core plugin placeholder
mkf "plugins/core/plugin.sh" '#!/usr/bin/env bash
set -euo pipefail
source "$JB_DIR/lib/base.sh"

core_init(){ local s="$JB_DIR/scripts/vps-init.sh"; [[ -x "$s" ]] || die "scripts/vps-init.sh missing"; as_root "$s"; }
jb_register "init" core_init "Bootstrap a fresh VPS (runs scripts/vps-init.sh)"

core_harden(){ local s="$JB_DIR/scripts/security_hardening.sh"; [[ -x "$s" ]] || die "scripts/security_hardening.sh missing"; as_root "$s"; }
jb_register "harden" core_harden "Apply security hardening (runs scripts/security_hardening.sh)"

core_info(){
  need jq || pkg_install jq
  if [[ -x "$JB_DIR/dashboards/vps-dashboard/scripts/sysinfo.sh" ]]; then
    as_root "$JB_DIR/dashboards/vps-dashboard/scripts/sysinfo.sh"
  else
    echo "{}" | jq -c --arg host "$(hostname)" --arg kern "$(uname -r)" \
      --arg os "$(grep PRETTY_NAME /etc/os-release 2>/dev/null|cut -d= -f2|tr -d \")" \
      ". + {hostname:$host, os:{pretty:$os}, kernel:$kern}"
  fi
}
jb_register "info" core_info "Emit system info JSON"
'
mkx "plugins/core/plugin.sh"

# 6) Env plugin placeholder
mkf "plugins/env/plugin.sh" '#!/usr/bin/env bash
set -euo pipefail
source "$JB_DIR/lib/base.sh"
ENV_DIR="$JB_DIR/secure/environments"
env_list(){ ls -1 "$ENV_DIR"/*.gpg 2>/dev/null | sed "s#.*/##; s#\\.gpg$##" || true; }
jb_register "env:list" env_list "List encrypted env names (from secure/environments)"
env_write(){ need gpg; local name="${1:-}"; local out="${2:-}"; [[ -n "$name" && -n "$out" ]] || die "Usage: jb env:write <name> <outfile>"; local f="$ENV_DIR/$name.env.gpg"; [[ -f "$f" ]] || die "Not found: $f"; gpg -d "$f" > "$out"; }
jb_register "env:write" env_write "Decrypt <name>.env.gpg to <outfile>"
env_eval(){ need gpg; local name="${1:-}"; [[ -n "$name" ]] || die "Usage: jb env:eval <name>"; local f="$ENV_DIR/$name.env.gpg"; [[ -f "$f" ]] || die "Not found: $f"; # shellcheck disable=SC2046
export $(gpg -d "$f" | xargs); }
jb_register "env:eval" env_eval "Export env vars from <name>.env.gpg into the current JB session"
'
mkx "plugins/env/plugin.sh"

# 7) Webhost plugin placeholder
mkf "plugins/webhost/plugin.sh" '#!/usr/bin/env bash
set -euo pipefail
source "$JB_DIR/lib/base.sh"
webhost_setup(){ local s="$JB_DIR/tools/webhost/webhost.sh"; [[ -x "$s" ]] || die "tools/webhost/webhost.sh missing or not executable"; as_root "$s" "$@"; }
jb_register "webhost:setup" webhost_setup "Run your webhost flow (wraps tools/webhost/webhost.sh)"
'
mkx "plugins/webhost/plugin.sh"

# 8) Dashboard plugin placeholder
mkf "plugins/dashboard/plugin.sh" '#!/usr/bin/env bash
set -euo pipefail
source "$JB_DIR/lib/base.sh"
dash_install(){ local d="$JB_DIR/dashboards/vps-dashboard"; [[ -d "$d" ]] || die "dashboards/vps-dashboard missing (drop the dashboard here)"; need systemctl || die "systemd required"; ( cd "$d" && as_root ./scripts/install_dashboard.sh ); }
jb_register "dashboard:install" dash_install "Install the compact Nord dashboard + timer"
dash_sysinfo(){ local s="$JB_DIR/dashboards/vps-dashboard/scripts/sysinfo.sh"; [[ -x "$s" ]] || die "sysinfo.sh missing"; as_root "$s"; }
jb_register "dashboard:sysinfo" dash_sysinfo "Emit dashboard sysinfo JSON once"
'
mkx "plugins/dashboard/plugin.sh"

# 9) Scripts placeholders (you will paste your real logic)
mkf "scripts/vps-init.sh" '#!/usr/bin/env bash
set -euo pipefail
echo "[vps-init] placeholder — add your bootstrap logic here"
'
mkx "scripts/vps-init.sh"

mkf "scripts/security_hardening.sh" '#!/usr/bin/env bash
set -euo pipefail
echo "[security_hardening] placeholder — add your hardening steps here"
'
mkx "scripts/security_hardening.sh"

mkf "scripts/env-manager.sh" '#!/usr/bin/env bash
set -euo pipefail
echo "[env-manager] placeholder — combine with plugins/env if you want"
'

# 10) Tools/webhost placeholders (so your current files have a home)
mkf "tools/webhost/webhost.sh" '#!/usr/bin/env bash
set -euo pipefail
echo "[webhost] placeholder — drop in your real webhost.sh (and mark it executable)"
'
mkx "tools/webhost/webhost.sh"

mkf "tools/webhost/html scripts/README.md" "# Place any HTML/JS helpers or templates used by webhost flows here.\n"

# 11) Dashboard placeholders (so Textastic can upload into a ready path)
mkf "dashboards/vps-dashboard/index.html" "<!-- placeholder: drop the real dashboard bundle here -->\n"
mkf "dashboards/vps-dashboard/assets/style.css" "/* placeholder */\n"
mkf "dashboards/vps-dashboard/assets/app.js" "// placeholder\n"
mkf "dashboards/vps-dashboard/data/sysinfo.json" "{ \"placeholder\": true }\n"
mkf "dashboards/vps-dashboard/scripts/sysinfo.sh" "#!/usr/bin/env bash\nset -euo pipefail\necho '{\"placeholder\":true}'\n"
mkx "dashboards/vps-dashboard/scripts/sysinfo.sh"
mkf "services/my-timers/sysinfo.service" "[Unit]\nDescription=Generate sysinfo JSON for dashboard\n\n[Service]\nType=oneshot\nExecStart=/usr/local/bin/sysinfo-json > /var/www/html/vps-dashboard/data/sysinfo.json\n"
mkf "services/my-timers/sysinfo.timer" "[Unit]\nDescription=Refresh sysinfo JSON every 5s\n\n[Timer]\nOnUnitActiveSec=5s\nAccuracySec=1s\nUnit=sysinfo.service\n\n[Install]\nWantedBy=timers.target\n"

# 12) Profiles + CI placeholders
mkf "profiles/debian-bookworm/packages.txt" "# list packages you want installed here\n"
mkf "profiles/debian-bookworm/sshd_config" "# custom sshd_config goes here\n"
mkf ".github/workflows/ci.yml" "name: JB-VPS CI\non: [push]\njobs:\n  shellcheck:\n    runs-on: ubuntu-latest\n    steps:\n      - uses: actions/checkout@v4\n      - uses: ludeeus/action-shellcheck@v2\n"

Info "Done. Structure ready. Try: ./bin/jb help"