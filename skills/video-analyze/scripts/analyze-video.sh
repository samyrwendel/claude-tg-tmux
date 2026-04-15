#!/bin/bash
# Analyze video via Gemini API (download + upload + prompt)
# Usage: analyze-video.sh <url_or_path> [prompt] [language]
#
# Requires: yt-dlp, python3, google-genai, GOOGLE_API_KEY env var
# If URL: downloads via yt-dlp. If local path: uses directly.
# Default prompt: general analysis. Default language: pt.

set -euo pipefail

INPUT="${1:?Usage: analyze-video.sh <url_or_path> [prompt] [language]}"
PROMPT="${2:-Analise este vídeo em detalhes. Descreva o que acontece, o que é dito, e dê um resumo completo.}"
LANG="${3:-pt}"

TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

VIDEO_FILE=""

# Check if input is URL or local file
if [[ "$INPUT" =~ ^https?:// ]]; then
  echo "⏬ Downloading video..." >&2
  VIDEO_FILE="$TMPDIR/video.mp4"
  yt-dlp -f "bv*+ba/b" --merge-output-format mp4 -o "$VIDEO_FILE" --no-post-overwrites "$INPUT" 2>/dev/null
  
  # If merge failed or file too big, try smaller format
  if [ ! -f "$VIDEO_FILE" ] || [ "$(stat -f%z "$VIDEO_FILE" 2>/dev/null || stat -c%s "$VIDEO_FILE" 2>/dev/null)" -gt 104857600 ]; then
    echo "⏬ Trying smaller format..." >&2
    rm -f "$VIDEO_FILE"
    yt-dlp -f "worst[ext=mp4]/worst" -o "$VIDEO_FILE" --no-post-overwrites "$INPUT" 2>/dev/null || \
    yt-dlp -f "b" --merge-output-format mp4 -o "$VIDEO_FILE" --no-post-overwrites "$INPUT" 2>/dev/null
  fi
else
  VIDEO_FILE="$INPUT"
fi

if [ ! -f "$VIDEO_FILE" ]; then
  echo "❌ Failed to get video file" >&2
  exit 1
fi

FILE_SIZE=$(stat -c%s "$VIDEO_FILE" 2>/dev/null || stat -f%z "$VIDEO_FILE" 2>/dev/null)
echo "📹 Video: $(basename "$VIDEO_FILE") ($(( FILE_SIZE / 1024 / 1024 ))MB)" >&2

# Compress if > 50MB
if [ "$FILE_SIZE" -gt 52428800 ] && command -v ffmpeg &>/dev/null; then
  echo "🗜️ Compressing video..." >&2
  COMPRESSED="$TMPDIR/compressed.mp4"
  ffmpeg -i "$VIDEO_FILE" -vf "scale='min(720,iw)':'min(720,ih)':force_original_aspect_ratio=decrease" \
    -c:v libx264 -crf 28 -preset fast -c:a aac -b:a 64k -y "$COMPRESSED" 2>/dev/null
  VIDEO_FILE="$COMPRESSED"
  FILE_SIZE=$(stat -c%s "$VIDEO_FILE" 2>/dev/null || stat -f%z "$VIDEO_FILE" 2>/dev/null)
  echo "📹 Compressed: $(( FILE_SIZE / 1024 / 1024 ))MB" >&2
fi

# Upload to Gemini and analyze
python3 - "$VIDEO_FILE" "$PROMPT" "$LANG" << 'PYEOF'
import sys, os, time

video_path = sys.argv[1]
prompt = sys.argv[2]
lang = sys.argv[3]

from google import genai

api_key = os.environ.get('GOOGLE_API_KEY') or os.environ.get('GEMINI_API_KEY')
if not api_key:
    print("❌ No GOOGLE_API_KEY or GEMINI_API_KEY set", file=sys.stderr)
    sys.exit(1)
client = genai.Client(api_key=api_key)

# Upload file
print("📤 Uploading to Gemini...", file=sys.stderr)
uploaded = client.files.upload(file=video_path)

# Wait for processing
print("⏳ Processing video...", file=sys.stderr)
while uploaded.state.name == "PROCESSING":
    time.sleep(3)
    uploaded = client.files.get(name=uploaded.name)

if uploaded.state.name == "FAILED":
    print(f"❌ Processing failed: {uploaded.state}", file=sys.stderr)
    sys.exit(1)

print("🧠 Analyzing...", file=sys.stderr)

full_prompt = f"""Idioma da resposta: {lang}

{prompt}"""

response = client.models.generate_content(
    model=os.environ.get('GEMINI_MODEL', 'gemini-2.0-flash'),
    contents=[uploaded, "\n\n", full_prompt]
)

print(response.text)

# Cleanup uploaded file
try:
    client.files.delete(name=uploaded.name)
except:
    pass
PYEOF
