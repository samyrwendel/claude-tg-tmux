#!/bin/bash
# Extract all video URLs from a YouTube channel
# Usage: extract-channel-links.sh <channel_url> [output_file] [max_videos]

set -euo pipefail

CHANNEL_URL="${1:?Usage: $0 <channel_url> [output_file] [max_videos]}"
OUTPUT="${2:-/tmp/channel-videos.txt}"
MAX="${3:-50}"

echo "📺 Extracting videos from: $CHANNEL_URL"
echo "📄 Output: $OUTPUT"
echo "🔢 Max videos: $MAX"

# Ensure URL ends with /videos for full listing
VIDEOS_URL="${CHANNEL_URL%/}"
[[ "$VIDEOS_URL" != */videos ]] && VIDEOS_URL="$VIDEOS_URL/videos"

# Extract video URLs
yt-dlp --flat-playlist --print url --playlist-end "$MAX" "$VIDEOS_URL" > "$OUTPUT" 2>/dev/null

COUNT=$(wc -l < "$OUTPUT")
echo "✅ Extracted $COUNT video URLs"
echo ""

if [ "$COUNT" -gt 50 ]; then
    echo "⚠️  NotebookLM supports max 50 sources per notebook."
    echo "   Consider splitting into multiple notebooks."
    echo "   First 50 saved to: ${OUTPUT%.txt}-batch1.txt"
    head -50 "$OUTPUT" > "${OUTPUT%.txt}-batch1.txt"
fi

# Also generate formatted list for easy copy-paste
echo ""
echo "=== URLs (copy-paste to NotebookLM) ==="
cat "$OUTPUT"
