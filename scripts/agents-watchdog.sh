#!/bin/bash
# agents-watchdog.sh — verifica e restart agentes que morreram ou estão em loop
# Notifica mainbot sobre ações tomadas
# Rodar via cron: * * * * * bash /home/clawd/claude-tg-tmux/scripts/agents-watchdog.sh

SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="/tmp/watchdog"
LOG="${LOG_DIR}/watchdog.log"
STATE_DIR="${LOG_DIR}/state"
ALERT_DIR="/tmp/cronbot/alerts"
TASK_DIR="${LOG_DIR}/tasks"
MAX_LOOP_SECONDS=300  # 5 min de loop = restart

mkdir -p "$LOG_DIR" "$STATE_DIR" "$ALERT_DIR" "$TASK_DIR"

log() { echo "[$(date '+%H:%M:%S')] $*" >> "$LOG"; }

notify_mainbot() {
  local msg="$1"
  local alert_file="${ALERT_DIR}/mainbot-$(date '+%Y%m%d-%H%M%S').alert"
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $msg" > "$alert_file"
  log "ALERT queued for mainbot: $msg"
  # Escreve em /tmp/cronbot/alerts para o hook cronbot-alerts.sh drenar
  bash "$(dirname "${BASH_SOURCE[0]}")/alert-mainbot.sh" "$msg" 2>/dev/null
}

save_task_state() {
  local agent="$1"
  local pane_file="${TASK_DIR}/${agent}.pane"
  local task_file="${TASK_DIR}/${agent}.task"
  
  # Capturar contexto atual do pane
  tmux capture-pane -p -t "$agent" 2>/dev/null | tail -30 > "$pane_file"
  
  # Gerar task file com timestamp e contexto
  cat > "$task_file" << EOF
[$(date '+%Y-%m-%d %H:%M:%S')] AGENTE $agent FOI REINICIADO PELO WATCHDOG (LOOP/DOWN)
Contexto anterior:
$(cat "$pane_file")
---
Ao reiniciar: leia o arquivo /tmp/watchdog/tasks/${agent}.pane para ver o que você estava fazendo.
Se não conseguir retomar, notifique o mainbot com esse contexto.
EOF
  log "Task state saved for $agent"
}

WATCHDOG_REGISTRY="${HOME}/.claude/bus/watchdog.registry"

# Agentes nativos + agentes spawnados dinamicamente
NATIVE_AGENTS="mainbot devbot execbot cronbot degenbot"
SPAWNED_AGENTS=""
if [ -f "$WATCHDOG_REGISTRY" ]; then
  SPAWNED_AGENTS=$(grep -v '^#' "$WATCHDOG_REGISTRY" 2>/dev/null | tr '\n' ' ')
fi
AGENTS="${NATIVE_AGENTS} ${SPAWNED_AGENTS}"

