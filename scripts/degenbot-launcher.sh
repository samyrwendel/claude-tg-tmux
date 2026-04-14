#!/bin/bash
# degenbot-launcher.sh — lança degenbot (Opus 4.6) via spawnbot

SESSION="degenbot"

if /usr/bin/tmux has-session -t "$SESSION" 2>/dev/null; then
  /usr/bin/tmux kill-session -t "$SESSION" 2>/dev/null
fi

bash "$(dirname "$0")/spawnbot.sh" create degenbot \
  "Degen 🦧 — Crypto, DeFi, Polymarket. Usa skills: polymarket, krystal, pools, lp-monitor. Responde só resultado, sem narração." \
  opus

echo "[degenbot-launcher] Sessão '$SESSION' iniciada (Opus 4.6)"
