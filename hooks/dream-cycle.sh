#!/bin/bash
# dream-cycle.sh — DIY AutoDream
# Consolidação de memory quando sessão está idle
#
# COMO DESATIVAR:
#   Opção A — Remover do cron:
#     crontab -e  →  apagar a linha com dream-cycle.sh
#   Opção B — Desabilitar temporariamente:
#     touch /tmp/dream-cycle-disabled   (reativa sozinho no próximo boot)
#   Opção C — Desabilitar o nativo (settings.json):
#     python3 -c "import json; d=json.load(open('/home/clawd/.claude/settings.json')); d['autoDream']['enabled']=False; json.dump(d,open('/home/clawd/.claude/settings.json','w'),indent=2)"
#
# COMO REATIVAR:
#   rm /tmp/dream-cycle-disabled
#   ou adicionar de volta no crontab: 0 4 * * * /home/clawd/.claude/hooks/dream-cycle.sh
#
# LOG: /tmp/dream-cycle.log

SESSION="nanobot"
IDLE_REQUIRED=1800   # 30 minutos mínimo de inatividade
RETRY_WAIT=900       # Retry em 15min se ainda ativo
LAST_ACTIVITY_FILE="/tmp/claude-last-activity"
LOG="/tmp/dream-cycle.log"
TOKEN=$(grep TELEGRAM_BOT_TOKEN ~/.claude/channels/telegram/.env 2>/dev/null | cut -d= -f2)
CHAT_ID="30289486"

# Verificar flag de desativação manual
if [ -f /tmp/dream-cycle-disabled ]; then
  echo "$(date): dream-cycle desabilitado (flag existe)" >> "$LOG"
  exit 0
fi

if ! tmux has-session -t "$SESSION" 2>/dev/null; then exit 0; fi

# Verificar se sessão está ativa
PANE=$(tmux capture-pane -t "$SESSION" -p 2>/dev/null | tail -5)
if echo "$PANE" | grep -qiE "thinking|tokens|✢|⏵|Actualizing|Razzle|Running|Shenanigating|Burrowing|Ruminating"; then
  echo "$(date): sessão ativa, reagendando em ${RETRY_WAIT}s" >> "$LOG"
  (sleep $RETRY_WAIT && /home/clawd/.claude/hooks/dream-cycle.sh) &
  exit 0
fi

# Verificar inatividade mínima
if [ -f "$LAST_ACTIVITY_FILE" ]; then
  LAST=$(stat -c %Y "$LAST_ACTIVITY_FILE" 2>/dev/null || echo 0)
  NOW=$(date +%s)
  IDLE=$((NOW - LAST))
  if [ "$IDLE" -lt "$IDLE_REQUIRED" ]; then
    WAIT=$((IDLE_REQUIRED - IDLE + 60))
    echo "$(date): idle ${IDLE}s (precisa ${IDLE_REQUIRED}s), aguardando ${WAIT}s" >> "$LOG"
    (sleep $WAIT && /home/clawd/.claude/hooks/dream-cycle.sh) &
    exit 0
  fi
fi

echo "$(date): disparando dream cycle" >> "$LOG"

PROMPT="[DREAM CYCLE] Reflexão profunda. Execute em silêncio:

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

Registrar os insights num arquivo ~/.claude/projects/-home-clawd/memory/dream-insights.md (criar se não existir, appending com data).

**4. ENTREGA**
AO TERMINAR: salvar um resumo compacto dos insights em ~/.claude/projects/-home-clawd/memory/dream-insights.md (append com data/hora). Formato:

## $(TZ=America/Manaus date '+%Y-%m-%d')
[bullet points dos insights encontrados]
---

NÃO enviar Telegram agora. O relatório será entregue de manhã quando o Samyr estiver online.
Só registrar: echo 'dream-done' > /tmp/dream-cycle-done

Silêncio total durante o processo."

tmux send-keys -t "$SESSION" "$PROMPT" Enter
echo "$(date): prompt injetado" >> "$LOG"
