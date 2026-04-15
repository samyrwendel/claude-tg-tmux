#!/bin/bash
# nanobot-launcher.sh — NanoBot Claude Code session (SEM Telegram plugin)
# O telegram-bridge.js é iniciado separadamente pelo start-all-agents

export PATH="/home/clawd/.bun/bin:/home/clawd/.npm-global/bin:$PATH"
AGENT_NAME="nanobot"
TASK_DIR="/tmp/watchdog/tasks"

# Matar sessão anterior
tmux kill-session -t "$AGENT_NAME" 2>/dev/null

# Iniciar Claude Code nanobot (SEM --channels plugin:telegram)
tmux new-session -d -s "$AGENT_NAME" -c /home/clawd \
  "/home/clawd/.npm-global/bin/claude --permission-mode bypassPermissions --dangerously-skip-permissions"

echo "[nanobot-launcher] Sessão nanobot iniciada (Claude Code Sonnet 4.6, sem Telegram plugin)"

# Recovery: se tinha task pendente, injetar contexto após 5s
if [ -f "${TASK_DIR}/${AGENT_NAME}.task" ]; then
  sleep 5
  task_content=$(cat "${TASK_DIR}/${AGENT_NAME}.task")
  tmux send-keys -t "$AGENT_NAME" "AVISO: Sessão reiniciada pelo watchdog. Contexto: $task_content" Enter 2>/dev/null
  rm -f "${TASK_DIR}/${AGENT_NAME}.task" "${TASK_DIR}/${AGENT_NAME}.pane"
  echo "[nanobot-launcher] Task recovery injetada"
fi
