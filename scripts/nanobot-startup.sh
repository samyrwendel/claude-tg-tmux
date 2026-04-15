#!/bin/bash
# nanobot-startup.sh — inicia Nanobot via PM2 (MCP server + Telegram bridge)
# Gerenciado por PM2 — autorestart em caso de falha
# NÃO iniciar manualmente se PM2 já estiver gerenciando

NANOBOT_DIR="/home/clawd/nanobot"
LOG_DIR="/tmp/nanobot"

mkdir -p "$LOG_DIR"

# Verificar se nanobot e nanobot-telegram já estão rodando via PM2
NANOBOT_STATUS=$(pm2 list | grep "nanobot " | grep -v "nanobot-" | awk '{print $10}')
TELEGRAM_STATUS=$(pm2 list | grep "nanobot-telegram" | awk '{print $10}')

if [ "$NANOBOT_STATUS" = "online" ] && [ "$TELEGRAM_STATUS" = "online" ]; then
  echo "[$(date '+%H:%M:%S')] Nanobot + Telegram bridge já estão rodando via PM2"
else
  echo "[$(date '+%H:%M:%S')] Iniciando nanobot via PM2 (MCP server + Telegram bridge)..."
  cd "$NANOBOT_DIR"
  pm2 start ecosystem.config.js
fi

# Verificar se o Telegram plugin do gateway está rodando (para @mentordegenbot)
# O gateway gerencia nativamente, mas确保 o bun server.ts NÃO está rodando (conflito)
if ps aux | grep -q "bun.*telegram.*server.ts" | grep -v grep; then
  echo "[$(date '+%H:%M:%S')] AVISO: bun server.ts está rodando — verificar se é necessário"
fi

sleep 3
echo "[$(date '+%H:%M:%S')] Status:"
pm2 list | grep -E "nanobot|clawdbot"
