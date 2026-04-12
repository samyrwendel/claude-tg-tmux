#!/bin/bash
# PostToolUse (reply): sinaliza fim de processamento e para o spinner

rm -f /tmp/claude-processing /tmp/claude-typing-chat

# Para o spinner animado se estiver rodando
bash /home/clawd/.claude/hooks/telegram-spinner.sh stop 2>/dev/null

exit 0
