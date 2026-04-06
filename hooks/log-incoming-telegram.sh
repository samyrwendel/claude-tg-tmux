#!/bin/bash
# Log incoming Telegram messages to BigQuery (UserPromptSubmit hook)
export GOOGLE_APPLICATION_CREDENTIALS=/home/clawd/.config/gcloud/service-account.json

INPUT=$(cat)

# Extract chat_id and message text from the channel tag in the prompt
CHAT_ID=$(echo "$INPUT" | python3 -c "
import sys, json, re
try:
    d = json.load(sys.stdin)
    prompt = d.get('prompt', '')
    m = re.search(r'chat_id=\"(\d+)\"', prompt)
    if m: print(m.group(1))
except: pass
" 2>/dev/null)

TEXT=$(echo "$INPUT" | python3 -c "
import sys, json, re
try:
    d = json.load(sys.stdin)
    prompt = d.get('prompt', '')
    m = re.search(r'<channel[^>]*>(.*?)</channel>', prompt, re.DOTALL)
    if m:
        text = m.group(1).strip()
        if text and text != '(voice message)':
            print(text)
except: pass
" 2>/dev/null)

if [ -z "$TEXT" ] || [ -z "$CHAT_ID" ]; then
    exit 0
fi

SESSION_ID="tg-${CHAT_ID}-$(date +%Y%m%d)"

node /home/clawd/clawd/bigquery-rag/log-interaction.js \
    --role user \
    --content "$TEXT" \
    --session "$SESSION_ID" \
    --source "telegram-${CHAT_ID}" &

exit 0
