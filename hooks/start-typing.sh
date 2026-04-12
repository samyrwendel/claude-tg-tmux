#!/bin/bash
# UserPromptSubmit: sinaliza início de processamento para o typing daemon

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

CHAT_ID="${CHAT_ID:-30289486}"
echo "$CHAT_ID" > /tmp/claude-typing-chat
touch /tmp/claude-processing

exit 0
