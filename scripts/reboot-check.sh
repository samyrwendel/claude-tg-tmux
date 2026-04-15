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

NATIVE_AGENTS="mainbot devbot execbot cronbot degenbot spawnbot"
WATCHDOG_REGISTRY="${HOME}/.claude/bus/watchdog.registry"

log "=== REBOOT CHECK $(date) ==="

all_ok=true

# Agentes nativos
for agent in $NATIVE_AGENTS; do
  if tmux has-session -t "$agent" 2>/dev/null; then
    log "✅ $agent is UP"
  else
    log "❌ $agent is DOWN — restarting..."
    launcher="${SCRIPTS_DIR}/${agent}-launcher.sh"
    if [ -f "$launcher" ]; then
      bash "$launcher" 2>/dev/null &
    fi
    all_ok=false
  fi
done

# Agentes spawnados (watchdog.registry)
if [ -f "$WATCHDOG_REGISTRY" ]; then
  while IFS= read -r agent; do
    [ -z "$agent" ] && continue
    if tmux has-session -t "$agent" 2>/dev/null; then
      log "✅ $agent (spawned) is UP"
    else
      log "❌ $agent (spawned) is DOWN — restarting..."
      launcher="${SCRIPTS_DIR}/${agent}-launcher.sh"
      if [ -f "$launcher" ]; then
        bash "$launcher" 2>/dev/null &
      else
        log "  sem launcher para $agent — ignorando"
      fi
      all_ok=false
    fi
  done < "$WATCHDOG_REGISTRY"
fi

sleep 15

log "=== STATUS AFTER 15s ==="
ALL_AGENTS="$NATIVE_AGENTS"
[ -f "$WATCHDOG_REGISTRY" ] && ALL_AGENTS="$ALL_AGENTS $(grep -v '^#' "$WATCHDOG_REGISTRY" | tr '\n' ' ')"
for agent in $ALL_AGENTS; do
  [ -z "$agent" ] && continue
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

# Notificar mainbot via file-based alert (não mistura com input do Samyr)
bash "${SCRIPTS_DIR}/alert-mainbot.sh" "[REBOOT-CHECK] Sistema reiniciado. Agentes verificados. Relatório: ${REPORT_FILE}" 2>/dev/null

# Verificar OpenClaw Gateway
if pgrep -f "openclaw-gateway" > /dev/null; then
  log "✅ openclaw-gateway is RUNNING"
else
  log "❌ openclaw-gateway is DOWN — restarting..."
        systemctl --user restart openclaw-gateway 2>/dev/null
fi

log "Report: $REPORT_FILE"
