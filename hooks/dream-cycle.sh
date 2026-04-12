#!/bin/bash
# dream-cycle.sh — DIY AutoDream (v2: processo independente, sem tmux)
# Roda como processo claude -p isolado, sobrevive a reinicializações de sessão
#
# COMO DESATIVAR:
#   Opção A — Remover do cron:
#     crontab -e  →  apagar a linha com dream-cycle.sh
#   Opção B — Desabilitar temporariamente:
#     touch /tmp/dream-cycle-disabled   (reativa sozinho no próximo boot)
#
# COMO REATIVAR:
#   rm /tmp/dream-cycle-disabled
#
# LOG: /tmp/dream-cycle.log

LOG="/tmp/dream-cycle.log"
PID_FILE="/tmp/dream-cycle-pid"
DONE_FLAG="/tmp/dream-cycle-done"
INSIGHTS_FILE="$HOME/.claude/projects/-home-clawd/memory/dream-insights.md"

# Verificar flag de desativação manual
if [ -f /tmp/dream-cycle-disabled ]; then
  echo "$(date): dream-cycle desabilitado (flag existe)" >> "$LOG"
  exit 0
fi

# Evitar múltiplos dreams simultâneos
if [ -f "$PID_FILE" ]; then
  OLD_PID=$(cat "$PID_FILE")
  if kill -0 "$OLD_PID" 2>/dev/null; then
    echo "$(date): dream já rodando (PID $OLD_PID), abortando" >> "$LOG"
    exit 0
  else
    rm -f "$PID_FILE"
  fi
fi

# Já tem dream pendente não entregue?
if [ -f "$DONE_FLAG" ]; then
  echo "$(date): done flag existe, dream anterior não entregue ainda" >> "$LOG"
  exit 0
fi

TODAY=$(TZ=America/Manaus date '+%Y-%m-%d')
NOW_TS=$(TZ=America/Manaus date '+%Y-%m-%d %H:%M')

echo "$(date): disparando dream cycle (processo independente)" >> "$LOG"

PROMPT="[DREAM CYCLE] Reflexão profunda noturna. Execute em silêncio, sem narrar:

**1. CONSOLIDAÇÃO DE MEMORY**
- Ler todos os arquivos em ~/.claude/projects/-home-clawd/memory/*.md
- Remover info obsoleta, resolver contradições, atualizar MEMORY.md
- Adicionar lições novas ao lessons_learned.md

**2. TAREFAS PENDENTES**
- Ler promises.md e session_snapshot_latest.md
- Identificar o que ficou inacabado ou foi prometido e não entregue
- Registrar num bloco 'pendências' no session_snapshot_latest.md

**3. REFLEXÃO E INSIGHTS**
Com base em tudo que foi feito recentemente (memory, snapshots, lições):
- Há padrões de problema recorrente que têm solução melhor?
- Alguma automação que poderia eliminar trabalho manual repetido?
- Alguma melhoria de infraestrutura, hook, skill ou fluxo?
- Alguma ideia nova relevante pro portfólio/DeFi/negócios do Samyr?

**4. SALVAR INSIGHTS**
Salvar os insights em ${INSIGHTS_FILE} (append), com este formato exato:

## ${TODAY}
[bullet points dos insights encontrados, um por linha com - ]
---

Se o arquivo não existir, criar.

**5. SINALIZAR CONCLUSÃO**
Após salvar os insights, executar exatamente:
bash -c 'echo dream-done > /tmp/dream-cycle-done'

Silêncio total. Nada de Telegram, nada de output. Só salvar e sinalizar."

# Salvar prompt em arquivo temporário
PROMPT_FILE=$(mktemp /tmp/dream-prompt-XXXXXX.txt)
printf '%s' "$PROMPT" > "$PROMPT_FILE"

# Criar wrapper script para evitar problemas de quoting
RUNNER=$(mktemp /tmp/dream-runner-XXXXXX.sh)
cat > "$RUNNER" << RUNEOF
#!/bin/bash
CLAUDE_BIN="/home/clawd/.npm-global/bin/claude"
PROMPT_FILE="$PROMPT_FILE"
PID_FILE="$PID_FILE"
DONE_FLAG="$DONE_FLAG"
LOG="$LOG"
PROMPT=\$(cat "\$PROMPT_FILE")
\$CLAUDE_BIN -p "\$PROMPT" --dangerously-skip-permissions >> /tmp/dream-output.log 2>&1
EXIT_CODE=\$?
echo "\$(date): processo concluído (exit \$EXIT_CODE)" >> "\$LOG"
if [ "\$EXIT_CODE" -eq 0 ]; then
  echo dream-done > "\$DONE_FLAG"
fi
rm -f "\$PROMPT_FILE" "\$0" "\$PID_FILE"
RUNEOF
chmod +x "$RUNNER"

# Rodar como processo completamente independente
nohup "$RUNNER" &
DREAM_PID=$!
echo "$DREAM_PID" > "$PID_FILE"
disown "$DREAM_PID"

echo "$(date): processo iniciado PID $DREAM_PID" >> "$LOG"
