#!/bin/bash
# telegram-plugin-launcher.sh — inicia telegram plugin em tmux

export PATH="/home/clawd/.bun/bin:/home/clawd/.npm-global/bin:$PATH"

cd /home/clawd/.claude/plugins/cache/claude-plugins-official/telegram/0.0.5
source /home/clawd/.claude/channels/telegram/.env

tmux new-session -d -s telegram-plugin -c /home/clawd/.claude/plugins/cache/claude-plugins-official/telegram/0.0.5 \
  'source /home/clawd/.claude/channels/telegram/.env && bun server.ts'

echo "[telegram-plugin] Sessão tmux iniciada"
