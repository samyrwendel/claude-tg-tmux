# Multi-Agent Bus Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implementar barramento de arquivos entre 4 sessões Claude (mainbot/devbot/execbot/cronbot) para manter mainbot sempre disponível ao Samyr enquanto delega execução pesada.

**Architecture:** Mainbot classifica mensagens automaticamente e escreve tasks em `~/.claude/bus/tasks/`. Agentes leem via bus-worker.sh, processam, escrevem status. Cronbot (shell script em loop) monitora tasks, promises e saúde das sessões — injeta alertas no mainbot via tmux send-keys. Cada agente tem CLAUDE.md específico que herda do global.

**Tech Stack:** Bash, tmux send-keys, flock (lockfiles), claude CLI flags (`--system-prompt`), systemd (opcional para cronbot)

---

## File Map

| Arquivo | Ação | Responsabilidade |
|---------|------|-----------------|
| `~/.claude/bus/tasks/` | Criar dir | Fila de tasks pendentes |
| `~/.claude/bus/status/` | Criar dir | Status das tasks em andamento/concluídas |
| `~/.claude/bus/promises/` | Criar dir | Promessas com prazo |
| `scripts/bus-setup.sh` | Criar | Cria dirs do bus, idempotente |
| `scripts/bus-inject.sh` | Criar | Mainbot usa: cria task + injeta no agente via tmux |
| `scripts/bus-worker.sh` | Criar | Agentes usam: lê próxima task, cria lock, atualiza status |
| `scripts/bus-promise.sh` | Criar | Cria/lista/resolve promises |
| `scripts/cronbot-monitor.sh` | Criar | Loop de monitoramento — tasks, promises, sessões |
| `scripts/devbot-launcher.sh` | Criar | Lança devbot (Opus 4.6) com CLAUDE.md correto |
| `scripts/execbot-launcher.sh` | Criar | Lança execbot (Sonnet 4.6) com CLAUDE.md correto |
| `scripts/cronbot-launcher.sh` | Criar | Lança cronbot (Haiku 4.5) + inicia monitor loop |
| `~/.claude/agents/mainbot/CLAUDE.md` | Criar | Regras específicas do mainbot: classificação, bus |
| `~/.claude/agents/devbot/CLAUDE.md` | Criar | Regras do devbot: código, bus-worker protocol |
| `~/.claude/agents/execbot/CLAUDE.md` | Criar | Regras do execbot: tasks rápidas, bus-worker leve |
| `~/.claude/agents/cronbot/CLAUDE.md` | Criar | Regras do cronbot: NUNCA executa tasks |
| `mainbot-launcher.sh` | Modificar | Adicionar `--system-prompt` apontando para agents/mainbot/ |
| `systemd/cronbot-monitor.service` | Criar | Systemd para cronbot-monitor.sh (opcional) |

---

## Task 1: Criar estrutura do bus

**Files:**
- Create: `scripts/bus-setup.sh`

- [ ] **Step 1: Criar o script de setup**

```bash
cat > /home/clawd/claude-tg-tmux/scripts/bus-setup.sh << 'EOF'
#!/bin/bash
# bus-setup.sh — cria estrutura de diretórios do barramento multi-agent
# Idempotente: pode rodar múltiplas vezes sem problema

BUS_DIR="${HOME}/.claude/bus"

mkdir -p "${BUS_DIR}/tasks"
mkdir -p "${BUS_DIR}/status"
mkdir -p "${BUS_DIR}/promises"

echo "[bus-setup] Estrutura criada em ${BUS_DIR}"
ls -la "${BUS_DIR}"
EOF
chmod +x /home/clawd/claude-tg-tmux/scripts/bus-setup.sh
```

- [ ] **Step 2: Rodar o setup**

```bash
bash /home/clawd/claude-tg-tmux/scripts/bus-setup.sh
```

Saída esperada:
```
[bus-setup] Estrutura criada em /home/clawd/.claude/bus
total 0
drwxr-xr-x ... promises
drwxr-xr-x ... status
drwxr-xr-x ... tasks
```

- [ ] **Step 3: Verificar estrutura criada**

```bash
ls -la ~/.claude/bus/
```

Esperado: 3 diretórios — `tasks/`, `status/`, `promises/`

- [ ] **Step 4: Commit**

```bash
cd /home/clawd/claude-tg-tmux
git add scripts/bus-setup.sh
git commit -m "feat: bus-setup.sh — cria estrutura de diretórios do barramento"
```

