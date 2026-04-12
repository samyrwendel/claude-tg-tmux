#!/bin/bash
# Send "typing..." indicator to Telegram every 4s until killed
# Usage: typing-indicator.sh <chat_id>
# Kill with: kill $PID or kill $(cat /tmp/typing-indicator.pid)

CHAT_ID="${1:-30289486}"
TOKEN=$(grep TELEGRAM_BOT_TOKEN ~/.claude/channels/telegram/.env 2>/dev/null | cut -d= -f2)

if [ -z "$TOKEN" ]; then exit 1; fi

echo $$ > /tmp/typing-indicator.pid

while true; do
  curl -s "https://api.telegram.org/bot${TOKEN}/sendChatAction" \
    -d "chat_id=${CHAT_ID}" -d "action=typing" > /dev/null 2>&1
  sleep 4
done
