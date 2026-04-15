INPUT=$(cat)

CHAT_ID=$(echo "$INPUT" | python3 -c "
import sys, json, re
try:
    d = json.load(sys.stdin)
    prompt = d.get('prompt', '')
    m = re.search(r'chat_id=\"(\d+)\"', prompt)
    if m: print(m.group(1))
except: pass
" 2>/dev/null)

TEXT=$(echo "$INPUT" | python3 -c "
import sys, json, re
try:
    d = json.load(sys.stdin)
    prompt = d.get('prompt', '')
    m = re.search(r'<channel[^>]*>(.*?)</channel>', prompt, re.DOTALL)
    if m: print(m.group(1).strip())
except: pass
" 2>/dev/null)

if [ -z "$CHAT_ID" ] || [ -z "$TEXT" ]; then exit 0; fi
if [[ "$TEXT" != /* ]]; then exit 0; fi

TOKEN=$(grep TELEGRAM_BOT_TOKEN ~/.claude/channels/telegram/.env 2>/dev/null | cut -d= -f2)
if [ -z "$TOKEN" ]; then exit 0; fi

# Só Samyr pode usar comandos sensíveis
SAMYR_ID="30289486"

tg_send() {
  curl -s "https://api.telegram.org/bot${TOKEN}/sendMessage" \
    -d "chat_id=${CHAT_ID}" \
    -d "parse_mode=Markdown" \
    --data-urlencode "text=$1" > /dev/null
}

CMD=$(echo "$TEXT" | awk '{print $1}' | tr '[:upper:]' '[:lower:]')

# Agentes do mainbot e seus emojis
agent_status() {
  local name="$1" emoji="$2"
  tmux has-session -t "$name" 2>/dev/null && echo "${emoji} ${name} — ✅" || echo "${emoji} ${name} — ❌"
}

case "$CMD" in
  /stat|/status)
    TTS_STATUS="on"; [ -f /tmp/claude-tts-disabled ] && TTS_STATUS="off"

    # Agentes tmux do mainbot
    A_MAINBOT=$(agent_status mainbot "🧠")
    A_DEVBOT=$(agent_status devbot "💻")
    A_EXECBOT=$(agent_status execbot "⚡")
    A_CRONBOT=$(agent_status cronbot "⏰")
    A_DEGENBOT=$(agent_status degenbot "🦧")
    A_SPAWNBOT=$(agent_status spawnbot "🔁")

    # PM2
    pm2_status() {
      local name="$1" emoji="$2"
      local s=$(pm2 list 2>/dev/null | grep " $name " | awk '{print $10}')
      [ "$s" = "online" ] && echo "${emoji} ${name} — ✅" || echo "${emoji} ${name} — ❌"
    }
    OC_GW=$(pm2_status clawdbot-gw "🤖")
    BQ_SYNC=$(pm2_status bq-sync-daemon "📦")

    tg_send "$(cat <<MSG
*Status — $(TZ=America/Manaus date '+%d/%m %H:%M')*

*Agentes Mainbot (@mainagentebot)*
${A_MAINBOT}
${A_DEVBOT}
${A_EXECBOT}
${A_CRONBOT}
${A_DEGENBOT}
${A_SPAWNBOT}
TTS: ${TTS_STATUS}

*Serviços PM2*
${OC_GW}
${BQ_SYNC}
MSG
    )"
    echo '{"decision":"block","reason":"Command handled"}'
    ;;
  /help)
    tg_send "$(cat <<'MSG'
*Comandos disponíveis:*

/stat — status dos agentes e serviços
/syscheck — status detalhado do sistema
/model — modelo Claude atual
/tts on|off — ligar/desligar voz
/compact — compactar contexto da conversa
/new — nova conversa
/restart — reinicia a sessão mainbot
/setkey NOME VALOR — salva API key nas skills
/listkeys — lista as keys configuradas (sem valores)
/help — esta mensagem
MSG
    )"
    echo '{"decision":"block","reason":"Command handled"}'
    ;;

  /syscheck)
    HEARTBEAT=$(stat -c %Y /tmp/claude-heartbeat 2>/dev/null || echo 0)
    NOW=$(date +%s)
    DIFF=$((NOW - HEARTBEAT))
    TTS_STATUS="on"
    [ -f /tmp/claude-tts-disabled ] && TTS_STATUS="off"

    OC_HEALTH=$(curl -s --max-time 2 http://localhost:18789/health 2>/dev/null | python3 -c "import json,sys; d=json.load(sys.stdin); print('✅ live' if d.get('ok') else '❌ down')" 2>/dev/null || echo "❌ offline")

    OC_NOTES=$(python3 -c "
import json, datetime
try:
    d = json.load(open('/home/clawd/clawd/memory/heartbeat-state.json'))
    checks = d.get('lastChecks', {})
    now = datetime.datetime.now().timestamp()
    parts = []
    for k,v in checks.items():
        mins = int((now - v) / 60)
        parts.append(f'{k}: {mins}m atrás')
    print(', '.join(parts[:3]))
except:
    print('indisponível')
" 2>/dev/null)

    tg_send "$(cat <<MSG
*Syscheck — $(date '+%d/%m %H:%M')*

*Mainbot (@mainagentebot)*
TTS: ${TTS_STATUS}

*OpenClaw Gateway*
Health: ${OC_HEALTH}
Checks: ${OC_NOTES}

_Tem alguma tarefa pendente que precisa ser resolvida?_
MSG
    )"
    echo '{"decision":"block","reason":"Command handled"}'
    ;;

  /model)
    tg_send "Modelo: *claude-sonnet-4-6*"
    echo '{"decision":"block","reason":"Command handled"}'
    ;;

  /tts)
    ARG=$(echo "$TEXT" | awk '{print $2}' | tr '[:upper:]' '[:lower:]')
    if [ "$ARG" = "off" ]; then
      touch /tmp/claude-tts-disabled
      tg_send "TTS desligado."
    else
      rm -f /tmp/claude-tts-disabled
      tg_send "TTS ligado."
    fi
    echo '{"decision":"block","reason":"Command handled"}'
    ;;

  /compact)
    tg_send "Compactando contexto..."
    tmux send-keys -t mainbot "/compact" Enter
    echo '{"decision":"block","reason":"Command handled"}'
    ;;

  /new)
    tg_send "Iniciando nova conversa..."
    tmux send-keys -t mainbot "/new" Enter
    echo '{"decision":"block","reason":"Command handled"}'
    ;;

  /restart)
    tg_send "Reiniciando sessão..."
    sudo systemctl restart claude-watchdog.service &
    echo '{"decision":"block","reason":"Command handled"}'
    ;;

  /setkey)
    # Apenas Samyr pode definir keys
    if [ "$CHAT_ID" != "$SAMYR_ID" ]; then
      tg_send "Sem permissão."
      echo '{"decision":"block","reason":"Command handled"}'
      exit 0
    fi

    KEY_NAME=$(echo "$TEXT" | awk '{print $2}')
    KEY_VALUE=$(echo "$TEXT" | awk '{print $3}')
    ENV_FILE="$HOME/.claude/skills/.env"

    if [ -z "$KEY_NAME" ] || [ -z "$KEY_VALUE" ]; then
      tg_send "Uso: /setkey NOME VALOR"
      echo '{"decision":"block","reason":"Command handled"}'
      exit 0
    fi

    # Sanitizar nome (só letras, números, underscore)
    if ! echo "$KEY_NAME" | grep -qE '^[A-Z_][A-Z0-9_]+$'; then
      tg_send "Nome inválido. Use só letras maiúsculas e underscore. Ex: ELEVENLABS_API_KEY"
      echo '{"decision":"block","reason":"Command handled"}'
      exit 0
    fi

    # Atualizar ou adicionar no .env
    if grep -q "^${KEY_NAME}=" "$ENV_FILE" 2>/dev/null; then
      sed -i "s|^${KEY_NAME}=.*|${KEY_NAME}=${KEY_VALUE}|" "$ENV_FILE"
    else
      echo "${KEY_NAME}=${KEY_VALUE}" >> "$ENV_FILE"
    fi

    tg_send "✅ ${KEY_NAME} salvo em skills/.env"
    echo '{"decision":"block","reason":"Command handled"}'
    ;;

  /listkeys)
    if [ "$CHAT_ID" != "$SAMYR_ID" ]; then
      tg_send "Sem permissão."
      echo '{"decision":"block","reason":"Command handled"}'
      exit 0
    fi

    ENV_FILE="$HOME/.claude/skills/.env"
    RESULT=$(grep -v '^#' "$ENV_FILE" 2>/dev/null | grep '=' | awk -F= '{
      if ($2 == "") print "  " $1 ": ❌ não configurado"
      else print "  " $1 ": ✅"
    }' | head -20)

    tg_send "$(cat <<MSG
*Skills — API Keys*

${RESULT}
MSG
    )"
    echo '{"decision":"block","reason":"Command handled"}'
    ;;

  *)
    exit 0
    ;;
esac
