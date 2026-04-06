#!/bin/bash
# Hook: PostToolUse for telegram reply - logs outgoing messages to BQ
# Runs async (fire and forget) to not slow down replies
export GOOGLE_APPLICATION_CREDENTIALS=/home/clawd/.config/gcloud/service-account.json
INPUT=$(cat)
echo "$INPUT" | node /home/clawd/clawd/bigquery-rag/log-interaction.js &
exit 0