---

## Task 2: bus-inject.sh — mainbot cria e injeta tasks

**Files:**
- Create: `scripts/bus-inject.sh`

Este script é usado pelo mainbot para criar um arquivo `.task` e injetar o conteúdo no agente destino via tmux.

- [ ] **Step 1: Criar bus-inject.sh**

```bash
cat > /home/clawd/claude-tg-tmux/scripts/bus-inject.sh << 'EOF'
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
INJECT_MSG="[BUS TASK ${TASK_ID}] $(cat "$TASK_FILE")"
/usr/bin/tmux send-keys -t "$SESSION" "$INJECT_MSG" Enter

echo "[bus-inject] Injetado em tmux:${SESSION}"
echo "$TASK_ID"
EOF
chmod +x /home/clawd/claude-tg-tmux/scripts/bus-inject.sh
```

- [ ] **Step 2: Teste — injetar uma task de teste (sem sessão real)**

```bash
# Criar sessão de teste temporária
tmux new-session -d -s devbot-test 2>/dev/null || true

# Testar injeção (vai usar devbot-test se devbot não existir — ajustar temporariamente)
SESSION_OVERRIDE=devbot-test bash -c '
  sed "s/SESSION=\"devbot\"/SESSION=\"devbot-test\"/" \
    /home/clawd/claude-tg-tmux/scripts/bus-inject.sh > /tmp/bus-inject-test.sh
  chmod +x /tmp/bus-inject-test.sh
  /tmp/bus-inject-test.sh dev "Teste de injeção" "contexto de teste" "sem erro" "" "" "normal"
'

# Verificar arquivo criado
ls -la ~/.claude/bus/tasks/
cat ~/.claude/bus/tasks/*.task 2>/dev/null | head -20

# Verificar o que foi injetado no tmux
tmux capture-pane -t devbot-test -p | tail -10

# Limpar
tmux kill-session -t devbot-test 2>/dev/null
rm -f ~/.claude/bus/tasks/*.task
```

Esperado: arquivo `.task` com todos os campos preenchidos + conteúdo visível no pane do tmux.

- [ ] **Step 3: Commit**

```bash
cd /home/clawd/claude-tg-tmux
git add scripts/bus-inject.sh
git commit -m "feat: bus-inject.sh — cria task e injeta no agente via tmux"
```

---

## Task 3: bus-worker.sh — agentes processam tasks da fila

**Files:**
- Create: `scripts/bus-worker.sh`

Agentes (devbot, execbot) incluem este protocolo no seu CLAUDE.md. Na prática o Claude lê o arquivo de task que foi injetado via tmux, e ao concluir usa este script para atualizar o status.

- [ ] **Step 1: Criar bus-worker.sh**

```bash
cat > /home/clawd/claude-tg-tmux/scripts/bus-worker.sh << 'EOF'
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
EOF
chmod +x /home/clawd/claude-tg-tmux/scripts/bus-worker.sh
```

- [ ] **Step 2: Testar ciclo completo de uma task**

```bash
# Criar task de teste manualmente
TASK_ID="20260413-TEST"
BUS_DIR="$HOME/.claude/bus"
cat > "${BUS_DIR}/tasks/${TASK_ID}.task" << 'EOF'
TASK_ID: 20260413-TEST
AGENT: dev
TAREFA: Teste do bus-worker
AO TERMINAR: escrever em ~/.claude/bus/status/20260413-TEST.status
EOF

# Simular fluxo do agente
bash /home/clawd/claude-tg-tmux/scripts/bus-worker.sh lock "$TASK_ID"
bash /home/clawd/claude-tg-tmux/scripts/bus-worker.sh status "$TASK_ID" STARTED
bash /home/clawd/claude-tg-tmux/scripts/bus-worker.sh done "$TASK_ID" "Teste concluído com sucesso" "abc1234"

# Verificar
cat "${BUS_DIR}/status/${TASK_ID}.status"

# Cleanup
bash /home/clawd/claude-tg-tmux/scripts/bus-worker.sh cleanup "$TASK_ID"
ls "${BUS_DIR}/tasks/" "${BUS_DIR}/status/"
```

Saída esperada do status:
```
STATUS: DONE
RESUMO: Teste concluído com sucesso
COMMIT: abc1234
TIMESTAMP: 2026-04-13 ...
```

Após cleanup: diretórios vazios.

