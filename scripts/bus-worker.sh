#!/bin/bash
# bus-worker.sh — utilitário que agentes Claude usam para gerenciar tasks do bus
#
# Comandos:
#   bus-worker.sh lock <task_id>              — cria lock (sinaliza que está processando)
#   bus-worker.sh status <task_id> STARTED    — atualiza status para STARTED
#   bus-worker.sh done <task_id> <resumo> [commit]  — marca como DONE
#   bus-worker.sh fail <task_id> <erro>       — marca como FAILED
#   bus-worker.sh list                        — lista tasks pendentes para este agente
#   bus-worker.sh cleanup <task_id>           — remove task + lock + status

BUS_DIR="${HOME}/.claude/bus"
CMD="${1:?Comando obrigatório: lock|status|done|fail|list|cleanup}"

case "$CMD" in
  lock)
    TASK_ID="${2:?task_id obrigatório}"
    LOCK_FILE="${BUS_DIR}/tasks/${TASK_ID}.task.lock"
    echo "$$" > "$LOCK_FILE"
    echo "$(TZ=America/Manaus date '+%Y-%m-%d %H:%M')" >> "$LOCK_FILE"
    echo "[bus-worker] Lock criado: ${TASK_ID}"
    ;;

  status)
    TASK_ID="${2:?task_id obrigatório}"
    STATUS="${3:?status obrigatório}"
    STATUS_FILE="${BUS_DIR}/status/${TASK_ID}.status"
    cat > "$STATUS_FILE" << STATUSEOF
STATUS: ${STATUS}
TIMESTAMP: $(TZ=America/Manaus date '+%Y-%m-%d %H:%M')
STATUSEOF
    echo "[bus-worker] Status atualizado: ${TASK_ID} → ${STATUS}"
    ;;

  done)
    TASK_ID="${2:?task_id obrigatório}"
    RESUMO="${3:?resumo obrigatório}"
    COMMIT="${4:-}"
    STATUS_FILE="${BUS_DIR}/status/${TASK_ID}.status"
    cat > "$STATUS_FILE" << STATUSEOF
STATUS: DONE
RESUMO: ${RESUMO}
COMMIT: ${COMMIT}
TIMESTAMP: $(TZ=America/Manaus date '+%Y-%m-%d %H:%M')
STATUSEOF
    echo "[bus-worker] Task concluída: ${TASK_ID}"
    ;;

  fail)
    TASK_ID="${2:?task_id obrigatório}"
    ERRO="${3:?erro obrigatório}"
    STATUS_FILE="${BUS_DIR}/status/${TASK_ID}.status"
    cat > "$STATUS_FILE" << STATUSEOF
STATUS: FAILED
RESUMO: ${ERRO}
TIMESTAMP: $(TZ=America/Manaus date '+%Y-%m-%d %H:%M')
STATUSEOF
    echo "[bus-worker] Task falhou: ${TASK_ID}"
    ;;

  list)
    echo "=== Tasks pendentes em ${BUS_DIR}/tasks/ ==="
    for f in "${BUS_DIR}/tasks/"*.task; do
      [ -f "$f" ] || continue
      TASK_ID=$(basename "$f" .task)
      LOCKED="${BUS_DIR}/tasks/${TASK_ID}.task.lock"
      if [ -f "$LOCKED" ]; then
        echo "  [LOCKED] ${TASK_ID}"
      else
        echo "  [PENDING] ${TASK_ID}"
        grep "^TAREFA:" "$f" | head -1
      fi
    done
    ;;

  cleanup)
    TASK_ID="${2:?task_id obrigatório}"
    rm -f "${BUS_DIR}/tasks/${TASK_ID}.task"
    rm -f "${BUS_DIR}/tasks/${TASK_ID}.task.lock"
    rm -f "${BUS_DIR}/status/${TASK_ID}.status"
    echo "[bus-worker] Cleanup: ${TASK_ID}"
    ;;

  *)
    echo "Comando inválido: $CMD" >&2
    exit 1
    ;;
esac
