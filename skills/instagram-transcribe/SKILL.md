---
name: instagram-transcribe
description: Transcribe Instagram Reels and videos to text. Use when the user sends an Instagram URL (reel, post with video, IGTV) and wants a transcription, summary, or translation of the audio content. Also handles any yt-dlp-compatible video URL (TikTok, YouTube Shorts, Twitter/X videos).
---

# Instagram Transcribe

Download audio from Instagram Reels/videos and transcribe via OpenAI Whisper.

## Quick start

```bash
{baseDir}/scripts/transcribe-reel.sh <url> [language] [output_file]
```

Examples:
```bash
# Portuguese reel (default language: pt)
{baseDir}/scripts/transcribe-reel.sh "https://www.instagram.com/reel/ABC123/"

# English video
{baseDir}/scripts/transcribe-reel.sh "https://www.instagram.com/reel/ABC123/" en

# Save to file
{baseDir}/scripts/transcribe-reel.sh "https://www.instagram.com/reel/ABC123/" pt /tmp/transcript.txt
```

## Requirements

- `yt-dlp` (install: `pip install --break-system-packages yt-dlp`)
- `OPENAI_API_KEY` env var
- Optional: `ffmpeg` for better audio conversion

## Supported URLs

Any yt-dlp-compatible URL works:
- Instagram Reels/Posts/IGTV
- TikTok videos
- YouTube/YouTube Shorts
- Twitter/X videos

## Workflow

1. Receive URL from user
2. Run the script to download audio + transcribe
3. Return plain text transcription
4. Optionally summarize or translate based on user request
