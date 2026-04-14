#!/bin/bash
# nanobot-launcher.sh — inicia Claude Code nanobot em tmux com Telegram plugin

export PATH="/home/clawd/.bun/bin:/home/clawd/.npm-global/bin:$PATH"

tmux new-session -d -s nanobot -c /home/clawd \
  '/home/clawd/.npm-global/bin/claude --channels plugin:telegram@claude-plugins-official --permission-mode bypassPermissions --dangerously-skip-permissions'

echo "[nanobot-launcher] Sessão nanobot iniciada"