- [ ] **Step 3: Commit**

```bash
cd /home/clawd/claude-tg-tmux
git add scripts/bus-worker.sh
git commit -m "feat: bus-worker.sh — utilitário de ciclo de vida de tasks para agentes"
```

---

## Task 4: bus-promise.sh — gerenciar promessas

**Files:**
- Create: `scripts/bus-promise.sh`

- [ ] **Step 1: Criar bus-promise.sh**

```bash
cat > /home/clawd/claude-tg-tmux/scripts/bus-promise.sh << 'EOF'
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
EOF
chmod +x /home/clawd/claude-tg-tmux/scripts/bus-promise.sh
```

- [ ] **Step 2: Testar ciclo de promise**

```bash
# Criar promise
bash /home/clawd/claude-tg-tmux/scripts/bus-promise.sh create \
  "portfolio-update" \
  "$(TZ=America/Manaus date -d '+2 hours' '+%Y-%m-%d %H:%M')" \
  "Samyr pediu update do portfólio"

# Listar
bash /home/clawd/claude-tg-tmux/scripts/bus-promise.sh list

# Check urgência (deve aparecer como URGENTE pois < 24h)
bash /home/clawd/claude-tg-tmux/scripts/bus-promise.sh check

# Resolver
bash /home/clawd/claude-tg-tmux/scripts/bus-promise.sh resolve "portfolio-update"

# Check novamente (deve retornar OK)
bash /home/clawd/claude-tg-tmux/scripts/bus-promise.sh check

# Cleanup
rm -f ~/.claude/bus/promises/portfolio-update.promise
```

Saída esperada do check antes de resolver: `URGENTE|portfolio-update|...|Samyr pediu update...`
Saída após resolver: `OK`

- [ ] **Step 3: Commit**

```bash
cd /home/clawd/claude-tg-tmux
git add scripts/bus-promise.sh
git commit -m "feat: bus-promise.sh — gerenciar promessas feitas ao Samyr com prazo"
```

---

## Task 5: cronbot-monitor.sh — loop de monitoramento

**Files:**
- Create: `scripts/cronbot-monitor.sh`

Este é o coração do cronbot. Roda como loop em bash dentro da sessão tmux `cronbot`. Não é um Claude — é shell puro.

- [ ] **Step 1: Criar cronbot-monitor.sh**

```bash
cat > /home/clawd/claude-tg-tmux/scripts/cronbot-monitor.sh << 'EOF'
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
EOF
chmod +x /home/clawd/claude-tg-tmux/scripts/cronbot-monitor.sh
```

- [ ] **Step 2: Teste do check_tasks com status DONE simulado**

```bash
# Criar task e status simulados
TASK_ID="20260413-MONTEST"
BUS_DIR="$HOME/.claude/bus"

cat > "${BUS_DIR}/tasks/${TASK_ID}.task" << 'EOF'
TASK_ID: 20260413-MONTEST
AGENT: dev
TAREFA: Teste do monitor
EOF

cat > "${BUS_DIR}/status/${TASK_ID}.status" << 'EOF'
STATUS: DONE
RESUMO: Teste concluído com sucesso
COMMIT: abc1234
EOF

# Criar sessão mainbot-test temporária pra capturar injeção
tmux new-session -d -s mainbot-test 2>/dev/null || true

# Substituir mainbot por mainbot-test no script e rodar UMA iteração do check
bash -c '
  source /home/clawd/claude-tg-tmux/scripts/cronbot-monitor.sh &
  MONITOR_PID=$!
  sleep 5  # aguardar primeiro ciclo (não tem sleep 60 pois mockamos)
  kill $MONITOR_PID 2>/dev/null
' &

# Verificar injeção (manual — rodar check_tasks diretamente)
(
  BUS_DIR="$HOME/.claude/bus"
  MAINBOT="mainbot-test"
  log() { echo "$*"; }
  inject_mainbot() { /usr/bin/tmux send-keys -t "mainbot-test" "$1" Enter; echo "INJECT: $1"; }
  source /home/clawd/claude-tg-tmux/scripts/cronbot-monitor.sh
  check_tasks
)

tmux capture-pane -t mainbot-test -p | tail -5
tmux kill-session -t mainbot-test 2>/dev/null

# Verificar cleanup
ls "${BUS_DIR}/tasks/" "${BUS_DIR}/status/"
```

