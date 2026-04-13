#!/bin/bash
# start-all-agents.sh — inicializa todo o sistema multi-agent
# Uso: bash start-all-agents.sh [--no-mainbot]

SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log() { echo "[$(date '+%H:%M:%S')] $*"; }

# Setup do bus
log "Configurando estrutura do bus..."
bash "${SCRIPTS_DIR}/bus-setup.sh"

# Mainbot (opcional — normalmente já gerenciado pelo systemd)
if [[ "$1" != "--no-mainbot" ]]; then
  log "Mainbot: gerenciado pelo systemd (claude-mainbot.service) — skip"
fi

# Devbot
log "Iniciando devbot (Opus 4.6)..."
bash "${SCRIPTS_DIR}/devbot-launcher.sh"

# Execbot
log "Iniciando execbot (Sonnet 4.6)..."
bash "${SCRIPTS_DIR}/execbot-launcher.sh"

# Cronbot
log "Iniciando cronbot (monitor shell)..."
bash "${SCRIPTS_DIR}/cronbot-launcher.sh"

sleep 2
log "=== Sessões ativas ==="
/usr/bin/tmux list-sessions 2>/dev/null || echo "Nenhuma sessão tmux ativa"
