#!/bin/bash
# spawnbot.sh — contrata agentes especializados com provisionamento completo
#
# Uso:
#   spawnbot.sh create <nome> "<especialidade>" [modelo] [emoji]
#   spawnbot.sh list                          — lista agentes ativos
#   spawnbot.sh kill <nome>                   — desliga e remove agente
#   spawnbot.sh fire <nome>                   — alias de kill
#
# Exemplos:
#   spawnbot.sh create researchbot "pesquisa web, notícias, análise" sonnet 🔍
#   spawnbot.sh create sqlbot "BigQuery, SQL, análise de dados" opus 📊
#
# Modelos disponíveis:
#   opus    → claude-opus-4-6    (tarefas complexas, raciocínio profundo)
#   sonnet  → claude-sonnet-4-6  (tarefas intermediárias, padrão)
#   haiku   → claude-haiku-4-5-20251001 (tarefas simples, rápido)

CLAUDE_BIN="/home/clawd/.npm-global/bin/claude"
AGENTS_DIR="${HOME}/.claude/agents"
SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUS_REGISTRY="${HOME}/.claude/bus/agents.registry"
WATCHDOG_REGISTRY="${HOME}/.claude/bus/watchdog.registry"
MAINBOT="mainbot"
LOG="/tmp/spawnbot.log"

export HOME="/home/clawd"
export PATH="/home/clawd/.npm-global/bin:/home/clawd/.local/bin:/usr/local/bin:/usr/bin:/bin"
[ -s "$HOME/.nvm/nvm.sh" ] && source "$HOME/.nvm/nvm.sh"

log() { echo "[$(TZ=America/Manaus date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG"; }

inject_mainbot() {
  local msg="$1"
  bash "${SCRIPTS_DIR}/alert-mainbot.sh" "$msg" 2>/dev/null
  log "ALERT → mainbot: $msg"
}

resolve_model() {
  case "${1:-sonnet}" in
    opus)   echo "claude-opus-4-6" ;;
    sonnet) echo "claude-sonnet-4-6" ;;
    haiku)  echo "claude-haiku-4-5-20251001" ;;
    *)      echo "$1" ;;
  esac
}

