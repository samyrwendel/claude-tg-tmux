#!/bin/bash
# typing-daemon: envia sendChatAction enquanto /tmp/claude-processing existir
# Roda como systemd user service: claude-typing-daemon.service

TOKEN=$(grep TELEGRAM_BOT_TOKEN ~/.claude/channels/telegram/.env 2>/dev/null | cut -d= -f2)

if [ -z "$TOKEN" ]; then
  echo "TOKEN não encontrado, abortando"
  exit 1
fi

TIMEOUT=300  # 5 minutos

while true; do
  if [ -f /tmp/claude-processing ]; then
    # Timeout: se flag tiver mais de TIMEOUT segundos, remove e para
    FLAG_AGE=$(( $(date +%s) - $(stat -c %Y /tmp/claude-processing 2>/dev/null || date +%s) ))
    if [ "$FLAG_AGE" -gt "$TIMEOUT" ]; then
      rm -f /tmp/claude-processing /tmp/claude-typing-chat
      # Para o spinner se estiver travado junto
      bash /home/clawd/.claude/hooks/telegram-spinner.sh stop 2>/dev/null
      sleep 4
      continue
    fi

    CHAT_ID=$(cat /tmp/claude-typing-chat 2>/dev/null)
    CHAT_ID="${CHAT_ID:-30289486}"
    curl -s "https://api.telegram.org/bot${TOKEN}/sendChatAction" \
      -H "Content-Type: application/json" \
      -d "{\"chat_id\":${CHAT_ID},\"action\":\"typing\"}" > /dev/null 2>&1
  fi
  sleep 4
done
