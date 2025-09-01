#!/usr/bin/env bash
set -euo pipefail
source "$JB_DIR/lib/base.sh"
dash_install(){ local d="$JB_DIR/dashboards/vps-dashboard"; [[ -d "$d" ]] || die "dashboards/vps-dashboard missing (drop the dashboard here)"; need systemctl || die "systemd required"; ( cd "$d" && as_root ./scripts/install_dashboard.sh ); }
jb_register "dashboard:install" dash_install "Install the compact Nord dashboard + timer"
dash_sysinfo(){ local s="$JB_DIR/dashboards/vps-dashboard/scripts/sysinfo.sh"; [[ -x "$s" ]] || die "sysinfo.sh missing"; as_root "$s"; }
jb_register "dashboard:sysinfo" dash_sysinfo "Emit dashboard sysinfo JSON once"
