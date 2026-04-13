#!/bin/bash
# cronbot-launcher.sh — lança sessão cronbot (shell monitor, não Claude)
# O cronbot é um bash loop, não um LLM — custo zero

SESSION="cronbot"
MONITOR="${HOME}/claude-tg-tmux/scripts/cronbot-monitor.sh"
WORK_DIR="/home/clawd"

/usr/bin/tmux kill-session -t "$SESSION" 2>/dev/null

/usr/bin/tmux new-session -d -s "$SESSION" -c "$WORK_DIR" \
  "bash ${MONITOR}"

echo "[cronbot-launcher] Sessão '$SESSION' iniciada (monitor shell)"
/usr/bin/tmux list-sessions | grep "$SESSION"
