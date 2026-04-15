#!/bin/bash
# spawnbot-launcher.sh — lança spawnbot (Sonnet 4.6) como agente de contratação

SESSION="spawnbot"
CLAUDE_BIN="/home/clawd/.npm-global/bin/claude"
AGENT_DIR="${HOME}/.claude/agents/spawnbot"
WORK_DIR="/home/clawd"

export HOME="/home/clawd"
export PATH="/home/clawd/.npm-global/bin:/home/clawd/.local/bin:/usr/local/bin:/usr/bin:/bin"
[ -s "$HOME/.nvm/nvm.sh" ] && source "$HOME/.nvm/nvm.sh"

/usr/bin/tmux kill-session -t "$SESSION" 2>/dev/null

/usr/bin/tmux new-session -d -s "$SESSION" -c "$WORK_DIR" \
  "$CLAUDE_BIN" --model claude-sonnet-4-6 --dangerously-skip-permissions --add-dir "$AGENT_DIR"

sleep 3
/usr/bin/tmux send-keys -t "$SESSION" Enter 2>/dev/null

echo "[spawnbot-launcher] Sessão '$SESSION' iniciada (Sonnet 4.6)"
