#!/bin/bash
# Send TTS voice after Telegram reply (PostToolUse hook)
INPUT=$(cat)

CHAT_ID=$(echo "$INPUT" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('tool_input', {}).get('chat_id', ''))
except: pass
" 2>/dev/null)

TEXT=$(echo "$INPUT" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    print(d.get('tool_input', {}).get('text', ''))
except: pass
" 2>/dev/null)

if [ -z "$CHAT_ID" ] || [ -z "$TEXT" ]; then exit 0; fi

# Skip short/trivial replies and emoji-only
WORD_COUNT=$(echo "$TEXT" | wc -w)
if [ "$WORD_COUNT" -lt 3 ]; then exit 0; fi

/home/clawd/.claude/hooks/send-voice.sh "$CHAT_ID" "$TEXT" "" "$TEXT" &
exit 0
