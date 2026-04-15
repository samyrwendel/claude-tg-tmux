#!/bin/bash
# cronbot-monitor.sh — loop de monitoramento do barramento multi-agent
# Roda como shell script dentro da sessão tmux 'cronbot'
# NÃO é um processo Claude — custo zero quando tudo está ok

BUS_DIR="${HOME}/.claude/bus"
MAINBOT="mainbot"
LOG="/tmp/cronbot-monitor.log"
TASK_TIMEOUT=1800      # 30 minutos sem update = travado (tasks de código levam tempo)
PROMISE_CHECK=900      # checar promises a cada 15min
CRON_CHECK=3600        # checar crontab a cada 1h
SESSIONS_TO_WATCH="devbot execbot degenbot spawnbot"
BUS_REGISTRY="${HOME}/.claude/bus/agents.registry"
WATCHDOG_REGISTRY="${HOME}/.claude/bus/watchdog.registry"

LOG_MAX_LINES=1000
log() {
  echo "[$(TZ=America/Manaus date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG"
  # Rotação: manter apenas as últimas LOG_MAX_LINES linhas
  local lines
  lines=$(wc -l < "$LOG" 2>/dev/null || echo 0)
  if [ "$lines" -gt "$LOG_MAX_LINES" ]; then
    tail -500 "$LOG" > "${LOG}.tmp" && mv "${LOG}.tmp" "$LOG"
  fi
}

ALERT_DIR="/tmp/cronbot/alerts"
mkdir -p "$ALERT_DIR"

inject_mainbot() {
  local msg="$1"
  # Escreve em arquivo de alerta — NÃO usa tmux send-keys (misturaria com input do Samyr)
  # O hook cronbot-alerts.sh drena esses arquivos no contexto do Claude via UserPromptSubmit
  local ts
  ts=$(TZ=America/Manaus date '+%Y%m%d-%H%M%S')
  local alertfile="${ALERT_DIR}/${ts}-$$.alert"
  echo "$msg" > "$alertfile"
  log "ALERT → ${alertfile}: $msg"
}

check_new_notifications() {
  local notify_file="${BUS_DIR}/pending-notifications"
  [ -f "$notify_file" ] || return

  # Ler e limpar atomicamente (swap)
  local tmp="${notify_file}.processing"
  mv "$notify_file" "$tmp" 2>/dev/null || return

  while IFS='|' read -r task_id agent created tarefa; do
    [ -z "$task_id" ] && continue
    inject_mainbot "[CRONBOT] 📋 Task ${task_id} delegada → ${agent}. Tarefa: ${tarefa}"
    log "Notificação: Task ${task_id} → ${agent}"
  done < "$tmp"

  rm -f "$tmp"
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
        TAREFA=$(grep "^TAREFA:" "$task_file" | cut -d' ' -f2- | cut -c1-80)

        # Se agente ainda está online e trabalhando, só alertar — não marcar FAILED
        AGENT_SESSION="${AGENT}bot"
        [[ "$AGENT" == *bot ]] && AGENT_SESSION="$AGENT"
        PANE_CONTENT=$(/usr/bin/tmux capture-pane -t "$AGENT_SESSION" -p 2>/dev/null | tail -3)
        if /usr/bin/tmux has-session -t "$AGENT_SESSION" 2>/dev/null && \
           echo "$PANE_CONTENT" | grep -qiE "thinking|tokens|✢|⏵|Baked|Working|Processing|◀▶|Razzle|Shenanigating"; then
          # Agente vivo e trabalhando — só avisar se passou de 2x o timeout
          if [ "$LOCK_AGE" -gt $((TASK_TIMEOUT * 2)) ]; then
            inject_mainbot "[CRONBOT] ⚠️ Task ${TASK_ID} em andamento há $((LOCK_AGE/60))min. Agente ${AGENT_SESSION} ainda trabalhando."
            log "Task ${TASK_ID} ainda em andamento após ${LOCK_AGE}s (agente ativo)"
            # Atualizar timestamp do lock para não spammar
            touch "$LOCK_FILE"
          fi
          continue
        fi

        # Agente offline ou idle sem ter concluído = FAILED real
        mkdir -p "${BUS_DIR}/status"
        cat > "$STATUS_FILE" << STATUSEOF
STATUS: FAILED
RESUMO: Timeout após $((LOCK_AGE/60))min — agente não respondeu
COMMIT: -
DETALHES: Lock criado mas agente (${AGENT_SESSION}) não finalizou em ${TASK_TIMEOUT}s
STATUSEOF
        rm -f "$LOCK_FILE"
        inject_mainbot "[CRONBOT] ❌ Task ${TASK_ID} FAILED por timeout ($((LOCK_AGE/60))min, agente offline). ${TAREFA}"
        log "Task ${TASK_ID} marcada FAILED por timeout (${LOCK_AGE}s, agente offline/idle)"
      fi
      continue
    fi

    # Status DONE ou FAILED sem lock = agente concluiu
    if [ -f "$STATUS_FILE" ]; then
      STATUS=$(grep "^STATUS:" "$STATUS_FILE" | cut -d' ' -f2)
      RESUMO=$(grep "^RESUMO:" "$STATUS_FILE" | cut -d' ' -f2-)
      COMMIT=$(grep "^COMMIT:" "$STATUS_FILE" | cut -d' ' -f2-)
      AGENT=$(grep "^AGENT:" "$task_file" | cut -d' ' -f2)

      # Dedupe: só notificar se ainda não foi notificado
      NOTIFIED_FLAG="${BUS_DIR}/status/${TASK_ID}.notified"
      if [ ! -f "$NOTIFIED_FLAG" ]; then
        if [ "$STATUS" = "DONE" ]; then
          MSG="[${AGENT^^}BOT] ✅ Task ${TASK_ID} CONCLUÍDA. ${RESUMO}"
          [ -n "$COMMIT" ] && [ "$COMMIT" != "-" ] && MSG="${MSG} (commit: ${COMMIT})"
          inject_mainbot "$MSG"
        elif [ "$STATUS" = "FAILED" ]; then
          inject_mainbot "[CRONBOT] ❌ Task ${TASK_ID} FALHOU: ${RESUMO}"
        fi
        touch "$NOTIFIED_FLAG"
        log "Notificação enviada: ${TASK_ID} → ${STATUS}"
      fi

      # Cleanup após notificar
      rm -f "$task_file" "$LOCK_FILE" "$STATUS_FILE" "$NOTIFIED_FLAG"
      log "Cleanup após notificação: ${TASK_ID}"
    fi
  done
}

