#!/bin/bash
# start-all-agents.sh — inicializa sub-agentes do mainbot (claude-tg-tmux)
#
# ARQUITETURA:
#   mainbot tmux (@dgenmainbot)  → systemd claude-cli.service → start-claude-tmux.sh
#   sub-agentes (devbot, etc)    → este script
#   OpenClaw/Degenerado          → PM2 clawdbot-gw (@mentordegenbot) — NÃO gerenciado aqui
#
# Uso: bash start-all-agents.sh

SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log() { echo "[$(date '+%H:%M:%S')] $*"; }

# Setup do bus
log "Configurando estrutura do bus..."
bash "${SCRIPTS_DIR}/bus-setup.sh"

# Mainbot: gerenciado pelo systemd (claude-cli.service) via start-claude-tmux.sh
log "Mainbot: systemd claude-cli.service — não iniciar aqui"

# Devbot
log "Iniciando devbot (Opus 4.6)..."
bash "${SCRIPTS_DIR}/devbot-launcher.sh"

# Execbot
log "Iniciando execbot (Sonnet 4.6)..."
bash "${SCRIPTS_DIR}/execbot-launcher.sh"

# Cronbot
log "Iniciando cronbot (monitor shell)..."
bash "${SCRIPTS_DIR}/cronbot-launcher.sh"

# Degenbot
log "Iniciando degenbot (Opus 4.6)..."
bash "${SCRIPTS_DIR}/degenbot-launcher.sh"

# Spawnbot
log "Iniciando spawnbot (Sonnet 4.6)..."
bash "${SCRIPTS_DIR}/spawnbot-launcher.sh"

# NOTA: nanobot foi removido do sistema.
# mainbot tmux = bot Telegram principal (@dgenmainbot), gerenciado pelo systemd.
# Degenerado/OpenClaw (@mentordegenbot) = PM2 clawdbot-gw — NÃO gerenciado aqui.

sleep 2
log "=== Sessões ativas ==="
/usr/bin/tmux list-sessions 2>/dev/null || echo "Nenhuma sessão tmux ativa"