Esperado: injeção `[DEVBOT] Task 20260413-MONTEST CONCLUÍDA. Teste concluído com sucesso (commit: abc1234)` visível no pane.

- [ ] **Step 3: Commit**

```bash
cd /home/clawd/claude-tg-tmux
git add scripts/cronbot-monitor.sh
git commit -m "feat: cronbot-monitor.sh — loop de monitoramento de tasks, promises e sessões"
```

---

## Task 6: Launchers dos agentes

**Files:**
- Create: `scripts/devbot-launcher.sh`
- Create: `scripts/execbot-launcher.sh`
- Create: `scripts/cronbot-launcher.sh`

- [ ] **Step 1: Criar devbot-launcher.sh**

```bash
cat > /home/clawd/claude-tg-tmux/scripts/devbot-launcher.sh << 'EOF'
#!/bin/bash
# devbot-launcher.sh — lança devbot (Opus 4.6) com identidade específica

SESSION="devbot"
CLAUDE_BIN="/home/clawd/.npm-global/bin/claude"
AGENT_DIR="${HOME}/.claude/agents/devbot"
WORK_DIR="/home/clawd"

export HOME="/home/clawd"
export PATH="/home/clawd/.npm-global/bin:/home/clawd/.local/bin:/usr/local/bin:/usr/bin:/bin"
[ -s "$HOME/.nvm/nvm.sh" ] && source "$HOME/.nvm/nvm.sh"

# Matar sessão anterior se existir
/usr/bin/tmux kill-session -t "$SESSION" 2>/dev/null

# Criar sessão com Opus e CLAUDE.md do devbot
/usr/bin/tmux new-session -d -s "$SESSION" -c "$WORK_DIR" \
  "CLAUDE_CONFIG_DIR=${AGENT_DIR} ${CLAUDE_BIN} --model claude-opus-4-6 --dangerously-skip-permissions"

sleep 3
/usr/bin/tmux send-keys -t "$SESSION" Enter 2>/dev/null

echo "[devbot-launcher] Sessão '$SESSION' iniciada (Opus 4.6)"
EOF
chmod +x /home/clawd/claude-tg-tmux/scripts/devbot-launcher.sh
```

- [ ] **Step 2: Criar execbot-launcher.sh**

```bash
cat > /home/clawd/claude-tg-tmux/scripts/execbot-launcher.sh << 'EOF'
#!/bin/bash
# execbot-launcher.sh — lança execbot (Sonnet 4.6) com identidade específica

SESSION="execbot"
CLAUDE_BIN="/home/clawd/.npm-global/bin/claude"
AGENT_DIR="${HOME}/.claude/agents/execbot"
WORK_DIR="/home/clawd"

export HOME="/home/clawd"
export PATH="/home/clawd/.npm-global/bin:/home/clawd/.local/bin:/usr/local/bin:/usr/bin:/bin"
[ -s "$HOME/.nvm/nvm.sh" ] && source "$HOME/.nvm/nvm.sh"

/usr/bin/tmux kill-session -t "$SESSION" 2>/dev/null

/usr/bin/tmux new-session -d -s "$SESSION" -c "$WORK_DIR" \
  "CLAUDE_CONFIG_DIR=${AGENT_DIR} ${CLAUDE_BIN} --model claude-sonnet-4-6 --dangerously-skip-permissions"

sleep 3
/usr/bin/tmux send-keys -t "$SESSION" Enter 2>/dev/null

echo "[execbot-launcher] Sessão '$SESSION' iniciada (Sonnet 4.6)"
EOF
chmod +x /home/clawd/claude-tg-tmux/scripts/execbot-launcher.sh
```

- [ ] **Step 3: Criar cronbot-launcher.sh**

```bash
cat > /home/clawd/claude-tg-tmux/scripts/cronbot-launcher.sh << 'EOF'
#!/bin/bash
# cronbot-launcher.sh — lança sessão cronbot (shell monitor, não Claude)
# O cronbot é um bash loop, não um LLM — custo zero

SESSION="cronbot"
MONITOR="${HOME}/claude-tg-tmux/scripts/cronbot-monitor.sh"
WORK_DIR="/home/clawd"

/usr/bin/tmux kill-session -t "$SESSION" 2>/dev/null

# Lança o monitor shell diretamente — sem Claude
/usr/bin/tmux new-session -d -s "$SESSION" -c "$WORK_DIR" \
  "bash ${MONITOR}"

echo "[cronbot-launcher] Sessão '$SESSION' iniciada (monitor shell)"
/usr/bin/tmux list-sessions | grep "$SESSION"
EOF
chmod +x /home/clawd/claude-tg-tmux/scripts/cronbot-launcher.sh
```

