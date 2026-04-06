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
    "$SCRIPT_DIR/systemd/nanobot.service" > "$SYSTEMD_USER/nanobot.service"

sed "s|%h/claude-tg-tmux|$SCRIPT_DIR|g" \
    "$SCRIPT_DIR/systemd/nanobot-failure-notify.service" > "$SYSTEMD_USER/nanobot-failure-notify.service"

# Injetar .env no serviço
sed -i "/\[Service\]/a EnvironmentFile=$SCRIPT_DIR/.env" "$SYSTEMD_USER/nanobot.service"

systemctl --user daemon-reload
systemctl --user enable nanobot.service
systemctl --user start nanobot.service

sleep 3
STATUS=$(systemctl --user is-active nanobot.service)
if [ "$STATUS" = "active" ]; then
    info "nanobot.service ativo ✓"
else
    warn "nanobot.service status: $STATUS — verifique: journalctl --user -u nanobot -n 20"
fi

# ── 8. Resumo ─────────────────────────────────────────────────────────────
echo ""
echo "╔══════════════════════════════════════════════╗"
echo "║           Instalação concluída ✓             ║"
echo "╚══════════════════════════════════════════════╝"
echo ""
echo "  Sessão tmux:  tmux attach -t ${SESSION_NAME:-nanobot}"
echo "  Status:       systemctl --user status nanobot"
echo "  Logs:         journalctl --user -u nanobot -f"
echo ""
echo "  TTS:          ${TTS_ENABLED:-true}"
echo "  BQ logging:   ${BQ_ENABLED:-false}"
echo ""
