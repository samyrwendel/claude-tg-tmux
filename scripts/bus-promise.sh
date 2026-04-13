#!/bin/bash
# bus-promise.sh — cria, lista e resolve promessas feitas ao Samyr
#
# Comandos:
#   bus-promise.sh create <slug> <deadline> <contexto>
#     deadline formato: "2026-04-14 18:00"
#   bus-promise.sh list                    — lista promises abertas
#   bus-promise.sh resolve <slug>          — marca como cumprida
#   bus-promise.sh check                   — retorna promises urgentes (< 24h ou vencidas)

BUS_DIR="${HOME}/.claude/bus"
CMD="${1:?Comando: create|list|resolve|check}"

case "$CMD" in
  create)
    SLUG="${2:?slug obrigatório (ex: portfolio-update)}"
    DEADLINE="${3:?deadline obrigatório (ex: '2026-04-14 18:00')}"
    CONTEXTO="${4:?contexto obrigatório}"
    FILE="${BUS_DIR}/promises/${SLUG}.promise"
    cat > "$FILE" << PROMEOF
PROMISE_ID: ${SLUG}
DEADLINE: ${DEADLINE}
CONTEXTO: ${CONTEXTO}
STATUS: OPEN
CREATED: $(TZ=America/Manaus date '+%Y-%m-%d %H:%M')
PROMEOF
    echo "[bus-promise] Criada: ${SLUG} → vence ${DEADLINE}"
    ;;

  list)
    echo "=== Promises abertas ==="
    for f in "${BUS_DIR}/promises/"*.promise; do
      [ -f "$f" ] || continue
      STATUS=$(grep "^STATUS:" "$f" | cut -d' ' -f2)
      [ "$STATUS" = "RESOLVED" ] && continue
      echo "---"
      cat "$f"
    done
    ;;

  resolve)
    SLUG="${2:?slug obrigatório}"
    FILE="${BUS_DIR}/promises/${SLUG}.promise"
    [ -f "$FILE" ] || { echo "Promise não encontrada: $SLUG" >&2; exit 1; }
    sed -i "s/^STATUS: OPEN/STATUS: RESOLVED/" "$FILE"
    echo "RESOLVED_AT: $(TZ=America/Manaus date '+%Y-%m-%d %H:%M')" >> "$FILE"
    echo "[bus-promise] Resolvida: ${SLUG}"
    ;;

  check)
    NOW_TS=$(date +%s)
    LIMIT_24H=$((NOW_TS + 86400))
    FOUND=0
    for f in "${BUS_DIR}/promises/"*.promise; do
      [ -f "$f" ] || continue
      STATUS=$(grep "^STATUS:" "$f" | cut -d' ' -f2)
      [ "$STATUS" = "RESOLVED" ] && continue
      DEADLINE=$(grep "^DEADLINE:" "$f" | cut -d' ' -f2-)
      DEADLINE_TS=$(date -d "$DEADLINE" +%s 2>/dev/null) || continue
      SLUG=$(grep "^PROMISE_ID:" "$f" | cut -d' ' -f2)
      CONTEXTO=$(grep "^CONTEXTO:" "$f" | cut -d' ' -f2-)
      if [ "$DEADLINE_TS" -lt "$NOW_TS" ]; then
        echo "VENCIDA|${SLUG}|${DEADLINE}|${CONTEXTO}"
        FOUND=1
      elif [ "$DEADLINE_TS" -lt "$LIMIT_24H" ]; then
        echo "URGENTE|${SLUG}|${DEADLINE}|${CONTEXTO}"
        FOUND=1
      fi
    done
    [ "$FOUND" -eq 0 ] && echo "OK"
    ;;

  *)
    echo "Comando inválido: $CMD" >&2
    exit 1
    ;;
esac
