#!/bin/bash
# bus-inject.sh — mainbot usa para criar task e injetar no agente via tmux
# Uso: bus-inject.sh <agent> <tarefa> [contexto] [criterio] [arquivos] [deadline] [priority]
#
# Exemplo:
#   bus-inject.sh dev "Refatorar auth.js" "/home/clawd/clawd/auth.js" "testes passando" "" "" "high"

AGENT="${1:?Agente obrigatório: dev|exec}"
TAREFA="${2:?Tarefa obrigatória}"
CONTEXTO="${3:-}"
CRITERIO="${4:-concluído sem erro}"
ARQUIVOS="${5:-}"
DEADLINE="${6:--}"
PRIORITY="${7:-normal}"

BUS_DIR="${HOME}/.claude/bus"
TODAY=$(date +%Y%m%d)

# Gerar ID único
LAST=$(ls "${BUS_DIR}/tasks/${TODAY}"*.task 2>/dev/null | wc -l)
SEQ=$(printf "%03d" $((LAST + 1)))
TASK_ID="${TODAY}-${SEQ}"

TASK_FILE="${BUS_DIR}/tasks/${TASK_ID}.task"

# Mapear nome do agente para sessão tmux
case "$AGENT" in
  dev|devbot)   SESSION="devbot" ;;
  exec|execbot) SESSION="execbot" ;;
  *)            echo "Agente inválido: $AGENT (use dev ou exec)" >&2; exit 1 ;;
esac

# Verificar se sessão existe
if ! /usr/bin/tmux has-session -t "$SESSION" 2>/dev/null; then
  echo "[bus-inject] ERRO: sessão tmux '$SESSION' não encontrada" >&2
  exit 1
fi

# Escrever arquivo de task
cat > "$TASK_FILE" << TASKEOF
TASK_ID: ${TASK_ID}
AGENT: ${AGENT}
PRIORITY: ${PRIORITY}
DEADLINE: ${DEADLINE}
CREATED: $(TZ=America/Manaus date '+%Y-%m-%d %H:%M')

TAREFA: ${TAREFA}
CONTEXTO: ${CONTEXTO}
CRITÉRIO: ${CRITERIO}
ARQUIVOS: ${ARQUIVOS}

AO TERMINAR: escrever em ~/.claude/bus/status/${TASK_ID}.status
FORMATO DO STATUS:
STATUS: DONE|FAILED
RESUMO: (1 linha, resultado limpo)
COMMIT: (hash se houver)
DETALHES: (opcional)
TASKEOF

echo "[bus-inject] Task ${TASK_ID} criada → ${SESSION}"

# Injetar no agente via tmux
# Usar arquivo de task como contexto, enviando apenas um marcador para o agente
/usr/bin/tmux send-keys -t "$SESSION" "# [BUS TASK ${TASK_ID}] Veja em ${TASK_FILE}" Enter

echo "[bus-inject] Injetado em tmux:${SESSION}"
echo "$TASK_ID"