- [ ] **Step 4: Verificar que os 3 launchers existem e são executáveis**

```bash
ls -la /home/clawd/claude-tg-tmux/scripts/*-launcher.sh
```

Esperado: `devbot-launcher.sh`, `execbot-launcher.sh`, `cronbot-launcher.sh` — todos com permissão `-rwxr-xr-x`

- [ ] **Step 5: Commit**

```bash
cd /home/clawd/claude-tg-tmux
git add scripts/devbot-launcher.sh scripts/execbot-launcher.sh scripts/cronbot-launcher.sh
git commit -m "feat: launchers para devbot (Opus), execbot (Sonnet) e cronbot (shell monitor)"
```

---

## Task 7: CLAUDE.md por agente

**Files:**
- Create: `~/.claude/agents/mainbot/CLAUDE.md`
- Create: `~/.claude/agents/devbot/CLAUDE.md`
- Create: `~/.claude/agents/execbot/CLAUDE.md`
- Create: `~/.claude/agents/cronbot/CLAUDE.md`

- [ ] **Step 1: Criar diretórios dos agentes**

```bash
mkdir -p ~/.claude/agents/{mainbot,devbot,execbot,cronbot}
```

- [ ] **Step 2: Criar CLAUDE.md do mainbot**

```bash
cat > ~/.claude/agents/mainbot/CLAUDE.md << 'EOF'
@/home/clawd/.claude/CLAUDE.md

# MAINBOT — Orquestrador

## Papel
Único ponto de contato com o Samyr. Nunca executa tarefas pesadas. Classifica, delega, entrega.

## Bus — Classificação Automática

Ao receber uma mensagem do Samyr, classificar SEMPRE antes de responder:

| Sinal | Ação |
|-------|------|
| Código, refactor, bug, deploy, SSH, script | Delegar ao devbot via bus-inject.sh |
| Preço, busca, leitura de arquivo, API rápida | Delegar ao execbot via bus-inject.sh |
| Cron, automação | Delegar ao devbot + avisar cronbot |
| "depois", "me avisa", "te falo", prazo | Criar promise via bus-promise.sh |
| Análise, DeFi, pergunta direta | Responder direto |
| Ambíguo | Confirmar com Samyr antes de agir |

Quando Samyr menciona explicitamente um agente ("fala pro dev"), respeitar sem reclassificar.

## Como delegar

```bash
bash ~/.claude/bus/../claude-tg-tmux/scripts/bus-inject.sh <agent> "<tarefa>" "<contexto>" "<critério>" "<arquivos>"
```

Após delegar: avisar Samyr ("Mandei pro dev. Te aviso quando concluir.") e ficar disponível.

## Como criar promise

```bash
bash ~/claude-tg-tmux/scripts/bus-promise.sh create "<slug>" "<YYYY-MM-DD HH:MM>" "<contexto>"
```

## Ao receber notificação do cronbot

Quando o cronbot injeta `[DEVBOT]` ou `[EXECBOT]` com resultado, filtrar e entregar ao Samyr limpo, sem narração interna.

## Regras invioláveis

- Nunca executar código em projetos — SEMPRE delegar ao devbot
- Nunca bloquear esperando resultado de tarefa longa
- Sempre estar disponível para nova mensagem do Samyr
EOF
```

- [ ] **Step 3: Criar CLAUDE.md do devbot**

```bash
cat > ~/.claude/agents/devbot/CLAUDE.md << 'EOF'
@/home/clawd/.claude/CLAUDE.md

# DEVBOT — Executor de Código

## Papel
Executa tarefas de código, deploy e SSH delegadas pelo mainbot. Modelo Opus 4.6 — poder máximo.

## Protocolo do Bus

Ao receber uma mensagem `[BUS TASK YYYYMMDD-NNN]`:

1. Ler o TASK_ID da mensagem
2. Criar lock: `bash ~/claude-tg-tmux/scripts/bus-worker.sh lock <TASK_ID>`
3. Atualizar status: `bash ~/claude-tg-tmux/scripts/bus-worker.sh status <TASK_ID> STARTED`
4. Executar a tarefa conforme TAREFA/CONTEXTO/CRITÉRIO
5. Ao concluir com sucesso: `bash ~/claude-tg-tmux/scripts/bus-worker.sh done <TASK_ID> "<resumo 1 linha>" "<commit hash>"`
6. Se falhar: `bash ~/claude-tg-tmux/scripts/bus-worker.sh fail <TASK_ID> "<descrição do erro>"`

## Regras

- Auto-validar antes de marcar DONE — conferir se critério foi atendido
- Resumo deve ser 1 linha limpa, sem narração
- Se falhar após 1 retry: marcar FAILED com erro claro, não tentar mais
- Nunca comunicar com Samyr diretamente — só via status do bus
EOF
```

