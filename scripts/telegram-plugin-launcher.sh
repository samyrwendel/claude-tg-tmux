#!/bin/bash
# telegram-plugin-launcher.sh — inicia telegram plugin em tmux
# Detecta versão instalada automaticamente (não hardcoda)

export PATH="/home/clawd/.bun/bin:/home/clawd/.npm-global/bin:$PATH"

PLUGIN_BASE="/home/clawd/.claude/plugins/cache/claude-plugins-official/telegram"

# Detectar versão mais recente instalada
PLUGIN_DIR=$(ls -d "${PLUGIN_BASE}"/[0-9]* 2>/dev/null | sort -V | tail -1)

if [ -z "$PLUGIN_DIR" ] || [ ! -f "${PLUGIN_DIR}/server.ts" ]; then
  echo "[telegram-plugin] ERRO: plugin não encontrado em ${PLUGIN_BASE}" >&2
  exit 1
fi

echo "[telegram-plugin] Usando versão: $(basename "$PLUGIN_DIR")"

source /home/clawd/.claude/channels/telegram/.env

# Matar sessão anterior se existir
tmux kill-session -t telegram-plugin 2>/dev/null

tmux new-session -d -s telegram-plugin -c "$PLUGIN_DIR" \
  "source /home/clawd/.claude/channels/telegram/.env && bun server.ts"

echo "[telegram-plugin] Sessão tmux iniciada (dir: $PLUGIN_DIR)"
