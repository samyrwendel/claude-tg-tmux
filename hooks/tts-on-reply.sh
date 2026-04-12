#!/bin/bash
# TTS desabilitado temporariamente
exit 0
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

# Extract the sent message_id from tool response (format: "sent (id: XXXX)")
MSG_ID=$(echo "$INPUT" | python3 -c "
import sys, json, re
try:
    d = json.load(sys.stdin)
    resp = str(d.get('tool_response', ''))
    m = re.search(r'id:\s*(\d+)', resp)
    if m: print(m.group(1))
except: pass
" 2>/dev/null)

if [ -z "$CHAT_ID" ] || [ -z "$TEXT" ]; then exit 0; fi

# Skip short/trivial replies
WORD_COUNT=$(echo "$TEXT" | wc -w)
if [ "$WORD_COUNT" -lt 3 ]; then exit 0; fi

TOKEN=$(grep TELEGRAM_BOT_TOKEN ~/.claude/channels/telegram/.env 2>/dev/null | cut -d= -f2)

(
  # Send voice with the text as caption
  /home/clawd/.claude/hooks/send-voice.sh "$CHAT_ID" "$TEXT" "" "$TEXT"

  # Delete the original text message to avoid duplication
  if [ -n "$MSG_ID" ] && [ -n "$TOKEN" ]; then
    curl -s "https://api.telegram.org/bot${TOKEN}/deleteMessage" \
      -d "chat_id=${CHAT_ID}" \
      -d "message_id=${MSG_ID}" > /dev/null 2>&1
  fi
) &

exit 0
