#!/bin/bash
# UserPromptSubmit: sinaliza início de processamento para o typing daemon
# SOMENTE quando a mensagem vier do Telegram (contém chat_id no prompt)

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

# Sem chat_id = não é Telegram = não iniciar spinner
if [ -z "$CHAT_ID" ]; then
  exit 0
fi

echo "$CHAT_ID" > /tmp/claude-typing-chat
touch /tmp/claude-processing

exit 0
