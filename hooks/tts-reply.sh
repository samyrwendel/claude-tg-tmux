#!/bin/bash
# Generate TTS audio via ElevenLabs and return the file path
# Usage: tts-reply.sh "texto para falar"
# Output: path to generated .mp3 file

TEXT="$1"
if [ -z "$TEXT" ]; then exit 1; fi

ELEVENLABS_KEY="sk_f072918db49a1aed2e529d81351ea7adf26e19bf55ca6d21"
VOICE_ID="30D0RicpFBZ55TdpseEa"
MODEL="eleven_v3"
OUTFILE="/tmp/tts-reply-$(date +%s).mp3"

curl -s "https://api.elevenlabs.io/v1/text-to-speech/${VOICE_ID}" \
  -H "xi-api-key: ${ELEVENLABS_KEY}" \
  -H "Content-Type: application/json" \
  -d "{
    \"text\": $(echo "$TEXT" | jq -Rs .),
    \"model_id\": \"${MODEL}\",
    \"voice_settings\": {
      \"stability\": 0.85,
      \"similarity_boost\": 0.9,
      \"style\": 0.4,
      \"use_speaker_boost\": true
    }
  }" \
  --output "$OUTFILE" 2>/dev/null

if [ -s "$OUTFILE" ]; then
  echo "$OUTFILE"
else
  rm -f "$OUTFILE"
  exit 1
fi
