#!/bin/bash
# nanobot-launcher.sh — inicia Claude Code nanobot em tmux

export PATH="/home/clawd/.bun/bin:/home/clawd/.npm-global/bin:$PATH"

AGENT_NAME="nanobot"
TASK_DIR="/tmp/watchdog/tasks"

# Deletar sessão anterior se existir
tmux kill-session -t "$AGENT_NAME" 2>/dev/null

tmux new-session -d -s "$AGENT_NAME" -c /home/clawd \
  "/home/clawd/.npm-global/bin/claude --channels plugin:telegram@claude-plugins-official --permission-mode bypassPermissions --dangerously-skip-permissions"

echo "[nanobot-launcher] Sessão nanobot iniciada"

# Recovery: se tinha task pendente, injetar contexto após 5s
if [ -f "${TASK_DIR}/${AGENT_NAME}.task" ]; then
  sleep 5
  task_content=$(cat "${TASK_DIR}/${AGENT_NAME}.task")
  tmux send-keys -t "$AGENT_NAME" "AVISO: Sessão anterior foi reiniciada pelo watchdog. Contexto: $task_content" Enter 2>/dev/null
  rm -f "${TASK_DIR}/${AGENT_NAME}.task" "${TASK_DIR}/${AGENT_NAME}.pane"
  echo "[nanobot-launcher] Task recovery injetada"
fi
