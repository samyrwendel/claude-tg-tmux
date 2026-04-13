#!/bin/bash
# cronbot-monitor.sh — loop de monitoramento do barramento multi-agent
# Roda como shell script dentro da sessão tmux 'cronbot'
# NÃO é um processo Claude — custo zero quando tudo está ok

BUS_DIR="${HOME}/.claude/bus"
MAINBOT="mainbot"
LOG="/tmp/cronbot-monitor.log"
TASK_TIMEOUT=300       # 5 minutos sem update = travado
PROMISE_CHECK=900      # checar promises a cada 15min
CRON_CHECK=3600        # checar crontab a cada 1h
SESSIONS_TO_WATCH="devbot execbot"

log() { echo "[$(TZ=America/Manaus date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG"; }

inject_mainbot() {
  local msg="$1"
  if /usr/bin/tmux has-session -t "$MAINBOT" 2>/dev/null; then
    /usr/bin/tmux send-keys -t "$MAINBOT" "$msg" Enter
    log "INJECT → mainbot: $msg"
  else
    log "WARN: mainbot não encontrado — não pôde injetar: $msg"
  fi
}

check_tasks() {
  local now
  now=$(date +%s)

  for task_file in "${BUS_DIR}/tasks/"*.task; do
    [ -f "$task_file" ] || continue
    TASK_ID=$(basename "$task_file" .task)
    LOCK_FILE="${BUS_DIR}/tasks/${TASK_ID}.task.lock"
    STATUS_FILE="${BUS_DIR}/status/${TASK_ID}.status"

    # Task com lock = em processamento: checar timeout
    if [ -f "$LOCK_FILE" ]; then
      LOCK_AGE=$((now - $(stat -c %Y "$LOCK_FILE" 2>/dev/null || echo $now)))
      if [ "$LOCK_AGE" -gt "$TASK_TIMEOUT" ]; then
        AGENT=$(grep "^AGENT:" "$task_file" | cut -d' ' -f2)
        TAREFA=$(grep "^TAREFA:" "$task_file" | cut -d' ' -f2-)
        inject_mainbot "[CRONBOT] ⚠️ ${AGENT}bot sem resposta na task ${TASK_ID} (${LOCK_AGE}s). Tarefa: ${TAREFA}"
      fi
      continue
    fi

    # Status DONE ou FAILED sem lock = agente concluiu
    if [ -f "$STATUS_FILE" ]; then
      STATUS=$(grep "^STATUS:" "$STATUS_FILE" | cut -d' ' -f2)
      RESUMO=$(grep "^RESUMO:" "$STATUS_FILE" | cut -d' ' -f2-)
      COMMIT=$(grep "^COMMIT:" "$STATUS_FILE" | cut -d' ' -f2-)
      AGENT=$(grep "^AGENT:" "$task_file" | cut -d' ' -f2)

      if [ "$STATUS" = "DONE" ]; then
        MSG="[${AGENT^^}BOT] Task ${TASK_ID} CONCLUÍDA. ${RESUMO}"
        [ -n "$COMMIT" ] && [ "$COMMIT" != "-" ] && MSG="${MSG} (commit: ${COMMIT})"
        inject_mainbot "$MSG"
      elif [ "$STATUS" = "FAILED" ]; then
        inject_mainbot "[${AGENT^^}BOT] ❌ Task ${TASK_ID} FALHOU: ${RESUMO}"
      fi

      # Cleanup após notificar
      rm -f "$task_file" "$LOCK_FILE" "$STATUS_FILE"
      log "Cleanup após notificação: ${TASK_ID}"
    fi
  done
}

check_promises() {
  local results
  results=$(bash "${HOME}/claude-tg-tmux/scripts/bus-promise.sh" check 2>/dev/null)
  [ "$results" = "OK" ] || [ -z "$results" ] && return

  while IFS='|' read -r tipo slug deadline contexto; do
    if [ "$tipo" = "VENCIDA" ]; then
      inject_mainbot "[CRONBOT] 🔴 Promise VENCIDA: '${contexto}' (era ${deadline}). Avisar Samyr."
    elif [ "$tipo" = "URGENTE" ]; then
      inject_mainbot "[CRONBOT] ⏰ Promise urgente em < 24h: '${contexto}' (vence ${deadline})."
    fi
  done <<< "$results"
}

check_sessions() {
  for session in $SESSIONS_TO_WATCH; do
    if ! /usr/bin/tmux has-session -t "$session" 2>/dev/null; then
      log "Sessão $session não encontrada — tentando reiniciar"
      LAUNCHER="${HOME}/claude-tg-tmux/scripts/${session}-launcher.sh"
      if [ -f "$LAUNCHER" ]; then
        bash "$LAUNCHER" &
        inject_mainbot "[CRONBOT] ⚠️ Sessão ${session} estava morta — reiniciando."
      else
        inject_mainbot "[CRONBOT] ⚠️ Sessão ${session} morta e sem launcher. Verificar manualmente."
      fi
    fi
  done
}

check_crontab() {
  local count
  count=$(crontab -l 2>/dev/null | grep -v "^#" | grep -v "^$" | wc -l)
  log "Crontab check: ${count} jobs ativos"
  # Checar jobs críticos
  if ! crontab -l 2>/dev/null | grep -q "dream-cycle"; then
    inject_mainbot "[CRONBOT] ⚠️ dream-cycle não encontrado no crontab!"
  fi
  if ! crontab -l 2>/dev/null | grep -q "proactive-checkin"; then
    inject_mainbot "[CRONBOT] ⚠️ proactive-checkin não encontrado no crontab!"
  fi
}

log "=== cronbot-monitor iniciado (PID $$) ==="

LAST_PROMISE_CHECK=0
LAST_CRON_CHECK=0

while true; do
  sleep 60

  NOW=$(date +%s)

  # Tasks: checar a cada ciclo (1min)
  check_tasks

  # Sessions: checar a cada ciclo (1min)
  check_sessions

  # Promises: a cada 15min
  if [ $((NOW - LAST_PROMISE_CHECK)) -ge $PROMISE_CHECK ]; then
    check_promises
    LAST_PROMISE_CHECK=$NOW
  fi

  # Crontab: a cada 1h
  if [ $((NOW - LAST_CRON_CHECK)) -ge $CRON_CHECK ]; then
    check_crontab
    LAST_CRON_CHECK=$NOW
  fi
done
