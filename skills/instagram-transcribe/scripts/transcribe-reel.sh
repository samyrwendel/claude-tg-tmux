#!/bin/bash
# Transcribe Instagram Reels/videos via yt-dlp + OpenAI Whisper API
# Usage: transcribe-reel.sh <instagram_url> [language] [output_file]
#
# Requires: yt-dlp, curl, OPENAI_API_KEY env var
# Language defaults to "pt" if not specified

set -euo pipefail

URL="${1:?Usage: transcribe-reel.sh <instagram_url> [language] [output_file]}"
LANG="${2:-pt}"
OUTPUT="${3:-}"

TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

AUDIO_FILE="$TMPDIR/audio.m4a"

# Download audio
yt-dlp -f "ba/b" -o "$AUDIO_FILE" --no-post-overwrites "$URL" 2>/dev/null

# If ffmpeg available, convert to mp3 for better compatibility
if command -v ffmpeg &>/dev/null; then
  MP3_FILE="$TMPDIR/audio.mp3"
  ffmpeg -i "$AUDIO_FILE" -q:a 2 "$MP3_FILE" -y 2>/dev/null
  AUDIO_FILE="$MP3_FILE"
fi

# Transcribe via Whisper API
TRANSCRIPT=$(curl -s https://api.openai.com/v1/audio/transcriptions \
  -H "Authorization: Bearer $OPENAI_API_KEY" \
  -F file="@$AUDIO_FILE" \
  -F model="whisper-1" \
  -F language="$LANG" \
  -F response_format="text")

if [ -n "$OUTPUT" ]; then
  echo "$TRANSCRIPT" > "$OUTPUT"
  echo "Saved to $OUTPUT"
else
  echo "$TRANSCRIPT"
fi
