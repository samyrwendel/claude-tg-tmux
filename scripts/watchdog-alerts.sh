#!/bin/bash
# watchdog-alerts.sh — checa alerts pendentes do watchdog
# Rodar no startup do mainbot ou via cron

ALERT_DIR="/tmp/watchdog/alerts"
PROCESSED_DIR="/tmp/watchdog/processed"

mkdir -p "$ALERT_DIR" "$PROCESSED_DIR"

for alert in "$ALERT_DIR"/*.alert; do
  [ -f "$alert" ] || continue
  content=$(cat "$alert")
  filename=$(basename "$alert")
  
  echo "watchdog alert: $content"
  
  # Mover para processed
  mv "$alert" "${PROCESSED_DIR}/${filename}"
done
