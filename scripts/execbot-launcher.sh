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
  "$CLAUDE_BIN" --model claude-sonnet-4-6 --dangerously-skip-permissions --add-dir "$AGENT_DIR"

sleep 3
/usr/bin/tmux send-keys -t "$SESSION" Enter 2>/dev/null

echo "[execbot-launcher] Sessão '$SESSION' iniciada (Sonnet 4.6)"
