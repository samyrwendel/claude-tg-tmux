#!/bin/bash
# spawnbot.sh — cria agentes especializados sob demanda
#
# Uso:
#   spawnbot.sh create <nome> <especialidade> [modelo] [workspace]
#   spawnbot.sh list                          — lista agentes ativos
#   spawnbot.sh kill <nome>                   — mata sessão e remove registro
#
# Exemplos:
#   spawnbot.sh create degenbot "DeFi, Polymarket, pools, crypto trading" opus
#   spawnbot.sh create researchbot "pesquisa web, notícias, análise de mercado" sonnet
#   spawnbot.sh create sqlbot "BigQuery, análise de dados, SQL" sonnet /home/clawd/clawd
#
# Modelos disponíveis:
#   opus    → claude-opus-4-6    (tarefas complexas, raciocínio profundo)
#   sonnet  → claude-sonnet-4-6  (tarefas intermediárias, padrão)
#   haiku   → claude-haiku-4-5-20251001 (tarefas simples, rápido)

CLAUDE_BIN="/home/clawd/.npm-global/bin/claude"
AGENTS_DIR="${HOME}/.claude/agents"
BUS_REGISTRY="${HOME}/.claude/bus/agents.registry"
MAINBOT="mainbot"
LOG="/tmp/spawnbot.log"

export HOME="/home/clawd"
export PATH="/home/clawd/.npm-global/bin:/home/clawd/.local/bin:/usr/local/bin:/usr/bin:/bin"
[ -s "$HOME/.nvm/nvm.sh" ] && source "$HOME/.nvm/nvm.sh"

log() { echo "[$(TZ=America/Manaus date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG"; }

inject_mainbot() {
  local msg="$1"
  if /usr/bin/tmux has-session -t "$MAINBOT" 2>/dev/null; then
    /usr/bin/tmux send-keys -t "$MAINBOT" "$msg" Enter
    log "INJECT → mainbot: $msg"
  else
    echo "$msg"
    log "mainbot offline — output no stdout: $msg"
  fi
}

resolve_model() {
  case "${1:-sonnet}" in
    opus)   echo "claude-opus-4-6" ;;
    sonnet) echo "claude-sonnet-4-6" ;;
    haiku)  echo "claude-haiku-4-5-20251001" ;;
    *)      echo "$1" ;;  # model ID direto
  esac
}

