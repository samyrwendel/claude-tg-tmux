#!/bin/bash
# PreToolUse hook for mcp__plugin_telegram_telegram__reply
# Intercepts text replies, sends voice+caption instead, blocks text message

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

# Respect /tts off toggle
[ -f /tmp/claude-tts-disabled ] && exit 0

# Allow short/trivial replies as text (no TTS)
WORD_COUNT=$(echo "$TEXT" | wc -w)
if [ "$WORD_COUNT" -lt 3 ]; then exit 0; fi

# Generate TTS and send voice+caption (blocking — must complete before hook returns)
/home/clawd/.claude/hooks/send-voice.sh "$CHAT_ID" "$TEXT" "" "$TEXT"
RESULT=$?

if [ $RESULT -eq 0 ]; then
  # Block the text reply — voice was sent successfully
  echo '{"decision":"block","reason":"Voice message sent"}'
fi
# If TTS failed, exit 0 = allow text reply to go through normally
