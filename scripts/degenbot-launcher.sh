#!/bin/bash
# degenbot-launcher.sh — lança degenbot (Opus 4.6) via spawnbot

SESSION="degenbot"
TASK_DIR="/tmp/watchdog/tasks"

if /usr/bin/tmux has-session -t "$SESSION" 2>/dev/null; then
  /usr/bin/tmux kill-session -t "$SESSION" 2>/dev/null
fi

bash "$(dirname "$0")/spawnbot.sh" create degenbot \
  "Degen 🦧 — Crypto, DeFi, Polymarket. Usa skills: polymarket, krystal, pools, lp-monitor. Responde só resultado, sem narração." \
  opus /home/clawd/mainbot-degen

echo "[degenbot-launcher] Sessão '$SESSION' iniciada (Opus 4.6)"

# Recovery: injetar contexto se tinha task pendente
if [ -f "${TASK_DIR}/${SESSION}.task" ]; then
  sleep 8
  task_content=$(cat "${TASK_DIR}/${SESSION}.task")
  /usr/bin/tmux send-keys -t "$SESSION" "AVISO: Sessão anterior foi reiniciada pelo watchdog. Leia: ${TASK_DIR}/${SESSION}.pane" Enter 2>/dev/null
  rm -f "${TASK_DIR}/${SESSION}.task" "${TASK_DIR}/${SESSION}.pane"
  echo "[degenbot-launcher] Task recovery injetada"
fi
