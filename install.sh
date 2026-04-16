#!/bin/bash
# claude-tg-tmux — Installer
# Uso: bash install.sh
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLAUDE_CONFIG="$HOME/.claude"
HOOKS_DST="$CLAUDE_CONFIG/hooks"
TG_PLUGIN_DIR="$CLAUDE_CONFIG/channels/telegram"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()  { echo -e "${GREEN}[+]${NC} $1"; }
warn()  { echo -e "${YELLOW}[!]${NC} $1"; }
error() { echo -e "${RED}[x]${NC} $1"; exit 1; }

echo ""
echo "╔══════════════════════════════════════╗"
echo "║      claude-tg-tmux  installer       ║"
echo "╚══════════════════════════════════════╝"
echo ""

# ── 1. Carregar ou criar .env ──────────────────────────────────────────────
if [ ! -f "$SCRIPT_DIR/.env" ]; then
    cp "$SCRIPT_DIR/.env.example" "$SCRIPT_DIR/.env"
    warn ".env criado — preencha os valores e rode novamente."
    echo "  $SCRIPT_DIR/.env"
    exit 0
fi

source "$SCRIPT_DIR/.env"

[ -z "$TELEGRAM_BOT_TOKEN" ] && error "TELEGRAM_BOT_TOKEN não definido no .env"
[ -z "$ALLOWED_USER_IDS" ]   && error "ALLOWED_USER_IDS não definido no .env"
ADMIN_CHAT_ID="${ADMIN_CHAT_ID:-$(echo "$ALLOWED_USER_IDS" | cut -d, -f1)}"

# ── 2. Dependências ────────────────────────────────────────────────────────
info "Verificando dependências..."
command -v claude  >/dev/null || error "claude CLI não encontrado. Instale via npm."
command -v tmux    >/dev/null || error "tmux não encontrado. Instale: sudo apt install tmux"
command -v ffmpeg  >/dev/null || warn  "ffmpeg não encontrado — TTS ficará desabilitado."
command -v whisper >/dev/null || warn  "whisper não encontrado — STT ficará desabilitado."
command -v jq      >/dev/null || error "jq não encontrado. Instale: sudo apt install jq"
command -v python3 >/dev/null || error "python3 não encontrado."

