#!/bin/bash
# bus-inject.sh — mainbot usa para criar task e injetar no agente via tmux
# Uso: bus-inject.sh <agent> <tarefa> [contexto] [criterio] [arquivos] [deadline] [priority]
#
# Exemplo:
#   bus-inject.sh dev "Refatorar auth.js" "/home/clawd/clawd/auth.js" "testes passando" "" "" "high"

AGENT="${1:?Agente obrigatório: dev|exec|<nome-do-agente>}"
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
  dev|devbot)       SESSION="devbot" ;;
  exec|execbot)     SESSION="execbot" ;;
  degen|degenbot)   SESSION="degenbot" ;;
  spawn|spawnbot)   SESSION="spawnbot" ;;
  cron|cronbot)     SESSION="cronbot" ;;
  *)
    # Checar registry de agentes dinâmicos (spawnbot)
    REGISTRY="${HOME}/.claude/bus/agents.registry"
    if [ -f "$REGISTRY" ] && grep -q "^${AGENT}|" "$REGISTRY" 2>/dev/null; then
      SESSION="$AGENT"
    else
      echo "Agente inválido: $AGENT — não encontrado nos agentes nativos nem no registry" >&2
      echo "Agentes nativos: dev, exec, degen" >&2
      echo "Registry: $(cut -d'|' -f1 "$REGISTRY" 2>/dev/null | tr '\n' ' ')" >&2
      exit 1
    fi
    ;;
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

SKILLS DISPONÍVEIS (usar quando relevante):
$(case "$AGENT" in
  dev|devbot) echo "  /review — code review antes de DONE (OBRIGATÓRIO se modificou código)
  /investigate — debug de bug com root cause
  /ship — commit + push + PR
  /health — health check do código
  /careful — modo seguro para mudanças destrutivas
  /guard — guardrails para rm -rf, DROP TABLE, force-push
  /checkpoint — salvar progresso entre sessões
  /gsd-code-review — code review detalhado
  /gsd-debug — workflow de debug
  /gsd-secure-phase — auditoria de segurança
  /gsd-verify-work — verificar se o trabalho cumpriu o objetivo" ;;
  exec|execbot) echo "  /investigate — debug/análise rápida
  /gsd-explore — explorar codebase
  /bigquery-rag — buscar contexto no BQ" ;;
  degen|degenbot) echo "  /polymarket — dados de mercado
  /dex-chart — gráficos DeFi
  /trading — análise de trade" ;;
esac)

AO TERMINAR: escrever em ~/.claude/bus/status/${TASK_ID}.status
FORMATO DO STATUS:
STATUS: DONE|FAILED
RESUMO: (1 linha, resultado limpo)
COMMIT: (hash se houver)
DETALHES: (opcional)
TASKEOF

echo "[bus-inject] Task ${TASK_ID} criada → ${SESSION}"

# Aguardar agente estar idle (prompt "❯" visível) antes de injetar
wait_idle() {
  local session="$1"
  local max_wait=30
  local elapsed=0
  while [ $elapsed -lt $max_wait ]; do
    local pane
    pane=$(/usr/bin/tmux capture-pane -t "$session" -p -S -5 2>/dev/null)
    # Claude Code idle: linha com "❯ " no final (prompt vazio esperando input)
    if echo "$pane" | grep -qE '^\s*❯\s*$'; then
      return 0
    fi
    sleep 1
    elapsed=$((elapsed + 1))
  done
  # Timeout — injeta mesmo assim
  return 0
}

# Injetar no agente via tmux
wait_idle "$SESSION"
/usr/bin/tmux send-keys -t "$SESSION" "# [BUS TASK ${TASK_ID}] Veja em ${TASK_FILE}" Enter

# Criar lock para cronbot rastrear timeout
LOCK_FILE="${BUS_DIR}/tasks/${TASK_ID}.task.lock"
touch "$LOCK_FILE"

# Notificar cronbot: registrar task pendente para pickup
NOTIFY_FILE="${BUS_DIR}/pending-notifications"
echo "${TASK_ID}|${AGENT}|$(TZ=America/Manaus date '+%Y-%m-%d %H:%M')|${TAREFA}" >> "$NOTIFY_FILE"

echo "[bus-inject] Injetado em tmux:${SESSION} (lock + notify criados)"
echo "$TASK_ID"
