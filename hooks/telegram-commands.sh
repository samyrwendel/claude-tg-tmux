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

case "$CMD" in
  /help)
    tg_send "$(cat <<'MSG'
*Comandos disponíveis:*

/help — esta mensagem
/syscheck — status do sistema
/model — modelo atual
/tts on|off — ligar/desligar voz
/compact — compactar contexto
/new — nova conversa
/restart — reinicia a sessão
/setkey NOME VALOR — salva API key nas skills
/listkeys — lista as keys configuradas (sem valores)
MSG
    )"
    echo '{"decision":"block","reason":"Command handled"}'
    ;;

  /syscheck)
    TTS_STATUS="on"
    [ -f /tmp/claude-tts-disabled ] && TTS_STATUS="off"

    # Sessão mainbot
    MAINBOT_UP="❌ down"
    tmux has-session -t mainbot 2>/dev/null && MAINBOT_UP="✅ up"

    # Processo Claude no pane
    PANE_PID=$(tmux list-panes -t mainbot -F '#{pane_pid}' 2>/dev/null)
    CLAUDE_UP="❌ morto"
    [ -n "$PANE_PID" ] && kill -0 "$PANE_PID" 2>/dev/null && CLAUDE_UP="✅ vivo"

    # OpenClaw Gateway (PM2 clawdbot-gw — @mentordegenbot)
    OC_STATUS=$(pm2 list 2>/dev/null | grep "clawdbot-gw" | awk '{print $10}')
    OC_HEALTH="❌ offline"
    [ "$OC_STATUS" = "online" ] && OC_HEALTH="✅ online"

    tg_send "$(cat <<MSG
*Status — $(date '+%d/%m %H:%M')*

*Mainbot (@dgenmainbot)*
Sessão tmux: ${MAINBOT_UP}
Claude CLI: ${CLAUDE_UP}
TTS: ${TTS_STATUS}

*Degenerado/OpenClaw (@mentordegenbot)*
clawdbot-gw PM2: ${OC_HEALTH}
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
    tg_send "Reiniciando sessão mainbot..."
    systemctl --user restart claude-cli.service &
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
