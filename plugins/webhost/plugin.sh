#!/usr/bin/env bash
set -euo pipefail
source "$JB_DIR/lib/base.sh"
webhost_setup(){ local s="$JB_DIR/tools/webhost/webhost.sh"; [[ -x "$s" ]] || die "tools/webhost/webhost.sh missing or not executable"; as_root "$s" "$@"; }
jb_register "webhost:setup" webhost_setup "Run your webhost flow (wraps tools/webhost/webhost.sh)"
