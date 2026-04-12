#!/bin/bash
# Hook: PostToolUse — controla spinner animado no Telegram
# Inicia spinner na primeira tool call, atualiza texto nas seguintes, para no reply

SPINNER="/home/clawd/.claude/hooks/telegram-spinner.sh"

# Ler input do hook
INPUT=$(cat)

# Extrair nome da tool
TOOL_NAME=$(echo "$INPUT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tool_name','unknown'))" 2>/dev/null || echo "unknown")

# Se é reply/react do Telegram, parar spinner e sair
case "$TOOL_NAME" in
  mcp__plugin_telegram_telegram__reply|mcp__plugin_telegram_telegram__react|mcp__plugin_telegram_telegram__edit_message)
    "$SPINNER" stop &
    exit 0
    ;;
esac

# Ignorar tools leves
case "$TOOL_NAME" in
  Read|Glob|Grep|ToolSearch|TaskOutput|Skill)
    exit 0
    ;;
esac

# Só disparar spinner se houver uma mensagem Telegram em processamento
if [ ! -f /tmp/claude-processing ]; then
  exit 0
fi

# Extrair descrição
DESCRIPTION=$(echo "$INPUT" | python3 -c "
import sys,json
d=json.load(sys.stdin)
tool = d.get('tool_name','?')
inp = d.get('tool_input',{})
if tool == 'Bash':
    desc = inp.get('description', inp.get('command','')[:60])
elif tool == 'Edit':
    desc = 'editando ' + inp.get('file_path','?').split('/')[-1]
elif tool == 'Write':
    desc = 'escrevendo ' + inp.get('file_path','?').split('/')[-1]
elif tool == 'Agent':
    desc = 'subagente: ' + inp.get('description','trabalhando')
else:
    desc = tool
print(desc[:100])
" 2>/dev/null || echo "trabalhando...")

# Se spinner já tá rodando, só atualizar texto. Senão, iniciar.
if [ -f /tmp/telegram-spinner.pid ] && kill -0 $(cat /tmp/telegram-spinner.pid) 2>/dev/null; then
  "$SPINNER" update "$DESCRIPTION" &
else
  "$SPINNER" start "$DESCRIPTION" &
fi

exit 0
