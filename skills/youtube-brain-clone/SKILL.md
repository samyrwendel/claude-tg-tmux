---
name: youtube-brain-clone
description: Clone the knowledge of any YouTuber/content creator into a personal AI consultant using Google NotebookLM + Gemini. Extract video links from a channel, load them into NotebookLM, and connect to Gemini for deep content analysis — hooks, strategies, formats, topics. Use when user wants to analyze a creator's content strategy, clone a YouTuber's style, study content patterns, or create a knowledge base from a YouTube channel. Trigger words include clonar, clone brain, NotebookLM, analisar canal, estudar criador, content strategy, ganchos, hooks.
---

# YouTube Brain Clone

Clone any YouTuber's knowledge into an AI consultant via NotebookLM + Gemini.

## Overview

Turn an entire YouTube channel into a searchable, queryable AI consultant that analyzes content patterns, hooks, strategies, and style.

## Workflow

### Step 1: Extract video links from a channel

```bash
# Using yt-dlp to list all video URLs from a channel
yt-dlp --flat-playlist --print url "https://www.youtube.com/@CHANNEL_NAME/videos" > /tmp/channel-videos.txt
```

Or use the script:
```bash
{baseDir}/scripts/extract-channel-links.sh "https://www.youtube.com/@CHANNEL_NAME" /tmp/channel-videos.txt
```

### Step 2: Load into NotebookLM

1. Go to https://notebooklm.google.com
2. Create a new notebook
3. Add sources → YouTube URLs
4. Paste video links (NotebookLM accepts YouTube URLs directly)
5. Wait for processing

**Limits:** NotebookLM supports up to 50 sources per notebook. For large channels, prioritize recent/popular videos.

### Step 3: Connect Gemini

1. Open https://gemini.google.com
2. Connect your NotebookLM notebook as context
3. Now Gemini thinks on top of the loaded content

### Step 4: Query the cloned brain

Example queries for content strategy analysis:

- "Quais são os ganchos que esse criador mais usa e por que funcionam?"
- "Qual o formato de vídeo que mais engaja nesse canal?"
- "Analise a psicologia dos títulos dos últimos 20 vídeos"
- "Quais temas geram mais visualizações?"
- "Como esse criador estrutura seus CTAs?"
- "Extraia o framework de storytelling usado nos vídeos mais populares"

## Automation Script

For bulk extraction + formatting:

```bash
{baseDir}/scripts/extract-channel-links.sh <channel_url> [output_file] [max_videos]
```

## Chrome Extension (Optional)

The reel mentions a Chrome extension for bulk-selecting videos from a channel page. Alternatives:
- **Channel Crawler** — bulk extract YouTube links
- **yt-dlp** — CLI, no extension needed (recommended)

## Use Cases

1. **Content creators**: Study competitors' hook patterns and adapt for your niche
2. **Marketers**: Analyze what messaging works in a niche
3. **Learners**: Turn educational channels into queryable knowledge bases
4. **Researchers**: Deep-dive into a creator's evolution over time

## Notes

- NotebookLM is free (Google account required)
- Gemini connection may require Gemini Advanced for best results
- For channels with 100+ videos, batch into multiple notebooks
- yt-dlp is more reliable than browser extensions for link extraction