- [ ] **Step 4: Criar CLAUDE.md do execbot**

```bash
cat > ~/.claude/agents/execbot/CLAUDE.md << 'EOF'
@/home/clawd/.claude/CLAUDE.md

# EXECBOT — Executor Rápido

## Papel
Executa tasks rápidas delegadas pelo mainbot: buscas, leitura de arquivos, consultas de API, análises leves. Modelo Sonnet 4.6.

## Protocolo do Bus

Ao receber uma mensagem `[BUS TASK YYYYMMDD-NNN]`:

1. Ler o TASK_ID
2. Criar lock: `bash ~/claude-tg-tmux/scripts/bus-worker.sh lock <TASK_ID>`
3. Executar — tasks rápidas não precisam atualizar status STARTED
4. Ao concluir: `bash ~/claude-tg-tmux/scripts/bus-worker.sh done <TASK_ID> "<resultado direto>"`
5. Se falhar: `bash ~/claude-tg-tmux/scripts/bus-worker.sh fail <TASK_ID> "<erro>"`

## Regras

- Tasks devem ser rápidas (< 2min) — se for mais longo, avisar no status e marcar DONE parcial
- Nunca comunicar com Samyr diretamente
- Nunca executar código destrutivo (rm, drop, delete) sem confirmação explícita na task
EOF
```

- [ ] **Step 5: Criar CLAUDE.md do cronbot**

```bash
cat > ~/.claude/agents/cronbot/CLAUDE.md << 'EOF'
@/home/clawd/.claude/CLAUDE.md

# CRONBOT — Monitor

## Papel
Monitoramento puro. Roda como shell script (cronbot-monitor.sh), não como Claude ativo.

## Regra absoluta
NUNCA executar tasks de desenvolvimento ou código.
NUNCA responder ao Samyr diretamente.
APENAS injetar alertas no mainbot via tmux send-keys.

## O que este agente faz
- Monitora tasks em ~/.claude/bus/tasks/ e status/
- Monitora promises em ~/.claude/bus/promises/
- Monitora saúde das sessões tmux devbot e execbot
- Valida jobs do crontab a cada hora
- Injeta alertas no mainbot quando detecta problema

Este arquivo existe apenas para referência — o cronbot é um shell script, não um Claude.
EOF
```

- [ ] **Step 6: Verificar todos os arquivos**

```bash
ls -la ~/.claude/agents/
for agent in mainbot devbot execbot cronbot; do
  echo "=== $agent ==="
  head -5 ~/.claude/agents/$agent/CLAUDE.md
done
```

- [ ] **Step 7: Commit**

```bash
cd /home/clawd/claude-tg-tmux
# Os CLAUDE.md ficam em ~/.claude/agents/ fora do repo — commitar scripts de setup
git add scripts/
git commit -m "feat: CLAUDE.md por agente (mainbot/devbot/execbot/cronbot) com protocolo do bus"
```

---

## Task 8: Atualizar mainbot-launcher.sh para usar CLAUDE.md específico

**Files:**
- Modify: `mainbot-launcher.sh`

- [ ] **Step 1: Ler o launcher atual**

Já lido: `/home/clawd/claude-tg-tmux/mainbot-launcher.sh` — linha 22-23 tem o comando de inicialização.

- [ ] **Step 2: Adicionar CLAUDE_CONFIG_DIR para mainbot**

```bash
# Editar linha do tmux new-session para incluir CLAUDE_CONFIG_DIR
sed -i 's|"$CLAUDE_BIN --channels|"CLAUDE_CONFIG_DIR=${HOME}/.claude/agents/mainbot '"$CLAUDE_BIN"' --channels|' \
  /home/clawd/claude-tg-tmux/mainbot-launcher.sh
```

Verificar resultado:
```bash
grep "new-session" /home/clawd/claude-tg-tmux/mainbot-launcher.sh
```

