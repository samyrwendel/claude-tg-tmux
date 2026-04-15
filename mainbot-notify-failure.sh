#!/bin/bash
# Called by systemd OnFailure — sends Telegram notification with cooldown
COOLDOWN_FILE="/tmp/mainbot-notify-cooldown"
COOLDOWN_SECS=600  # 10 minutes between notifications

# Check cooldown
if [ -f "$COOLDOWN_FILE" ]; then
    last=$(stat -c %Y "$COOLDOWN_FILE" 2>/dev/null) || last=0
    now=$(date +%s)
    elapsed=$(( now - last ))
    if [ "$elapsed" -lt "$COOLDOWN_SECS" ]; then
        exit 0
    fi
fi

TG_BOT_TOKEN=$(grep TELEGRAM_BOT_TOKEN /home/clawd/.claude/channels/telegram/.env 2>/dev/null | cut -d= -f2)
TG_CHAT_ID="30289486"

if [ -n "$TG_BOT_TOKEN" ]; then
    curl -s -X POST "https://api.telegram.org/bot${TG_BOT_TOKEN}/sendMessage" \
        -d chat_id="$TG_CHAT_ID" \
        -d text="⚠️ Mainbot (@dgenmainbot) caiu — systemd reiniciando. Se repetir 3x em 10min, para automaticamente." \
        >/dev/null 2>&1
    touch "$COOLDOWN_FILE"
fi
