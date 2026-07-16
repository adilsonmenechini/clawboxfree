#!/bin/sh
set -e

AUTH_USERNAME="${OPENCLAW_AUTH_USERNAME:-admin}"
AUTH_PASSWORD="${OPENCLAW_AUTH_PASSWORD:-}"

if [ -z "$AUTH_PASSWORD" ]; then
    echo "WARNING: OPENCLAW_AUTH_PASSWORD not set. Generating random password."
    AUTH_PASSWORD=$(tr -dc A-Za-z0-9 </dev/urandom | head -c 16 2>/dev/null || echo "clawbox-$(date +%s)")
    echo "Generated password: $AUTH_PASSWORD"
fi

if [ "$AUTH_PASSWORD" = "clawbox-admin" ]; then
    echo "WARNING: Using default password. Change OPENCLAW_AUTH_PASSWORD in .env"
fi

if ! command -v htpasswd >/dev/null 2>&1; then
    apk add --no-cache apache2-utils >/dev/null 2>&1
fi

htpasswd -c -b /etc/nginx/.htpasswd "$AUTH_USERNAME" "$AUTH_PASSWORD"

echo "Basic auth enabled: user=${AUTH_USERNAME}"
