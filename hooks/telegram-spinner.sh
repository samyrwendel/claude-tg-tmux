#!/bin/bash
# Spinner animado no Telegram — roda em background trocando emoji da mensagem
# Uso: telegram-spinner.sh start "texto" | telegram-spinner.sh stop

BOT_TOKEN="8620058557:AAEUzCZ9AykBfzdzSAPJRGwVzot2FLrXVaE"
CHAT_ID="30289486"
PID_FILE="/tmp/telegram-spinner.pid"
MSG_FILE="/tmp/telegram-spinner-msgid"
TEXT_FILE="/tmp/telegram-spinner-text"

FRAMES=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
EMOJIS=("⚙️" "🔧" "🔨" "💻" "🛠️" "🔄" "📡" "🧠" "🚀" "⏳")

start_spinner() {
  local TEXT="$1"
  local LOCK="/tmp/telegram-spinner.lock"

  # Lock para evitar race condition com múltiplos starts simultâneos
  exec 9>"$LOCK"
  flock -n 9 || exit 0  # Se não conseguir o lock, outro start está rodando — sair silenciosamente

  # Matar spinner anterior se existir
  if [ -f "$PID_FILE" ]; then
    kill $(cat "$PID_FILE") 2>/dev/null
    rm -f "$PID_FILE"
  fi

  # Criar mensagem inicial
  RESP=$(curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
    -d "chat_id=${CHAT_ID}" \
    -d "text=${FRAMES[0]} ${TEXT}" \
    -d "disable_notification=true")
  MSG_ID=$(echo "$RESP" | python3 -c "import sys,json; print(json.load(sys.stdin).get('result',{}).get('message_id',''))" 2>/dev/null)

  if [ -z "$MSG_ID" ]; then
    exit 1
  fi

  echo "$MSG_ID" > "$MSG_FILE"
  echo "$TEXT" > "$TEXT_FILE"
  date +%s > /tmp/telegram-spinner-start

  # Loop de animação em background (auto-kill após 10 minutos)
  (
    i=0
    MAX_SECONDS=120
    START=$(date +%s)
    while true; do
      sleep 1.5
      NOW=$(date +%s)
      if [ $(( NOW - START )) -gt $MAX_SECONDS ]; then
        # Timeout: deletar a mensagem do spinner silenciosamente
        curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/deleteMessage" \
          -d "chat_id=${CHAT_ID}" \
          -d "message_id=${MSG_ID}" \
          > /dev/null 2>&1
        rm -f /tmp/telegram-spinner.pid /tmp/telegram-spinner-msgid /tmp/telegram-spinner-text /tmp/telegram-spinner-start
        rm -f /tmp/claude-processing /tmp/claude-typing-chat
        exit 0
      fi
      i=$(( (i + 1) % ${#FRAMES[@]} ))
      CURRENT_TEXT=$(cat "$TEXT_FILE" 2>/dev/null || echo "$TEXT")
      curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/editMessageText" \
        -d "chat_id=${CHAT_ID}" \
        -d "message_id=${MSG_ID}" \
        -d "text=${FRAMES[$i]} ${CURRENT_TEXT}" \
        > /dev/null 2>&1
    done
  ) &

  echo $! > "$PID_FILE"
  exec 9>&-  # Liberar lock
}

update_text() {
  echo "$1" > "$TEXT_FILE"
}

stop_spinner() {
  if [ -f "$PID_FILE" ]; then
    kill $(cat "$PID_FILE") 2>/dev/null
    rm -f "$PID_FILE"
  fi
  if [ -f "$MSG_FILE" ]; then
    MSG_ID=$(cat "$MSG_FILE")
    LAST_TEXT=$(cat "$TEXT_FILE" 2>/dev/null || echo "pronto")
    curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/editMessageText" \
      -d "chat_id=${CHAT_ID}" \
      -d "message_id=${MSG_ID}" \
      -d "text=✅ ${LAST_TEXT}" \
      > /dev/null 2>&1
    rm -f "$MSG_FILE" "$TEXT_FILE" /tmp/telegram-spinner-start
  fi
}

case "$1" in
  start) start_spinner "$2" ;;
  update) update_text "$2" ;;
  stop) stop_spinner ;;
  *) echo "Uso: $0 start|update|stop [texto]" ;;
esac
