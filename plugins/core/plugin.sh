#!/usr/bin/env bash
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