# ── 3. Hooks ───────────────────────────────────────────────────────────────
info "Instalando hooks em $HOOKS_DST..."
mkdir -p "$HOOKS_DST"
cp "$SCRIPT_DIR"/hooks/*.sh "$HOOKS_DST/"
chmod +x "$HOOKS_DST"/*.sh

# Substituir caminhos hard-coded nos hooks
for f in "$HOOKS_DST"/*.sh; do
    sed -i "s|/home/clawd/.claude/hooks|$HOOKS_DST|g" "$f"
    sed -i "s|/home/clawd/clawd/bigquery-rag|${BQ_LOG_SCRIPT%/*}|g" "$f"
    sed -i "s|sk_f072918db49a1aed2e529d81351ea7adf26e19bf55ca6d21|${ELEVENLABS_API_KEY:-DISABLED}|g" "$f"
    if [ -n "$ELEVENLABS_VOICE_ID" ]; then
        sed -i "s|30D0RicpFBZ55TdpseEa|$ELEVENLABS_VOICE_ID|g" "$f"
    fi
done

# ── 4. Configuração do plugin Telegram ────────────────────────────────────
info "Configurando plugin Telegram..."
mkdir -p "$TG_PLUGIN_DIR"
echo "TELEGRAM_BOT_TOKEN=$TELEGRAM_BOT_TOKEN" > "$TG_PLUGIN_DIR/.env"

# ── 5. Pairing de usuários permitidos ─────────────────────────────────────
PAIRING_FILE="$CLAUDE_CONFIG/channels/telegram/access.json"
if [ ! -f "$PAIRING_FILE" ]; then
    ALLOWED_ARRAY=$(echo "$ALLOWED_USER_IDS" | python3 -c "
import sys
ids = sys.stdin.read().strip().split(',')
print('[' + ','.join(f'\"{i.strip()}\"' for i in ids if i.strip()) + ']')
")
    cat > "$PAIRING_FILE" << EOF
{
  "dmPolicy": "allowlist",
  "allowFrom": $ALLOWED_ARRAY
}
EOF
    info "access.json criado com users: $ALLOWED_USER_IDS"
fi

# ── 6. settings.json (merge de hooks) ─────────────────────────────────────
info "Configurando hooks no settings.json..."
SETTINGS="$CLAUDE_CONFIG/settings.json"
TEMPLATE="$SCRIPT_DIR/telegram/settings.json.template"

python3 << PYEOF
import json, os

install_dir = "$HOOKS_DST"
template_path = "$TEMPLATE"
settings_path = "$SETTINGS"

with open(template_path) as f:
    tmpl_str = f.read().replace("{{INSTALL_DIR}}", install_dir)
new_hooks = json.loads(tmpl_str).get("hooks", {})
new_perms = json.loads(tmpl_str).get("permissions", {})

cfg = {}
if os.path.exists(settings_path):
    with open(settings_path) as f:
        cfg = json.load(f)

# Merge permissions
existing_allow = cfg.get("permissions", {}).get("allow", [])
for p in new_perms.get("allow", []):
    if p not in existing_allow:
        existing_allow.append(p)
cfg.setdefault("permissions", {})["allow"] = existing_allow

# Set hooks (overwrite)
cfg["hooks"] = {**cfg.get("hooks", {}), **new_hooks}

with open(settings_path, "w") as f:
    json.dump(cfg, f, indent=2, ensure_ascii=False)
print("OK")
PYEOF

# ── 7. Serviços systemd ───────────────────────────────────────────────────
info "Instalando serviços systemd..."
SYSTEMD_USER="$HOME/.config/systemd/user"
mkdir -p "$SYSTEMD_USER"

sed "s|%h/claude-tg-tmux|$SCRIPT_DIR|g" \
    "$SCRIPT_DIR/systemd/mainbot.service" > "$SYSTEMD_USER/mainbot.service"

sed "s|%h/claude-tg-tmux|$SCRIPT_DIR|g" \
    "$SCRIPT_DIR/systemd/mainbot-failure-notify.service" > "$SYSTEMD_USER/mainbot-failure-notify.service"

cp "$SCRIPT_DIR/systemd/agents-boot.service" "$SYSTEMD_USER/agents-boot.service"

# claude-watchdog (mantém mainbot vivo e com plugin:telegram)
sed "s|%h/claude-tg-tmux|$SCRIPT_DIR|g" \
    "$SCRIPT_DIR/systemd/claude-watchdog.service" > "$SYSTEMD_USER/claude-watchdog.service"

# Se havia serviço de sistema (instalação antiga), desabilitar e remover
if systemctl is-active --quiet claude-watchdog.service 2>/dev/null; then
    warn "Serviço de sistema claude-watchdog detectado — migrando para serviço de usuário..."
    sudo systemctl stop claude-watchdog.service 2>/dev/null || true
    sudo systemctl disable claude-watchdog.service 2>/dev/null || true
fi

# tmux-doctor (auto-fix mainbot)
cp "$SCRIPT_DIR/systemd/tmux-doctor.service" "$SYSTEMD_USER/tmux-doctor.service"
cp "$SCRIPT_DIR/systemd/tmux-doctor.timer"   "$SYSTEMD_USER/tmux-doctor.timer"

# tmux-doctor script
mkdir -p "$HOME/.local/bin"
cp "$SCRIPT_DIR/scripts/tmux-doctor.sh" "$HOME/.local/bin/tmux-doctor.sh"
chmod +x "$HOME/.local/bin/tmux-doctor.sh"

# Criar dirs do bus
mkdir -p "$HOME/.claude/bus/tasks" "$HOME/.claude/bus/status" "$HOME/.claude/bus/promises"
chmod +x "$SCRIPT_DIR"/scripts/*.sh

# Injetar .env no serviço
sed -i "/\[Service\]/a EnvironmentFile=$SCRIPT_DIR/.env" "$SYSTEMD_USER/mainbot.service"

# ── 7b. Skills ─────────────────────────────────────────────────────────────
if [ -d "$SCRIPT_DIR/skills" ]; then
    info "Instalando skills em $CLAUDE_CONFIG/skills/..."
    mkdir -p "$CLAUDE_CONFIG/skills"
    for skill_dir in "$SCRIPT_DIR/skills"/*/; do
        skill_name=$(basename "$skill_dir")
        cp -r "$skill_dir" "$CLAUDE_CONFIG/skills/$skill_name"
        info "  skill: $skill_name"
    done
