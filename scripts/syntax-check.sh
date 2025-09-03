#!/usr/bin/env bash
# Run bash syntax checks across key script locations
set -euo pipefail

shopt -s nullglob

declare -a files=()
files+=(bin/*.sh)
files+=(lib/*.sh)
files+=(plugins/*/plugin.sh)
files+=(areas/*/menu.sh)

fail=0

if [[ ${#files[@]} -eq 0 ]]; then
  echo "No files matched for syntax check." >&2
  exit 0
fi

echo "Running bash -n on ${#files[@]} files..."
for f in "${files[@]}"; do
  if bash -n "$f"; then
    printf "OK   %s\n" "$f"
  else
    printf "FAIL %s\n" "$f"
    fail=1
  fi
done

exit $fail

