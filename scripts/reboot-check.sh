#!/bin/bash
# reboot-check.sh — verifica todos os agentes após reboot
# Rodar via systemd after=network-online.target

SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="/tmp/reboot-check"
REPORT_FILE="${LOG_DIR}/report-$(date '+%Y%m%d-%H%M%S').log"

mkdir -p "$LOG_DIR"

log() { 
  echo "[$(date '+%H:%M:%S')] $*" | tee -a "$REPORT_FILE"
}

AGENTS="mainbot devbot execbot cronbot degenbot"

log "=== REBOOT CHECK $(date) ==="

all_ok=true

for agent in $AGENTS; do
  if tmux has-session -t "$agent" 2>/dev/null; then
    log "✅ $agent is UP"
  else
    log "❌ $agent is DOWN — restarting..."
    case "$agent" in
      mainbot) bash "${SCRIPTS_DIR}/mainbot-launcher.sh" 2>/dev/null & ;;
      devbot) bash "${SCRIPTS_DIR}/devbot-launcher.sh" 2>/dev/null & ;;
      execbot) bash "${SCRIPTS_DIR}/execbot-launcher.sh" 2>/dev/null & ;;
      cronbot) bash "${SCRIPTS_DIR}/cronbot-launcher.sh" 2>/dev/null & ;;
      degenbot) bash "${SCRIPTS_DIR}/degenbot-launcher.sh" 2>/dev/null & ;;


    esac
    all_ok=false
  fi
done

sleep 15

log "=== STATUS AFTER 5s ==="
for agent in $AGENTS; do
  if tmux has-session -t "$agent" 2>/dev/null; then
    log "✅ $agent"
  else
    log "❌ $agent STILL DOWN"
  fi
done

if $all_ok; then
  log "=== ALL AGENTS UP ==="
else
  log "=== SOME AGENTS REQUIRED RESTART ==="
fi

# Notificar mainbot
if tmux has-session -t mainbot 2>/dev/null; then
  tmux send-keys -t mainbot "reboot-check complete" Enter 2>/dev/null
fi

# Verificar OpenClaw Gateway
if pgrep -f "openclaw-gateway" > /dev/null; then
  log "✅ openclaw-gateway is RUNNING"
else
  log "❌ openclaw-gateway is DOWN — restarting..."
        systemctl --user restart openclaw-gateway 2>/dev/null
fi

log "Report: $REPORT_FILE"
