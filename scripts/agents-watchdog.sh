#!/bin/bash
# agents-watchdog.sh — verifica e restart agentes que morreram ou estão em loop
# Rodar via cron: * * * * * bash /home/clawd/claude-tg-tmux/scripts/agents-watchdog.sh

SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="/tmp/watchdog"
LOG="${LOG_DIR}/watchdog.log"
STATE_DIR="${LOG_DIR}/state"
MAX_LOOP_SECONDS=300  # 5 min de loop = restart

mkdir -p "$LOG_DIR" "$STATE_DIR"

log() { echo "[$(date '+%H:%M:%S')] $*" >> "$LOG"; }

AGENTS="mainbot devbot execbot cronbot degenbot nanobot"

for agent in $AGENTS; do
  if ! tmux has-session -t "$agent" 2>/dev/null; then
    log "WARN: $agent DOWN — restarting..."
    case "$agent" in
      mainbot) bash "${SCRIPTS_DIR}/../nanobot/mainbot-launcher.sh" 2>/dev/null & ;;
      devbot) bash "${SCRIPTS_DIR}/devbot-launcher.sh" 2>/dev/null & ;;
      execbot) bash "${SCRIPTS_DIR}/execbot-launcher.sh" 2>/dev/null & ;;
      cronbot) bash "${SCRIPTS_DIR}/cronbot-launcher.sh" 2>/dev/null & ;;
      degenbot) bash "${SCRIPTS_DIR}/degenbot-launcher.sh" 2>/dev/null & ;;
      nanobot) bash "${SCRIPTS_DIR}/nanobot-launcher.sh" 2>/dev/null & ;;
    esac
    log "OK: $agent restarted"
    # Limpar estado de loop
    rm -f "${STATE_DIR}/${agent}.loop"
    continue
  fi

  # Verificar loop: captura pane e olha indicadores
  pane_content=$(tmux capture-pane -p -t "$agent" 2>/dev/null | tail -5)
  
  # Indicadores de loop
  loop_indicator=""
  if echo "$pane_content" | grep -qE "Brewed for|Sautéed for|Working for|Processing|◀▶|◀▶"; then
    # Extrair minutos se possível
    loop_indicator=$(echo "$pane_content" | grep -oE "[0-9]+m [0-9]+s|[0-9]+m|[0-9]+\.[0-9]+s" | tail -1)
  fi
  
  if [ -n "$loop_indicator" ]; then
    state_file="${STATE_DIR}/${agent}.loop"
    last_seen=""
    if [ -f "$state_file" ]; then
      last_seen=$(cat "$state_file")
    fi
    
    if [ "$last_seen" = "$loop_indicator" ]; then
      # Mesma situação — contar tempo
      count_file="${STATE_DIR}/${agent}.count"
      count=$(cat "$count_file" 2>/dev/null || echo 0)
      count=$((count + 60))  # assume 1 min entre checks
      echo "$count" > "$count_file"
      
      if [ "$count" -ge "$MAX_LOOP_SECONDS" ]; then
        log "CRIT: $agent LOOPING ($loop_indicator, ${count}s) — killing and restarting"
        tmux kill-session -t "$agent" 2>/dev/null
        sleep 2
        case "$agent" in
          mainbot) bash "${SCRIPTS_DIR}/../nanobot/mainbot-launcher.sh" 2>/dev/null & ;;
          devbot) bash "${SCRIPTS_DIR}/devbot-launcher.sh" 2>/dev/null & ;;
          execbot) bash "${SCRIPTS_DIR}/execbot-launcher.sh" 2>/dev/null & ;;
          cronbot) bash "${SCRIPTS_DIR}/cronbot-launcher.sh" 2>/dev/null & ;;
          degenbot) bash "${SCRIPTS_DIR}/degenbot-launcher.sh" 2>/dev/null & ;;
          nanobot) bash "${SCRIPTS_DIR}/nanobot-launcher.sh" 2>/dev/null & ;;
        esac
        rm -f "$state_file" "$count_file"
        log "OK: $agent restarted after loop detection"
      fi
    else
      # Situação mudou — reset
      echo "$loop_indicator" > "$state_file"
      echo 60 > "${STATE_DIR}/${agent}.count"
    fi
  else
    # Sem indicador de loop — limpar estado
    rm -f "${STATE_DIR}/${agent}.loop" "${STATE_DIR}/${agent}.count"
  fi
done

log "=== watchdog check done $(date '+%H:%M:%S') ==="