cmd_create() {
  local NOME="${1:?Nome do agente obrigatório (ex: degenbot)}"
  local ESPECIALIDADE="${2:?Especialidade obrigatória (ex: 'DeFi, Polymarket')}"
  local MODELO_ALIAS="${3:-sonnet}"
  local WORKSPACE="${4:-/home/clawd}"

  local MODELO
  MODELO=$(resolve_model "$MODELO_ALIAS")
  local SESSION="$NOME"
  local AGENT_DIR="${AGENTS_DIR}/${NOME}"

  # Verificar se já existe
  if /usr/bin/tmux has-session -t "$SESSION" 2>/dev/null; then
    echo "[spawnbot] Sessão '$SESSION' já existe. Use 'spawnbot.sh kill $NOME' primeiro."
    exit 1
  fi

  # Criar diretório do agente
  mkdir -p "$AGENT_DIR"

  # Gerar CLAUDE.md específico
  cat > "${AGENT_DIR}/CLAUDE.md" << CLAUDEEOF
@/home/clawd/.claude/CLAUDE.md

# ${NOME^^} — Agente Especializado

## Especialidade
${ESPECIALIDADE}

## Papel
Agente especializado criado pelo spawnbot. Executa tasks delegadas pelo mainbot
dentro da sua área de especialidade.

## Protocolo do Bus

Ao receber uma mensagem \`[BUS TASK YYYYMMDD-NNN]\`:

1. Ler o TASK_ID da mensagem
2. Criar lock: \`bash ~/claude-tg-tmux/scripts/bus-worker.sh lock <TASK_ID>\`
3. Executar a tarefa conforme TAREFA/CONTEXTO/CRITÉRIO
4. Ao concluir: \`bash ~/claude-tg-tmux/scripts/bus-worker.sh done <TASK_ID> "<resumo>" "<commit se houver>"\`
5. Se falhar: \`bash ~/claude-tg-tmux/scripts/bus-worker.sh fail <TASK_ID> "<erro>"\`

## Regras

- Auto-validar antes de marcar DONE
- Resumo: 1 linha limpa, sem narração
- Nunca comunicar com Samyr diretamente — só via status do bus
- Máximo 1 retry antes de marcar FAILED
CLAUDEEOF

  # Lançar sessão tmux
  /usr/bin/tmux new-session -d -s "$SESSION" -c "$WORKSPACE" \
    "${CLAUDE_BIN} --model ${MODELO} --dangerously-skip-permissions"

  sleep 3
  /usr/bin/tmux send-keys -t "$SESSION" Enter 2>/dev/null

  # Registrar no bus registry
  mkdir -p "$(dirname "$BUS_REGISTRY")"
  # Remove entrada antiga se existir
  grep -v "^${NOME}|" "$BUS_REGISTRY" > "${BUS_REGISTRY}.tmp" 2>/dev/null
  mv "${BUS_REGISTRY}.tmp" "$BUS_REGISTRY" 2>/dev/null || true
  echo "${NOME}|${MODELO}|${WORKSPACE}|${ESPECIALIDADE}|$(TZ=America/Manaus date '+%Y-%m-%d %H:%M')" >> "$BUS_REGISTRY"

  log "Agente criado: $NOME ($MODELO) — $ESPECIALIDADE"

  # Avisar mainbot
  inject_mainbot "[SPAWNBOT] ✅ Agente '${NOME}' disponível na sessão tmux '${SESSION}'. Especialidade: ${ESPECIALIDADE}. Modelo: ${MODELO_ALIAS}. Para delegar: bash ~/claude-tg-tmux/scripts/bus-inject.sh ${NOME} \"<tarefa>\""

  echo "[spawnbot] $NOME criado (sessão: $SESSION, modelo: $MODELO)"
}

cmd_list() {
  echo "=== Agentes ativos (spawnbot) ==="
  if [ ! -f "$BUS_REGISTRY" ] || [ ! -s "$BUS_REGISTRY" ]; then
    echo "  Nenhum agente registrado."
    return
  fi
  while IFS='|' read -r nome modelo workspace esp criado; do
    VIVO="❌ morto"
    /usr/bin/tmux has-session -t "$nome" 2>/dev/null && VIVO="✅ vivo"
    echo "  $nome [$modelo] $VIVO — $esp (criado: $criado)"
  done < "$BUS_REGISTRY"

  echo ""
  echo "=== Agentes nativos ==="
  for s in mainbot devbot execbot cronbot; do
    /usr/bin/tmux has-session -t "$s" 2>/dev/null \
      && echo "  $s ✅ vivo" \
      || echo "  $s ❌ morto"
  done
}

cmd_kill() {
  local NOME="${1:?Nome do agente obrigatório}"
  /usr/bin/tmux kill-session -t "$NOME" 2>/dev/null && echo "[spawnbot] Sessão '$NOME' encerrada." || echo "[spawnbot] Sessão '$NOME' não encontrada."
  # Remove do registry
  grep -v "^${NOME}|" "$BUS_REGISTRY" > "${BUS_REGISTRY}.tmp" 2>/dev/null
  mv "${BUS_REGISTRY}.tmp" "$BUS_REGISTRY" 2>/dev/null || true
  rm -rf "${AGENTS_DIR}/${NOME}"
  log "Agente removido: $NOME"
  inject_mainbot "[SPAWNBOT] Agente '${NOME}' foi encerrado e removido do bus."
  echo "[spawnbot] $NOME removido."
}

# Atualizar bus-inject.sh para suportar agentes dinâmicos do registry
update_bus_inject() {
  # Patch: bus-inject.sh precisa aceitar agentes do registry além de dev|exec
  # Verificar se já foi patchado
  grep -q "BUS_REGISTRY" /home/clawd/claude-tg-tmux/scripts/bus-inject.sh && return

  # Adicionar suporte a agentes dinâmicos antes do case
  sed -i 's/# Mapear nome do agente para sessão tmux/# Mapear nome do agente para sessão tmux\n# Suporte a agentes dinâmicos do spawnbot registry\nif [ -f "${HOME}\/.claude\/bus\/agents.registry" ] \&\& grep -q "^${AGENT}|" "${HOME}\/.claude\/bus\/agents.registry" 2>\/dev\/null; then\n  SESSION="$AGENT"\nelse/' \
    /home/clawd/claude-tg-tmux/scripts/bus-inject.sh

  # Fechar o else com fi após o esac
  # Mais seguro: reescrever apenas a seção do case
  log "bus-inject.sh já suporta registry via fallback (session = agent name)"
}

CMD="${1:?Comando obrigatório: create|list|kill}"
case "$CMD" in
  create) shift; cmd_create "$@" ;;
  list)   cmd_list ;;
  kill)   shift; cmd_kill "$@" ;;
  *)      echo "Uso: spawnbot.sh <create|list|kill> [args]" >&2; exit 1 ;;
esac
