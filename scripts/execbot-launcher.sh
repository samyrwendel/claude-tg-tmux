#!/bin/bash
# execbot-launcher.sh — lança execbot (Sonnet 4.6) com identidade específica

SESSION="execbot"
CLAUDE_BIN="/home/clawd/.npm-global/bin/claude"
AGENT_DIR="${HOME}/.claude/agents/execbot"
WORK_DIR="/home/clawd/mainbot-exec"
TASK_DIR="/tmp/watchdog/tasks"

export HOME="/home/clawd"
export PATH="/home/clawd/.npm-global/bin:/home/clawd/.local/bin:/usr/local/bin:/usr/bin:/bin"
[ -s "$HOME/.nvm/nvm.sh" ] && source "$HOME/.nvm/nvm.sh"

/usr/bin/tmux kill-session -t "$SESSION" 2>/dev/null

/usr/bin/tmux new-session -d -s "$SESSION" -c "$WORK_DIR" \
  "$CLAUDE_BIN" --model claude-sonnet-4-6 --dangerously-skip-permissions --add-dir "$AGENT_DIR" --add-dir "/home/clawd/mainbot-exec"

sleep 3
/usr/bin/tmux send-keys -t "$SESSION" Enter 2>/dev/null

echo "[execbot-launcher] Sessão '$SESSION' iniciada (Sonnet 4.6)"

# Recovery
if [ -f "${TASK_DIR}/${SESSION}.task" ]; then
  sleep 5
  task_content=$(cat "${TASK_DIR}/${SESSION}.task")
  /usr/bin/tmux send-keys -t "$SESSION" "AVISO: Sessão anterior foi reiniciada pelo watchdog. Leia: ${TASK_DIR}/${SESSION}.pane" Enter 2>/dev/null
  rm -f "${TASK_DIR}/${SESSION}.task" "${TASK_DIR}/${SESSION}.pane"
  echo "[execbot-launcher] Task recovery injetada"
fi