check_promises() {
  local found=0

  # ── 1. bus/promises/*.promise (sistema formal) ────────────────────────────
  local results
  results=$(bash "${HOME}/claude-tg-tmux/scripts/bus-promise.sh" check 2>/dev/null)
  if [ -n "$results" ] && [ "$results" != "OK" ]; then
    while IFS='|' read -r tipo slug deadline contexto; do
      [ -z "$tipo" ] && continue
      if [ "$tipo" = "VENCIDA" ]; then
        inject_mainbot "[CRONBOT] 🔴 Promise VENCIDA: '${contexto}' (era ${deadline}). Avisar Samyr."
        found=1
      elif [ "$tipo" = "URGENTE" ]; then
        inject_mainbot "[CRONBOT] ⏰ Promise urgente em < 24h: '${contexto}' (vence ${deadline})."
        found=1
      fi
    done <<< "$results"
  fi

  # ── 2. memory/promises.md (promessas conversacionais do mainbot) ──────────
  local PROMISES_MD="${HOME}/.claude/projects/-home-clawd/memory/promises.md"
  if [ ! -f "$PROMISES_MD" ]; then return; fi

  local now_ts
  now_ts=$(date +%s)
  local limit_24h=$((now_ts + 86400))
  local today
  today=$(TZ=America/Manaus date '+%Y-%m-%d')

  # Formato: - [ ] YYYY-MM-DD | prazo: YYYY-MM-DD | descrição | contexto
  while IFS= read -r line; do
    # Só linhas abertas (- [ ])
    [[ "$line" =~ ^\-\ \[\ \] ]] || continue

    # Extrair prazo
    local prazo
    prazo=$(echo "$line" | grep -oP 'prazo:\s*\K[\d-]+')
    [ -z "$prazo" ] && continue

    local prazo_ts
    prazo_ts=$(date -d "$prazo" +%s 2>/dev/null) || continue

    # Extrair descrição (3º campo após |)
    local descricao
    descricao=$(echo "$line" | awk -F'|' '{gsub(/^[[:space:]]+|[[:space:]]+$/, "", $3); print $3}')

    if [ "$prazo_ts" -lt "$now_ts" ]; then
      inject_mainbot "[CRONBOT] 🔴 Promessa VENCIDA em promises.md: '${descricao}' (era ${prazo}). Cumprir ou cancelar."
      found=1
    elif [ "$prazo_ts" -lt "$limit_24h" ]; then
      inject_mainbot "[CRONBOT] ⏰ Promessa urgente em promises.md: '${descricao}' (vence ${prazo})."
      found=1
    fi
  done < "$PROMISES_MD"

  [ "$found" -eq 0 ] && log "check_promises: nenhuma urgência"
}

check_sessions() {
  # Agentes nativos fixos + degenbot
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

  # Agentes spawnados — usar launcher gerado (não recriar do zero)
  [ -f "$WATCHDOG_REGISTRY" ] || return
  while IFS= read -r nome; do
    [ -z "$nome" ] && continue
    if ! /usr/bin/tmux has-session -t "$nome" 2>/dev/null; then
      local launcher="${HOME}/claude-tg-tmux/scripts/${nome}-launcher.sh"
      if [ -f "$launcher" ]; then
        log "Agente spawnado '$nome' morto — reiniciando via launcher"
        bash "$launcher" &
        inject_mainbot "[CRONBOT] ⚠️ Agente '${nome}' estava morto — reiniciando."
      else
        inject_mainbot "[CRONBOT] ⚠️ Agente '${nome}' morto e sem launcher. Verificar."
      fi
    fi
  done < "$WATCHDOG_REGISTRY"
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

  # Notificações de novas tasks (bus-inject.sh)
  check_new_notifications

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
