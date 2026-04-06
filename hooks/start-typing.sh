#!/bin/bash
# Start typing indicator for Telegram when processing
# Reads UserPromptSubmit hook stdin to detect voice vs text
# Typing is stopped by stop-typing.sh (PostToolUse on reply)

PID_FILE="/tmp/typing-indicator.pid"
ACTION_FILE="/tmp/typing-action"
TOKEN=$(grep TELEGRAM_BOT_TOKEN ~/.claude/channels/telegram/.env 2>/dev/null | cut -d= -f2)

if [ -z "$TOKEN" ]; then exit 0; fi

# Read hook input to detect chat_id and message type
INPUT=$(cat)

CHAT_ID=$(echo "$INPUT" | python3 -c "
import sys, json, re
try:
    d = json.load(sys.stdin)
    prompt = d.get('prompt', '')
    m = re.search(r'chat_id=\"(\d+)\"', prompt)
    if m: print(m.group(1))
except: pass
" 2>/dev/null)

# Default to known chat if not detected
CHAT_ID="${CHAT_ID:-30289486}"

# Detect if it's a voice message
IS_VOICE=$(echo "$INPUT" | python3 -c "
import sys, json, re
try:
    d = json.load(sys.stdin)
    prompt = d.get('prompt', '')
    if 'attachment_kind=\"voice\"' in prompt or '(voice message)' in prompt:
        print('1')
except: pass
" 2>/dev/null)

ACTION="typing"
if [ "$IS_VOICE" = "1" ]; then
    ACTION="record_voice"
fi

# Store action for potential reuse
echo "$ACTION" > "$ACTION_FILE"

# Check if already running
if [ -f "$PID_FILE" ]; then
    pid=$(cat "$PID_FILE")
    if kill -0 "$pid" 2>/dev/null; then
        exit 0
    fi
    rm -f "$PID_FILE"
fi

# Start indicator in background
(
    echo $$ > "$PID_FILE"
    while true; do
        curl -s "https://api.telegram.org/bot${TOKEN}/sendChatAction" \
            -d "chat_id=${CHAT_ID}" -d "action=${ACTION}" > /dev/null 2>&1
        sleep 4
    done
) &

exit 0