fi

systemctl --user daemon-reload
systemctl --user enable mainbot.service agents-boot.service tmux-doctor.timer claude-watchdog.service
systemctl --user start mainbot.service agents-boot.service tmux-doctor.timer claude-watchdog.service

sleep 3
STATUS=$(systemctl --user is-active mainbot.service)
if [ "$STATUS" = "active" ]; then
    info "mainbot.service ativo ✓"
else
    warn "mainbot.service status: $STATUS — verifique: journalctl --user -u mainbot -n 20"
fi

STATUS_AGENTS=$(systemctl --user is-active agents-boot.service)
if [ "$STATUS_AGENTS" = "active" ]; then
    info "agents-boot.service ativo ✓ (devbot, execbot, cronbot)"
else
    warn "agents-boot.service status: $STATUS_AGENTS — verifique: journalctl --user -u agents-boot -n 20"
fi

STATUS_DOCTOR=$(systemctl --user is-active tmux-doctor.timer)
if [ "$STATUS_DOCTOR" = "active" ]; then
    info "tmux-doctor.timer ativo ✓ (auto-fix mainbot a cada 2min)"
else
    warn "tmux-doctor.timer status: $STATUS_DOCTOR"
fi

STATUS_WATCHDOG=$(systemctl --user is-active claude-watchdog.service)
if [ "$STATUS_WATCHDOG" = "active" ]; then
    info "claude-watchdog.service ativo ✓ (reinicia mainbot se cair ou perder plugin:telegram)"
else
    warn "claude-watchdog.service status: $STATUS_WATCHDOG — verifique: journalctl --user -u claude-watchdog -n 20"
fi

# ── 8. Registrar comandos no bot Telegram ────────────────────────────────
info "Registrando comandos no bot Telegram..."
curl -s "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/setMyCommands" \
  -d 'commands=[
    {"command":"help","description":"Lista os comandos disponíveis"},
    {"command":"syscheck","description":"Status do mainbot e OpenClaw"},
    {"command":"model","description":"Modelo Claude atual"},
    {"command":"tts","description":"Liga/desliga voz (on|off)"},
    {"command":"compact","description":"Compacta o contexto da conversa"},
    {"command":"new","description":"Inicia nova conversa"},
    {"command":"restart","description":"Reinicia a sessão mainbot"},
    {"command":"setkey","description":"Salva API key nas skills (admin)"},
    {"command":"listkeys","description":"Lista API keys configuradas (admin)"}
  ]' | grep -q '"ok":true' && info "Comandos registrados ✓" || warn "Falha ao registrar comandos — rode manualmente depois"

# ── 9. Resumo ─────────────────────────────────────────────────────────────
echo ""
echo "╔══════════════════════════════════════════════╗"
echo "║           Instalação concluída ✓             ║"
echo "╚══════════════════════════════════════════════╝"
echo ""
echo "  Sessão tmux:  tmux attach -t ${SESSION_NAME:-mainbot}"
echo "  Status:       systemctl --user status mainbot"
echo "  Logs:         journalctl --user -u mainbot -f"
echo ""
echo "  TTS:          ${TTS_ENABLED:-true}"
echo "  BQ logging:   ${BQ_ENABLED:-false}"
echo ""
