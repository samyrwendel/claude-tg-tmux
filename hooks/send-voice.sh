#!/bin/bash
# Generate TTS and send as Telegram voice message
# Usage: send-voice.sh <chat_id> "texto para falar" [reply_to_message_id]

CHAT_ID="$1"
TEXT="$2"
REPLY_TO="$3"
CAPTION="$4"

if [ -z "$CHAT_ID" ] || [ -z "$TEXT" ]; then
  echo "Usage: send-voice.sh <chat_id> \"text\" [reply_to]" >&2
  exit 1
fi

TOKEN=$(grep TELEGRAM_BOT_TOKEN ~/.claude/channels/telegram/.env 2>/dev/null | cut -d= -f2)
ENV_FILE="$(dirname "$0")/../.env"
[ -f "$ENV_FILE" ] && source "$ENV_FILE"
ELEVENLABS_KEY="${ELEVENLABS_API_KEY}"
VOICE_ID="${ELEVENLABS_VOICE_ID:-30D0RicpFBZ55TdpseEa}"
MODEL="eleven_v3"
TS=$(date +%s)

# 1. Generate TTS MP3
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
  --output "/tmp/tts-${TS}.mp3" 2>/dev/null

if [ ! -s "/tmp/tts-${TS}.mp3" ]; then
  echo "TTS generation failed" >&2
  exit 1
fi

# 2. Convert to OGG Opus (Telegram voice format)
ffmpeg -i "/tmp/tts-${TS}.mp3" -c:a libopus -b:a 64k -ac 1 "/tmp/tts-${TS}.ogg" -y 2>/dev/null

if [ ! -s "/tmp/tts-${TS}.ogg" ]; then
  echo "OGG conversion failed" >&2
  exit 1
fi

# 3. Send as voice message
EXTRA=()
if [ -n "$REPLY_TO" ]; then
  EXTRA+=(-F "reply_to_message_id=$REPLY_TO")
fi
if [ -n "$CAPTION" ]; then
  CAPTION_TRIMMED=$(echo "$CAPTION" | cut -c1-1024)
  EXTRA+=(-F "caption=$CAPTION_TRIMMED" -F "parse_mode=Markdown")
fi

RESULT=$(curl -s "https://api.telegram.org/bot${TOKEN}/sendVoice" \
  -F "chat_id=${CHAT_ID}" \
  -F "voice=@/tmp/tts-${TS}.ogg" \
  "${EXTRA[@]}" 2>&1)

MSG_ID=$(echo "$RESULT" | jq -r '.result.message_id // empty')
echo "sent voice msg_id=${MSG_ID}"

# Cleanup
rm -f "/tmp/tts-${TS}.mp3" "/tmp/tts-${TS}.ogg"
