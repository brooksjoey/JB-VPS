#!/bin/bash
# Updated VPS Initializer with Integrated Environment Management

# Load environment before anything else
if [ -f ~/my-sys-configs/scripts/env-manager.sh ]; then
    echo "🔐 Loading secure environment..."
    ~/my-sys-configs/scripts/env-manager.sh load personal
fi

# Your existing setup code continues here...
setup_cloudflare() {
    # Now uses environment variables instead of hardcoded values
    if [ -n "${CF_API_KEY:-}" ]; then
        echo "🔐 Using Cloudflare API key from environment"
        mkdir -p "$(dirname "$CF_SECRET_FILE")"
        echo "$CF_API_KEY" > "$CF_SECRET_FILE"
        chmod 600 "$CF_SECRET_FILE"
    else
        echo "⚠️  CF_API_KEY not set - prompting for input"
        read -sp "Enter Cloudflare API key: " cf_key
        echo
        echo "$cf_key" > "$CF_SECRET_FILE"
        chmod 600 "$CF_SECRET_FILE"
    fi
}