#!/bin/bash
# tmux-doctor.sh — Diagnóstico e auto-fix da sessão mainbot (Claude TG)
# Sistema: claude-tg-tmux / mainbot tmux (@mainagentebot)
# NÃO confundir com OpenClaw/Degenerado (@mentordegenbot, PM2 clawdbot-gw)
#
# Problemas tratados:
#   1. Sessão não existe → recria via mainbot-launcher.sh
#   2. Preso na tela de trust dialog → confirma com Enter
#   3. MCP Telegram desconectou (Claude idle sem responder) → reinicia sessão
#   4. hasTrustDialogAccepted=false → corrige no .claude.json

SESSION="mainbot"
CLAUDE_BIN="/home/clawd/.npm-global/bin/claude"
CLAUDE_ARGS="--channels plugin:telegram@claude-plugins-official --permission-mode bypassPermissions --dangerously-skip-permissions"
MAINBOT_LAUNCHER="/home/clawd/claude-tg-tmux/scripts/mainbot-launcher.sh"
WORKDIR="/home/clawd"
BOT_TOKEN="${TELEGRAM_BOT_TOKEN}"
CHAT_ID="${ADMIN_CHAT_ID:-30289486}"
LOCK_FILE="/tmp/tmux-doctor.lock"
COOLDOWN=120  # 2min entre ações
LOG="/tmp/tmux-doctor.log"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG"; }

check_cooldown() {
    [ -f "$LOCK_FILE" ] || return 0
    local age=$(( $(date +%s) - $(stat -c %Y "$LOCK_FILE") ))
    [ "$age" -lt "$COOLDOWN" ] && return 1
    return 0
}

send_tg() {
    curl -s -m 10 "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
        -d chat_id="$CHAT_ID" -d text="$1" > /dev/null 2>&1
}

# Garantir trust dialog aceito no .claude.json
fix_trust() {
    python3 -c "
import json
path = '/home/clawd/.claude.json'
with open(path) as f:
    d = json.load(f)
projects = d.setdefault('projects', {})
entry = projects.setdefault('/home/clawd', {})
if not entry.get('hasTrustDialogAccepted'):
    entry['hasTrustDialogAccepted'] = True
    with open(path, 'w') as f:
        json.dump(d, f, indent=2)
    print('fixed')
else:
    print('ok')
" 2>/dev/null
}

# Capturar conteúdo atual do pane
pane_content() {
    tmux capture-pane -t "$SESSION" -p 2>/dev/null
}

# Verificar se sessão existe
if ! tmux has-session -t "$SESSION" 2>/dev/null; then
    log "Sessão '$SESSION' não existe — delegando ao mainbot.service"
    fix_trust
    # Delega criação ao systemd (evita corrida com mainbot.service/launcher.sh)
    if systemctl --user is-enabled --quiet mainbot.service 2>/dev/null; then
        systemctl --user restart mainbot.service
    elif [ -f "$MAINBOT_LAUNCHER" ]; then
        # Fallback: systemd não configurado
        bash "$MAINBOT_LAUNCHER" &
    else
        tmux new-session -d -s "$SESSION" -c "$WORKDIR" "$CLAUDE_BIN" $CLAUDE_ARGS
    fi
    sleep 10
    CONTENT=$(pane_content)
    if echo "$CONTENT" | grep -q "trust\|Trust\|Yes, I trust"; then
        tmux send-keys -t "$SESSION" Enter
        log "Trust dialog confirmado após criar sessão"
    fi
    log "Sessão mainbot recriada"
    exit 0
fi

CONTENT=$(pane_content)

# Check 0: Spinner preso (processo antigo de telegram-spinner.sh)
SPINNER_PID_FILE="/tmp/telegram-spinner.pid"
if [ -f "$SPINNER_PID_FILE" ]; then
    SPINNER_PID=$(cat "$SPINNER_PID_FILE" 2>/dev/null)
    if [ -n "$SPINNER_PID" ] && kill -0 "$SPINNER_PID" 2>/dev/null; then
        SPINNER_AGE=$(( $(date +%s) - $(stat -c %Y "$SPINNER_PID_FILE") ))
        if [ "$SPINNER_AGE" -gt 300 ]; then  # >5min = preso
            log "Spinner preso ($SPINNER_AGE s) — matando PID $SPINNER_PID"
            kill "$SPINNER_PID" 2>/dev/null
            rm -f "$SPINNER_PID_FILE" /tmp/telegram-spinner-msgid /tmp/telegram-spinner-text
        fi
    fi
fi

# Check 1: Trust dialog preso
if echo "$CONTENT" | grep -q "Yes, I trust this folder\|trust this folder"; then
    log "Trust dialog detectado — confirmando"
    fix_trust
    tmux send-keys -t "$SESSION" Enter
    exit 0
fi

# Check 2: MCP desconectou — Claude menciona isso e ficou idle
if echo "$CONTENT" | grep -q "MCP do Telegram desconectou\|MCP.*desconec"; then
    check_cooldown || exit 0
    log "MCP Telegram desconectado — reiniciando sessão mainbot"
    touch "$LOCK_FILE"
    fix_trust
    tmux kill-session -t "$SESSION" 2>/dev/null
    sleep 2
    if [ -f "$MAINBOT_LAUNCHER" ]; then
        bash "$MAINBOT_LAUNCHER" &
    else
        tmux new-session -d -s "$SESSION" -c "$WORKDIR" "$CLAUDE_BIN" $CLAUDE_ARGS
    fi
    sleep 10
    CONTENT=$(pane_content)
    if echo "$CONTENT" | grep -q "Yes, I trust this folder"; then
        tmux send-keys -t "$SESSION" Enter
    fi
    log "Sessão mainbot reiniciada por MCP desconectado"
    exit 0
fi

# Check 3: Claude idle (prompt ❯ sem atividade) mas MCP deveria estar ativo
# Verificar se o último evento foi muito tempo atrás via pane_content
# Se o pane tem "Baked" mas nenhum evento recente de telegram, pode estar morto
# Não reiniciamos agressivamente aqui — só logamos
if echo "$CONTENT" | grep -q "Baked for" && ! echo "$CONTENT" | grep -q "telegram"; then
    log "Claude idle sem atividade Telegram recente — monitorando"
fi

log "Sessão OK"
