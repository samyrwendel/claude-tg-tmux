#!/bin/bash
# Gera áudio de teste com uma voz específica
# Uso: ./test-voice.sh <api_key> <voice_id> <texto> <output.mp3>

set -euo pipefail

API_KEY="${1:?Uso: $0 <api_key> <voice_id> <texto> <output.mp3>}"
VOICE_ID="${2:?Faltou voice_id}"
TEXT="${3:?Faltou texto}"
OUTPUT="${4:-/tmp/elevenlabs-test.mp3}"

HTTP_CODE=$(curl -s -o "$OUTPUT" -w "%{http_code}" \
  -X POST \
  -H "xi-api-key: ${API_KEY}" \
  -H "Content-Type: application/json" \
  -d "{\"text\": \"${TEXT}\", \"model_id\": \"eleven_multilingual_v2\"}" \
  "https://api.elevenlabs.io/v1/text-to-speech/${VOICE_ID}")

if [ "$HTTP_CODE" = "200" ]; then
  SIZE=$(stat -c%s "$OUTPUT" 2>/dev/null || stat -f%z "$OUTPUT" 2>/dev/null)
  echo "OK | ${OUTPUT} (${SIZE} bytes)"
else
  echo "FAIL | HTTP ${HTTP_CODE}"
  cat "$OUTPUT" 2>/dev/null
  rm -f "$OUTPUT"
  exit 1
fi
