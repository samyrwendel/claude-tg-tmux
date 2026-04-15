---
name: video-analyze
description: Analyze videos using Gemini AI vision. Use when the user sends a video URL (Instagram, TikTok, YouTube, Twitter/X, or any yt-dlp-compatible URL) or a local video file and asks to watch, analyze, describe, or understand its visual content. Trigger words include assistir, analisar vídeo, watch video, o que acontece, describe video, analyze video. Do NOT use for audio-only transcription (use instagram-transcribe instead). Use this when visual analysis is needed.
---

# Video Analyze

Upload videos to Gemini API for full visual + audio analysis.

## Quick start

```bash
GOOGLE_API_KEY=<key> {baseDir}/scripts/analyze-video.sh <url_or_path> [prompt] [language]
```

## Examples

```bash
# General analysis (Portuguese)
{baseDir}/scripts/analyze-video.sh "https://www.instagram.com/reel/ABC123/"

# Specific question about the video
{baseDir}/scripts/analyze-video.sh "https://youtu.be/xyz" "What product is being advertised?" en

# Local file
{baseDir}/scripts/analyze-video.sh /tmp/video.mp4 "Descreva passo a passo"
```

## Requirements

- `yt-dlp` for URL downloads
- `python3` + `google-genai` package
- `GOOGLE_API_KEY` env var (from clawdbot.json or Bitwarden)
- Optional: `ffmpeg` for compression of large files

## Workflow

1. User sends video URL + indicates they want visual analysis
2. Get GOOGLE_API_KEY from clawdbot.json
3. Run the script with URL and optional custom prompt
4. Return the analysis to the user

## When to use this vs instagram-transcribe

- **video-analyze**: User wants to SEE what happens (visual content, actions, products, scenes)
- **instagram-transcribe**: User just wants the spoken words as text (audio transcription)
- If unclear, prefer video-analyze as it covers both visual + audio

## Limits

- Max file size: ~2GB (Gemini Files API limit)
- Files auto-compress via ffmpeg if >50MB
- Uploaded files expire in 48h (auto-deleted after analysis)
- Model: gemini-2.5-flash (fast + capable)