Esperado: linha contendo `CLAUDE_CONFIG_DIR=...` antes do binário.

**Nota:** `CLAUDE_CONFIG_DIR` faz o Claude CLI usar aquele diretório como `~/.claude/` — ele herda o CLAUDE.md local do agente, que por sua vez faz `@/home/clawd/.claude/CLAUDE.md` para incluir o global.

- [ ] **Step 3: Verificar que o arquivo ficou correto**

```bash
cat /home/clawd/claude-tg-tmux/mainbot-launcher.sh
```

- [ ] **Step 4: Commit**

```bash
cd /home/clawd/claude-tg-tmux
git add mainbot-launcher.sh
git commit -m "feat: mainbot-launcher usa CLAUDE_CONFIG_DIR para identidade específica do agente"
```

---

## Task 9: Script de inicialização de todo o sistema

**Files:**
- Create: `scripts/start-all-agents.sh`

- [ ] **Step 1: Criar start-all-agents.sh**

```bash
cat > /home/clawd/claude-tg-tmux/scripts/start-all-agents.sh << 'EOF'
#!/bin/bash
# start-all-agents.sh — inicializa todo o sistema multi-agent
# Uso: bash start-all-agents.sh [--no-mainbot]

SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log() { echo "[$(date '+%H:%M:%S')] $*"; }

# Setup do bus
log "Configurando estrutura do bus..."
bash "${SCRIPTS_DIR}/bus-setup.sh"

# Mainbot (opcional — normalmente já gerenciado pelo systemd)
if [[ "$1" != "--no-mainbot" ]]; then
  log "Mainbot: gerenciado pelo systemd (claude-mainbot.service) — skip"
fi

# Devbot
log "Iniciando devbot (Opus 4.6)..."
bash "${SCRIPTS_DIR}/devbot-launcher.sh"

# Execbot
log "Iniciando execbot (Sonnet 4.6)..."
bash "${SCRIPTS_DIR}/execbot-launcher.sh"

# Cronbot
log "Iniciando cronbot (monitor shell)..."
bash "${SCRIPTS_DIR}/cronbot-launcher.sh"

sleep 2
log "=== Sessões ativas ==="
/usr/bin/tmux list-sessions 2>/dev/null || echo "Nenhuma sessão tmux ativa"
EOF
chmod +x /home/clawd/claude-tg-tmux/scripts/start-all-agents.sh
```

- [ ] **Step 2: Dry run (sem iniciar realmente)**

```bash
# Verificar que todos os subscripts existem
for script in bus-setup.sh devbot-launcher.sh execbot-launcher.sh cronbot-launcher.sh; do
  [ -f "/home/clawd/claude-tg-tmux/scripts/$script" ] && echo "✅ $script" || echo "❌ $script AUSENTE"
done
```

Todos devem mostrar ✅.

- [ ] **Step 3: Commit final**

```bash
cd /home/clawd/claude-tg-tmux
git add scripts/start-all-agents.sh
git commit -m "feat: start-all-agents.sh — inicializa sistema multi-agent completo"
git push
```

---

## Self-Review

**Cobertura do spec:**

| Requisito do spec | Task |
|------------------|------|
| Estrutura ~/.claude/bus/ | Task 1 |
| bus-inject.sh | Task 2 |
| bus-worker.sh | Task 3 |
| bus-promise.sh | Task 4 |
| cronbot-monitor.sh (tasks, promises, sessões, crontab) | Task 5 |
| Launchers devbot/execbot/cronbot | Task 6 |
| CLAUDE.md por agente com protocolo | Task 7 |
| mainbot-launcher com CLAUDE_CONFIG_DIR | Task 8 |
| Script de inicialização | Task 9 |

**Fora do escopo (v1 — ok não incluir):**
- Analista como revisor: ✅ não incluído
- Paralelismo de tasks: ✅ não incluído
- Retry automático: ✅ cronbot avisa, mainbot decide

**Consistência de nomes:**
- `bus-worker.sh done/fail/lock/status/list/cleanup` — consistente em Tasks 3 e 7
- `bus-promise.sh create/list/resolve/check` — consistente em Tasks 4 e 7
- `bus-inject.sh <agent> <tarefa> ...` — consistente em Tasks 2 e 7
- TASK_ID format `YYYYMMDD-NNN` — consistente em todas as tasks

**Placeholders:** nenhum TBD ou TODO encontrado.
