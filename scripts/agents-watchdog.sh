#!/bin/bash
# agents-watchdog.sh — verifica e restart agentes que morreram
# Rodar via cron: * * * * * bash /home/clawd/claude-tg-tmux/scripts/agents-watchdog.sh

SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG="/tmp/watchdog.log"

log() { echo "[$(date '+%H:%M:%S')] $*" >> "$LOG"; }

AGENTS="mainbot devbot execbot cronbot degenbot nanobot"

for agent in $AGENTS; do
  if ! tmux has-session -t "$agent" 2>/dev/null; then
    log "WARN: $agent down — restarting..."
    case "$agent" in
      mainbot) bash "${SCRIPTS_DIR}/../nanobot/mainbot-launcher.sh 2>/dev/null & ;;
      devbot) bash "${SCRIPTS_DIR}/devbot-launcher.sh 2>/dev/null & ;;
      execbot) bash "${SCRIPTS_DIR}/execbot-launcher.sh 2>/dev/null & ;;
      cronbot) bash "${SCRIPTS_DIR}/cronbot-launcher.sh 2>/dev/null & ;;
      degenbot) bash "${SCRIPTS_DIR}/degenbot-launcher.sh 2>/dev/null & ;;
      nanobot) bash "${SCRIPTS_DIR}/nanobot-launcher.sh 2>/dev/null & ;;
    esac
    log "OK: $agent restarted"
  fi
done
