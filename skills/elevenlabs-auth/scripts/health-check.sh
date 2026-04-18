#!/bin/bash
# Testa se a API key do ElevenLabs está funcionando
# Uso: ./health-check.sh <api_key>
# Retorna: OK / FAIL + motivo

set -euo pipefail

API_KEY="${1:?Uso: $0 <api_key>}"

RESPONSE=$(curl -s -w "\n%{http_code}" \
  -H "xi-api-key: ${API_KEY}" \
  "https://api.elevenlabs.io/v1/user" 2>/dev/null)

HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | sed '$d')

case "$HTTP_CODE" in
  200)
    CHAR_COUNT=$(echo "$BODY" | jq -r '.subscription.character_count // "?"')
    CHAR_LIMIT=$(echo "$BODY" | jq -r '.subscription.character_limit // "?"')
    TIER=$(echo "$BODY" | jq -r '.subscription.tier // "?"')
    echo "OK | tier=${TIER} | usado=${CHAR_COUNT}/${CHAR_LIMIT}"
    ;;
  401|403)
    echo "FAIL | key inválida (HTTP ${HTTP_CODE})"
    exit 1
    ;;
  *)
    MSG=$(echo "$BODY" | jq -r '.detail.message // .detail // empty' 2>/dev/null || true)
    echo "FAIL | HTTP ${HTTP_CODE} | ${MSG:-erro desconhecido}"
    exit 1
    ;;
esac