cmd_create() {
  local NOME="${1:?Nome do agente obrigatório (ex: researchbot)}"
  local ESPECIALIDADE="${2:?Especialidade obrigatória (ex: 'pesquisa web, notícias')}"
  local MODELO_ALIAS="${3:-sonnet}"
  local EMOJI="${4:-🤖}"

  local MODELO
  MODELO=$(resolve_model "$MODELO_ALIAS")
  local SESSION="$NOME"
  local AGENT_CONFIG_DIR="${AGENTS_DIR}/${NOME}"
  local WORKSPACE="/home/clawd/mainbot-${NOME}"

  # Verificar se já existe
  if /usr/bin/tmux has-session -t "$SESSION" 2>/dev/null; then
    echo "[spawnbot] Sessão '$SESSION' já existe. Use 'spawnbot.sh kill $NOME' primeiro."
    exit 1
  fi

  # Rollback: limpa tudo se qualquer etapa falhar
  _rollback() {
    log "ROLLBACK: limpando agente $NOME após falha"
    /usr/bin/tmux kill-session -t "$SESSION" 2>/dev/null
    rm -rf "$AGENT_CONFIG_DIR" "$WORKSPACE"
    rm -f "${SCRIPTS_DIR}/${NOME}-launcher.sh"
    (
      flock -x 9
      grep -v "^${NOME}|" "$BUS_REGISTRY" > "${BUS_REGISTRY}.tmp" 2>/dev/null
      mv "${BUS_REGISTRY}.tmp" "$BUS_REGISTRY" 2>/dev/null || true
      grep -v "^${NOME}$" "$WATCHDOG_REGISTRY" > "${WATCHDOG_REGISTRY}.tmp" 2>/dev/null
      mv "${WATCHDOG_REGISTRY}.tmp" "$WATCHDOG_REGISTRY" 2>/dev/null || true
    ) 9>"${BUS_REGISTRY}.lock"
  }

  echo "[spawnbot] Contratando ${EMOJI} ${NOME} (${MODELO_ALIAS})..."

  # ── 1. Workspace com identidade ──────────────────────────────────────────
  mkdir -p "${WORKSPACE}/memory" || { echo "[spawnbot] Erro ao criar workspace" >&2; exit 1; }

  cat > "${WORKSPACE}/IDENTITY.md" << EOF
# IDENTITY — ${NOME} ${EMOJI}

- **Nome:** ${NOME}
- **Emoji:** ${EMOJI}
- **Modelo:** ${MODELO}
- **Vibe:** Especialista focado. Executa, não filosofa.

Você é o **${NOME}**, agente especializado do time do Degenerado (mainbot).
Contratado pelo spawnbot para tarefa específica. Executa e reporta.

## Especialidade

${ESPECIALIDADE}

## Regras

- Resultado limpo, sem narração
- Ao concluir: reportar ao mainbot via bus
- NUNCA comunicar com Samyr diretamente
- Máximo 1 retry antes de escalar pro mainbot
- Responder em português do Brasil

## Limites

- Foco na especialidade acima — não desviar
- Não toma decisões estratégicas — executa o que o mainbot aprovou

## Contexto do sistema

- **Mainbot:** tmux \`mainbot\` (@mainagentebot) — orquestrador
- **OpenClaw/Degenerado:** SEPARADO — @mentordegenbot, PM2 clawdbot-gw — NÃO CONFUNDIR
- **Bus:** \`~/claude-tg-tmux/scripts/bus-inject.sh\`
- **Workspace:** ${WORKSPACE}
EOF

  cat > "${WORKSPACE}/CLAUDE.md" << EOF
# ${NOME} ${EMOJI}

Leia IDENTITY.md para sua identidade completa.

## Protocolo do Bus

Ao receber uma mensagem \`[BUS TASK YYYYMMDD-NNN]\`:

1. Ler o TASK_ID
2. Lock: \`bash ~/claude-tg-tmux/scripts/bus-worker.sh lock <TASK_ID>\`
3. Executar conforme TAREFA/CONTEXTO/CRITÉRIO
4. Concluir: \`bash ~/claude-tg-tmux/scripts/bus-worker.sh done <TASK_ID> "<resumo>"\`
5. Falha: \`bash ~/claude-tg-tmux/scripts/bus-worker.sh fail <TASK_ID> "<erro>"\`

## Output direto ao mainbot

\`\`\`bash
bash ~/claude-tg-tmux/scripts/alert-mainbot.sh "[${NOME^^}] <resultado>"
\`\`\`

## Nunca fazer

- Interagir com Samyr diretamente
- Tocar em /home/clawd/.openclaw/ ou PM2 clawdbot-gw
- Operar fora da especialidade definida
EOF

  log "Workspace criado: ${WORKSPACE}"

  # ── 2. Config dir para bus protocol (--add-dir) ───────────────────────────
  mkdir -p "$AGENT_CONFIG_DIR"

  cat > "${AGENT_CONFIG_DIR}/CLAUDE.md" << EOF
@/home/clawd/.claude/CLAUDE.md

# ${NOME^^} — Agente Especializado

## Especialidade
${ESPECIALIDADE}

## Papel
Agente criado pelo spawnbot. Executa tasks delegadas pelo mainbot.

## Protocolo do Bus

Ao receber \`[BUS TASK YYYYMMDD-NNN]\`:

1. Lock: \`bash ~/claude-tg-tmux/scripts/bus-worker.sh lock <TASK_ID>\`
2. Executar
3. Done: \`bash ~/claude-tg-tmux/scripts/bus-worker.sh done <TASK_ID> "<resumo>"\`
4. Fail: \`bash ~/claude-tg-tmux/scripts/bus-worker.sh fail <TASK_ID> "<erro>"\`

## Regras
- Auto-validar antes de marcar DONE
- Resumo: 1 linha, sem narração
- Nunca comunicar com Samyr — só via bus
- Máximo 1 retry antes de FAILED
EOF

  log "Agent config dir criado: ${AGENT_CONFIG_DIR}"

  # ── 3. Launcher script ────────────────────────────────────────────────────
  local LAUNCHER="${SCRIPTS_DIR}/${NOME}-launcher.sh"

  cat > "$LAUNCHER" << EOF
#!/bin/bash
# ${NOME}-launcher.sh — lança ${NOME} ${EMOJI} (${MODELO_ALIAS})
# Gerado automaticamente pelo spawnbot em $(TZ=America/Manaus date '+%Y-%m-%d %H:%M')

SESSION="${NOME}"
CLAUDE_BIN="/home/clawd/.npm-global/bin/claude"
AGENT_DIR="${AGENT_CONFIG_DIR}"
WORK_DIR="${WORKSPACE}"
TASK_DIR="/tmp/watchdog/tasks"

export HOME="/home/clawd"
export PATH="/home/clawd/.npm-global/bin:/home/clawd/.local/bin:/usr/local/bin:/usr/bin:/bin"
[ -s "\$HOME/.nvm/nvm.sh" ] && source "\$HOME/.nvm/nvm.sh"

/usr/bin/tmux kill-session -t "\$SESSION" 2>/dev/null

/usr/bin/tmux new-session -d -s "\$SESSION" -c "\$WORK_DIR" \\
  "\$CLAUDE_BIN" --model ${MODELO} --dangerously-skip-permissions \\
  --add-dir "\$AGENT_DIR" --add-dir "\$WORK_DIR"

sleep 3
/usr/bin/tmux send-keys -t "\$SESSION" Enter 2>/dev/null

echo "[${NOME}-launcher] Sessão '\$SESSION' iniciada (${MODELO_ALIAS})"

# Recovery: injetar contexto se tinha task pendente
if [ -f "\${TASK_DIR}/\${SESSION}.task" ]; then
  sleep 5
  /usr/bin/tmux send-keys -t "\$SESSION" "AVISO: Sessão anterior foi reiniciada pelo watchdog. Leia: \${TASK_DIR}/\${SESSION}.pane" Enter 2>/dev/null
  rm -f "\${TASK_DIR}/\${SESSION}.task" "\${TASK_DIR}/\${SESSION}.pane"
  echo "[${NOME}-launcher] Task recovery injetada"
fi
EOF

  chmod +x "$LAUNCHER"
  log "Launcher criado: ${LAUNCHER}"

  # ── 4. Registrar no watchdog registry ────────────────────────────────────
  mkdir -p "$(dirname "$WATCHDOG_REGISTRY")"
  (
    flock -x 9
    grep -v "^${NOME}$" "$WATCHDOG_REGISTRY" > "${WATCHDOG_REGISTRY}.tmp" 2>/dev/null
    mv "${WATCHDOG_REGISTRY}.tmp" "$WATCHDOG_REGISTRY" 2>/dev/null || true
    echo "${NOME}" >> "$WATCHDOG_REGISTRY"
  ) 9>"${WATCHDOG_REGISTRY}.lock"
  log "Registrado no watchdog registry"

  # ── 5. Lançar sessão tmux ─────────────────────────────────────────────────
  if ! bash "$LAUNCHER"; then
    echo "[spawnbot] Erro ao lançar sessão tmux '$SESSION'" >&2
    _rollback
    exit 1
  fi

  # Verificar que subiu
  sleep 2
  if ! /usr/bin/tmux has-session -t "$SESSION" 2>/dev/null; then
    echo "[spawnbot] Sessão '$SESSION' morreu logo após criar" >&2
    _rollback
    exit 1
  fi

  # ── 6. Registrar no bus registry ─────────────────────────────────────────
  mkdir -p "$(dirname "$BUS_REGISTRY")"
  (
    flock -x 9
    grep -v "^${NOME}|" "$BUS_REGISTRY" > "${BUS_REGISTRY}.tmp" 2>/dev/null
    mv "${BUS_REGISTRY}.tmp" "$BUS_REGISTRY" 2>/dev/null || true
    echo "${NOME}|${MODELO}|${WORKSPACE}|${ESPECIALIDADE}|$(TZ=America/Manaus date '+%Y-%m-%d %H:%M')" >> "$BUS_REGISTRY"
  ) 9>"${BUS_REGISTRY}.lock"

  log "Agente contratado: ${NOME} (${MODELO}) — ${ESPECIALIDADE}"

  inject_mainbot "[SPAWNBOT] ${EMOJI} ${NOME} contratado e online. Modelo: ${MODELO_ALIAS}. Especialidade: ${ESPECIALIDADE}. Delegar: bus-inject.sh ${NOME} \"<tarefa>\""

  echo "[spawnbot] ✅ ${NOME} contratado — sessão tmux '${SESSION}', workspace ${WORKSPACE}"
}

cmd_list() {
  echo "=== Agentes nativos ==="
  for s in mainbot devbot execbot cronbot degenbot spawnbot; do
    local status emoji
    /usr/bin/tmux has-session -t "$s" 2>/dev/null && status="✅ online" || status="❌ offline"
    echo "  $s — $status"
  done

  echo ""
  echo "=== Agentes spawnados ==="
  if [ ! -f "$BUS_REGISTRY" ] || [ ! -s "$BUS_REGISTRY" ]; then
    echo "  Nenhum."
    return
  fi
  while IFS='|' read -r nome modelo workspace esp criado; do
    local status
    /usr/bin/tmux has-session -t "$nome" 2>/dev/null && status="✅ online" || status="❌ offline"
    echo "  $nome [$modelo] $status — $esp (contratado: $criado)"
  done < "$BUS_REGISTRY"
}

cmd_kill() {
  local NOME="${1:?Nome do agente obrigatório}"

  /usr/bin/tmux kill-session -t "$NOME" 2>/dev/null \
    && echo "[spawnbot] Sessão '$NOME' encerrada." \
    || echo "[spawnbot] Sessão '$NOME' não encontrada."

  # Remover do bus registry
  (
    flock -x 9
    grep -v "^${NOME}|" "$BUS_REGISTRY" > "${BUS_REGISTRY}.tmp" 2>/dev/null
    mv "${BUS_REGISTRY}.tmp" "$BUS_REGISTRY" 2>/dev/null || true
  ) 9>"${BUS_REGISTRY}.lock"

  # Remover do watchdog registry
  (
    flock -x 9
    grep -v "^${NOME}$" "$WATCHDOG_REGISTRY" > "${WATCHDOG_REGISTRY}.tmp" 2>/dev/null
    mv "${WATCHDOG_REGISTRY}.tmp" "$WATCHDOG_REGISTRY" 2>/dev/null || true
  ) 9>"${WATCHDOG_REGISTRY}.lock"

  # Remover launcher e config dir
  rm -f "${SCRIPTS_DIR}/${NOME}-launcher.sh"
  rm -rf "${AGENTS_DIR}/${NOME}"
  rm -rf "/home/clawd/mainbot-${NOME}"

  log "Agente demitido: $NOME"
  inject_mainbot "[SPAWNBOT] 🔴 Agente '${NOME}' encerrado e removido."
  echo "[spawnbot] $NOME demitido."
}

CMD="${1:?Comando obrigatório: create|list|kill|fire}"
case "$CMD" in
  create)      shift; cmd_create "$@" ;;
  list)        cmd_list ;;
  kill|fire)   shift; cmd_kill "$@" ;;
  *)           echo "Uso: spawnbot.sh <create|list|kill> [args]" >&2; exit 1 ;;
esac
