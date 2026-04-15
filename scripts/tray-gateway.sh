#!/bin/bash
# tray-gateway.sh — inicia o gateway WebSocket do clawd-tray
# Roda no servidor clawd, aguarda conexão do tray (Windows)

GATEWAY_DIR="${HOME}/claude-tg-tmux/tray/gateway"
LOG="/tmp/clawd-tray/gateway.log"
PID_FILE="/tmp/clawd-tray/gateway.pid"

mkdir -p /tmp/clawd-tray

# Carregar senha do .env
ENV_FILE="${HOME}/claude-tg-tmux/.env"
[ -f "$ENV_FILE" ] && source "$ENV_FILE"

export TRAY_PORT="${TRAY_PORT:-18791}"
export TRAY_PASSWORD="${TRAY_PASSWORD:-}"
export NODE_PATH="${HOME}/.npm-global/lib/node_modules"
export HOME="/home/clawd"
export PATH="/home/clawd/.npm-global/bin:/home/clawd/.local/bin:/usr/local/bin:/usr/bin:/bin"
[ -s "$HOME/.nvm/nvm.sh" ] && source "$HOME/.nvm/nvm.sh"

# Instalar ws se não tiver
if ! node -e "require('ws')" 2>/dev/null; then
  echo "Instalando dependência ws..."
  cd "$GATEWAY_DIR"
  npm install ws 2>/dev/null
fi

# Matar instância anterior
if [ -f "$PID_FILE" ]; then
  OLD_PID=$(cat "$PID_FILE")
  kill "$OLD_PID" 2>/dev/null
  rm -f "$PID_FILE"
fi

echo "Iniciando Clawd Tray Gateway na porta ${TRAY_PORT}..."
nohup node "${GATEWAY_DIR}/server.js" >> "$LOG" 2>&1 &
PID=$!
echo "$PID" > "$PID_FILE"
echo "Gateway iniciado (PID: ${PID})"
echo "Log: ${LOG}"
echo "WS:   ws://0.0.0.0:${TRAY_PORT}"
echo "HTTP: http://127.0.0.1:$((TRAY_PORT + 1))"
