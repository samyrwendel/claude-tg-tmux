#!/bin/bash
# proactive-checkin.sh
# Injeta prompt de exame de consciência na sessão nanobot
# Rodado via cron a cada 4h

SESSION="nanobot"
STATE_FILE="$HOME/.claude/projects/-home-clawd/memory/heartbeat-state.json"

# Verificar se sessão está ativa
if ! tmux has-session -t "$SESSION" 2>/dev/null; then
  exit 0
fi

# Verificar se Claude está idle (não processando)
PANE=$(tmux capture-pane -t "$SESSION" -p 2>/dev/null | tail -5)
if echo "$PANE" | grep -qiE "thinking|tokens|✢|⏵|Actualizing|Razzle|Running|Shenanigating|Burrowing|Ruminating"; then
  exit 0  # Ocupado — tentar na próxima rodada
fi

ACTIONS_FILE="$HOME/.claude/projects/-home-clawd/memory/dream-actions.md"
TODAY=$(TZ=America/Manaus date '+%Y-%m-%d')

# Verificar se há ações do sonho de hoje
HAS_ACTIONS=0
if [ -f "$ACTIONS_FILE" ]; then
  ACTIONS=$(awk "/^## ${TODAY}/{found=1; next} found && /^## /{exit} found{print}" "$ACTIONS_FILE" | grep -v "^NENHUMA" | grep "^-" | head -5)
  [ -n "$ACTIONS" ] && HAS_ACTIONS=1
fi

DREAM_SECTION=""
if [ "$HAS_ACTIONS" -eq 1 ]; then
  DREAM_SECTION="**0. AÇÕES DO SONHO (prioridade)**
Durante o sonho de hoje foram identificadas ações pendentes. Se houver tempo ocioso agora, executar:
${ACTIONS}

Só executar se fizer sentido no contexto atual. Se já foram feitas ou não forem mais relevantes, ignorar.

"
fi

PROMPT="[CHECKIN PROATIVO] Exame de consciência silencioso. Execute em ordem:

${DREAM_SECTION}**1. PROMESSAS E PENDÊNCIAS**
- Ler ~/.claude/projects/-home-clawd/memory/promises.md
- Há promessas abertas vencidas ou próximas de vencer? → Alertar Samyr
- Ler project_payments_pending.md — contas próximas? → Alertar Samyr

**2. PESQUISA PROATIVA (só se houver algo relevante)**
Se houver tempo e não houver ações urgentes, pesquisar 1 tema:
- Polymarket: posições abertas mudaram? Algo expirando em breve?
- Crypto/DeFi: notícia relevante pro portfólio?
- Milhas: promoção Smiles/TudoAzul/LATAM Pass ativa?
- IA/Tech: novidade relevante?

**3. ATUALIZAR ESTADO (OBRIGATÓRIO após cada checkin)**
Ao terminar, atualizar ${STATE_FILE} com:
\`\`\`bash
python3 -c \"
import json, time
path = '${STATE_FILE}'
d = json.load(open(path))
d['lastChecks']['promises'] = int(time.time())
d['lastChecks']['polymarket'] = int(time.time())
d['notes'] = 'Heartbeat $(date +%d/%m/%Y\ %H:%M). [RESULTADO_RESUMIDO_EM_1_LINHA]'
json.dump(d, open(path, 'w'), indent=2, ensure_ascii=False)
\"
\`\`\`

**4. ENTREGA**
- SE encontrou algo relevante ou executou ação: enviar ao Samyr via Telegram
- SE tudo bem e nada pra fazer: silêncio total

**Regra:** Silêncio > mensagem genérica. Só falar se há valor real."

tmux send-keys -t "$SESSION" "$PROMPT" Enter