for agent in $AGENTS; do
  if ! tmux has-session -t "$agent" 2>/dev/null; then
    log "WARN: $agent DOWN — restarting..."
    save_task_state "$agent"
    case "$agent" in
      mainbot)
        # Delega ao systemd (evita corrida com mainbot.service)
        systemctl --user restart mainbot.service 2>/dev/null &
        notify_mainbot "$agent went DOWN. Task state saved. Restarting via mainbot.service."
        ;;
      devbot) 
        bash "${SCRIPTS_DIR}/devbot-launcher.sh" 2>/dev/null &
        notify_mainbot "$agent went DOWN. Task state saved. Restarting."
        ;;
      execbot) 
        bash "${SCRIPTS_DIR}/execbot-launcher.sh" 2>/dev/null &
        notify_mainbot "$agent went DOWN. Task state saved. Restarting."
        ;;
      cronbot) 
        bash "${SCRIPTS_DIR}/cronbot-launcher.sh" 2>/dev/null &
        notify_mainbot "$agent went DOWN. Task state saved. Restarting."
        ;;
      degenbot)
        bash "${SCRIPTS_DIR}/degenbot-launcher.sh" 2>/dev/null &
        notify_mainbot "$agent went DOWN. Task state saved. Restarting."
        ;;
      *)
        # Agente spawnado dinamicamente — launcher gerado pelo spawnbot
        local_launcher="${SCRIPTS_DIR}/${agent}-launcher.sh"
        if [ -f "$local_launcher" ]; then
          bash "$local_launcher" 2>/dev/null &
          notify_mainbot "$agent (spawned) went DOWN. Restarting via ${agent}-launcher.sh."
        else
          notify_mainbot "$agent went DOWN but no launcher found — skipping restart."
        fi
        ;;
    esac
    log "OK: $agent restarted"
    rm -f "${STATE_DIR}/${agent}.loop" "${STATE_DIR}/${agent}.count"
    continue
  fi

  # Verificar loop
  pane_content=$(tmux capture-pane -p -t "$agent" 2>/dev/null | tail -5)
  
  loop_indicator=""
  if echo "$pane_content" | grep -qE "Brewed for|Sautéed for|Working for|Processing|◀▶"; then
    loop_indicator=$(echo "$pane_content" | grep -oE "[0-9]+m [0-9]+s|[0-9]+m|[0-9]+\.[0-9]+s" | tail -1)
  fi
  
  if [ -n "$loop_indicator" ]; then
    state_file="${STATE_DIR}/${agent}.loop"
    last_seen=""
    [ -f "$state_file" ] && last_seen=$(cat "$state_file")
    
    if [ "$last_seen" = "$loop_indicator" ]; then
      count_file="${STATE_DIR}/${agent}.count"
      count=$(cat "$count_file" 2>/dev/null || echo 0)
      count=$((count + 60))
      echo "$count" > "$count_file"
      
      if [ "$count" -ge "$MAX_LOOP_SECONDS" ]; then
        log "CRIT: $agent LOOPING ($loop_indicator, ${count}s) — killing and restarting"
        save_task_state "$agent"
        tmux kill-session -t "$agent" 2>/dev/null
        sleep 2
        case "$agent" in
          mainbot)
            # Delega ao systemd (evita corrida com mainbot.service)
            systemctl --user restart mainbot.service 2>/dev/null &
            notify_mainbot "$agent was LOOPING for ${count}s. Task state saved. Restarted via mainbot.service."
            ;;
          devbot) 
            bash "${SCRIPTS_DIR}/devbot-launcher.sh" 2>/dev/null &
            notify_mainbot "$agent was LOOPING for ${count}s. Task state saved. Restarted."
            ;;
          execbot) 
            bash "${SCRIPTS_DIR}/execbot-launcher.sh" 2>/dev/null &
            notify_mainbot "$agent was LOOPING for ${count}s. Task state saved. Restarted."
            ;;
          cronbot) 
            bash "${SCRIPTS_DIR}/cronbot-launcher.sh" 2>/dev/null &
            notify_mainbot "$agent was LOOPING for ${count}s. Task state saved. Restarted."
            ;;
          degenbot)
            bash "${SCRIPTS_DIR}/degenbot-launcher.sh" 2>/dev/null &
            notify_mainbot "$agent was LOOPING for ${count}s. Task state saved. Restarted."
            ;;
          *)
            local_launcher="${SCRIPTS_DIR}/${agent}-launcher.sh"
            if [ -f "$local_launcher" ]; then
              bash "$local_launcher" 2>/dev/null &
              notify_mainbot "$agent (spawned) was LOOPING for ${count}s. Restarted."
            fi
            ;;
        esac
        rm -f "$state_file" "$count_file"
        log "OK: $agent restarted after loop detection"
      fi
    else
      echo "$loop_indicator" > "$state_file"
      echo 60 > "${STATE_DIR}/${agent}.count"
    fi
  else
    rm -f "${STATE_DIR}/${agent}.loop" "${STATE_DIR}/${agent}.count"
  fi
done

log "=== watchdog check done $(date '+%H:%M:%S') ==="
