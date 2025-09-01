#!/usr/bin/env bash
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
