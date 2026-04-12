#!/bin/bash
# dream-delivery.sh — Entrega matinal dos insights do dream cycle (v2: direto via Telegram API)
# Roda às 8h (Manaus) via cron. Sem dependência de tmux ou sessão ativa.

LOG="/tmp/dream-cycle.log"
DONE_FLAG="/tmp/dream-cycle-done"
PID_FILE="/tmp/dream-cycle-pid"
INSIGHTS_FILE="$HOME/.claude/projects/-home-clawd/memory/dream-insights.md"
TOKEN=$(grep TELEGRAM_BOT_TOKEN ~/.claude/channels/telegram/.env 2>/dev/null | cut -d= -f2)
CHAT_ID="30289486"

# Só entrega se o dream rodou e concluiu
if [ ! -f "$DONE_FLAG" ]; then
  # Verificar se ainda está rodando
  if [ -f "$PID_FILE" ]; then
    PID=$(cat "$PID_FILE")
    if kill -0 "$PID" 2>/dev/null; then
      echo "$(date): dream ainda rodando (PID $PID), reagendando entrega em 15min" >> "$LOG"
      (sleep 900 && /home/clawd/.claude/hooks/dream-delivery.sh) &
      exit 0
    fi
    # Processo morreu sem sinalizar done
    echo "$(date): processo dream morreu sem done flag, verificando arquivo de insights" >> "$LOG"
    rm -f "$PID_FILE"
  else
    exit 0
  fi
fi

# Verificar se há insights do dia de hoje
TODAY=$(TZ=America/Manaus date '+%Y-%m-%d')
if [ ! -f "$INSIGHTS_FILE" ]; then
  echo "$(date): sem arquivo de insights, nada a entregar" >> "$LOG"
  rm -f "$DONE_FLAG"
  exit 0
fi

# Extrair última entrada de hoje
SECTION=$(awk "/^## ${TODAY}/{found=1} found{print} /^---$/{if(found) exit}" "$INSIGHTS_FILE")

if [ -z "$SECTION" ]; then
  echo "$(date): sem insights de hoje no arquivo, nada a entregar" >> "$LOG"
  rm -f "$DONE_FLAG"
  exit 0
fi

# Montar mensagem pro Telegram
MSG="*Sonhei essa noite...*

${SECTION}

_Dream cycle concluído em ${TODAY}_"

# Enviar via Telegram Bot API diretamente
RESPONSE=$(curl -s -X POST "https://api.telegram.org/bot${TOKEN}/sendMessage" \
  -H "Content-Type: application/json" \
  -d "{\"chat_id\": \"${CHAT_ID}\", \"text\": $(echo "$MSG" | python3 -c 'import sys,json; print(json.dumps(sys.stdin.read()))'), \"parse_mode\": \"Markdown\"}")

if echo "$RESPONSE" | grep -q '"ok":true'; then
  echo "$(date): insights entregues com sucesso" >> "$LOG"
  rm -f "$DONE_FLAG" "$PID_FILE"
else
  echo "$(date): erro ao enviar Telegram: $RESPONSE" >> "$LOG"
fi
