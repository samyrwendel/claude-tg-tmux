#!/bin/bash
# devbot-launcher.sh — lança devbot (Opus 4.6) com identidade específica

SESSION="devbot"
CLAUDE_BIN="/home/clawd/.npm-global/bin/claude"
AGENT_DIR="${HOME}/.claude/agents/devbot"
WORK_DIR="/home/clawd"
TASK_DIR="/tmp/watchdog/tasks"

export HOME="/home/clawd"
export PATH="/home/clawd/.npm-global/bin:/home/clawd/.local/bin:/usr/local/bin:/usr/bin:/bin"
export CLAUDE_CODE_DISABLE_ADAPTIVE_THINKING=1
[ -s "$HOME/.nvm/nvm.sh" ] && source "$HOME/.nvm/nvm.sh"

/usr/bin/tmux kill-session -t "$SESSION" 2>/dev/null

/usr/bin/tmux new-session -d -s "$SESSION" -c "$WORK_DIR" \
  "$CLAUDE_BIN" --model claude-opus-4-6 --dangerously-skip-permissions --add-dir "$AGENT_DIR"

sleep 3
/usr/bin/tmux send-keys -t "$SESSION" Enter 2>/dev/null

echo "[devbot-launcher] Sessão '$SESSION' iniciada (Opus 4.6)"

# Recovery: injetar contexto se tinha task pendente
if [ -f "${TASK_DIR}/${SESSION}.task" ]; then
  sleep 5
  task_content=$(cat "${TASK_DIR}/${SESSION}.task")
  /usr/bin/tmux send-keys -t "$SESSION" "AVISO: Sessão anterior foi reiniciada pelo watchdog. Leia: ${TASK_DIR}/${SESSION}.pane" Enter 2>/dev/null
  rm -f "${TASK_DIR}/${SESSION}.task" "${TASK_DIR}/${SESSION}.pane"
  echo "[devbot-launcher] Task recovery injetada"
fi
