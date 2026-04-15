#!/bin/bash
# alert-mainbot.sh — envia alerta para o mainbot via arquivo (não tmux send-keys)
# Uso: bash alert-mainbot.sh "mensagem"
# O hook cronbot-alerts.sh drena esses arquivos no próximo turno do Claude.

MSG="${1:?Mensagem obrigatória}"
ALERT_DIR="/tmp/cronbot/alerts"
mkdir -p "$ALERT_DIR"

TS=$(TZ=America/Manaus date '+%Y%m%d-%H%M%S')
echo "$MSG" > "${ALERT_DIR}/${TS}-$$.alert"
