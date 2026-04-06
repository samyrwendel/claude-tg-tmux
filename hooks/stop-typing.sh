#!/bin/bash
# PostToolUse hook: stop typing indicator after reply is sent
if [ -f /tmp/typing-indicator.pid ]; then
  kill $(cat /tmp/typing-indicator.pid) 2>/dev/null
  rm -f /tmp/typing-indicator.pid
fi
exit 0
