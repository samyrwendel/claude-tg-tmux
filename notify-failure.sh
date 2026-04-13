#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -f "$SCRIPT_DIR/.env" ] && source "$SCRIPT_DIR/.env"

COOLDOWN_FILE="/tmp/mainbot-notify-cooldown"
COOLDOWN_SECS=600

if [ -f "$COOLDOWN_FILE" ]; then
    last=$(stat -c %Y "$COOLDOWN_FILE" 2>/dev/null) || last=0
    now=$(date +%s)
    if (( now - last < COOLDOWN_SECS )); then exit 0; fi
fi

TOKEN="${TELEGRAM_BOT_TOKEN}"
CHAT_ID="${ADMIN_CHAT_ID}"

if [ -n "$TOKEN" ] && [ -n "$CHAT_ID" ]; then
    curl -s -X POST "https://api.telegram.org/bot${TOKEN}/sendMessage" \
        -d chat_id="$CHAT_ID" \
        -d text="⚠️ NanoBot caiu — systemd reiniciando. Se repetir 3x em 10min, para." \
        >/dev/null 2>&1
    touch "$COOLDOWN_FILE"
fi
