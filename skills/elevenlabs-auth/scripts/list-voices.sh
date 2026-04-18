#!/bin/bash
# Lista todas as vozes da conta com voice_id e nome
# Uso: ./list-voices.sh <api_key>

set -euo pipefail

API_KEY="${1:?Uso: $0 <api_key>}"

RESPONSE=$(curl -s -w "\n%{http_code}" \
  -H "xi-api-key: ${API_KEY}" \
  "https://api.elevenlabs.io/v1/voices" 2>/dev/null)

HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_CODE" != "200" ]; then
  echo "FAIL | HTTP ${HTTP_CODE}"
  exit 1
fi

echo "$BODY" | jq -r '.voices[] | "\(.voice_id) | \(.name)"'
