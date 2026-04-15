#!/bin/bash
# cronbot-alerts.sh — UserPromptSubmit hook
# Drena alertas pendentes do cronbot e injeta no contexto do Claude.
# NÃO usa tmux send-keys — injeta via stdout do hook, que o Claude lê como contexto.
# Só drena quando há mensagem do Telegram (não polui sessões CLI locais).

INPUT=$(cat)

# Só rodar se for mensagem Telegram
CHAT_ID=$(echo "$INPUT" | python3 -c "
import sys, json, re
try:
    d = json.load(sys.stdin)
    m = re.search(r'chat_id=\"(\d+)\"', d.get('prompt',''))
    if m: print(m.group(1))
except: pass
" 2>/dev/null)

[ -z "$CHAT_ID" ] && exit 0

ALERT_DIR="/tmp/cronbot/alerts"
[ -d "$ALERT_DIR" ] || exit 0

ALERTS=""
for f in "$ALERT_DIR"/*.alert; do
  [ -f "$f" ] || continue
  content=$(cat "$f")
  [ -z "$content" ] && rm -f "$f" && continue
  ALERTS="${ALERTS}${content}\n"
  rm -f "$f"
done

[ -z "$ALERTS" ] && exit 0

# Injetar no contexto via stdout — Claude lê como parte do contexto da sessão
printf "\n[SISTEMA — alertas do cronbot]\n%b\n" "$ALERTS"

exit 0
