#!/usr/bin/env bash
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
