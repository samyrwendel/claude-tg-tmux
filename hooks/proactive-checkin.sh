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

PROMPT="[CHECKIN PROATIVO] Exame de consciência silencioso. Execute em ordem:

**1. PROMESSAS E PENDÊNCIAS**
- Ler ~/.claude/projects/-home-clawd/memory/promises.md
- Há promessas abertas vencidas ou próximas de vencer? → Alertar Samyr
- Ler project_payments_pending.md — contas próximas? → Alertar Samyr

**2. PESQUISA PROATIVA (obrigatória — pelo menos 1 insight de valor)**
Escolher pelo menos 1 tema relevante e pesquisar:
- Polymarket: posições abertas mudaram? Algo expirando em breve?
- Crypto/DeFi: notícia relevante pro portfólio?
- Milhas: promoção Smiles/TudoAzul/LATAM Pass ativa?
- Geopolítica: evento que afeta apostas abertas?
- IA/Tech: novidade relevante?

**3. ATUALIZAR ESTADO (OBRIGATÓRIO após cada checkin)**
Ao terminar as pesquisas, atualizar ${STATE_FILE} com:
\`\`\`bash
python3 -c \"
import json, time
path = '${STATE_FILE}'
d = json.load(open(path))
d['lastChecks']['promises'] = int(time.time())
d['lastChecks']['polymarket'] = int(time.time())  # se verificou
d['notes'] = 'Heartbeat $(date +%d/%m/%Y\ %H:%M). [RESULTADO_RESUMIDO_EM_1_LINHA]'
json.dump(d, open(path, 'w'), indent=2, ensure_ascii=False)
\"
\`\`\`
Substituir [RESULTADO_RESUMIDO_EM_1_LINHA] com o que encontrou (ex: 'Sem pendências urgentes' ou 'Alertado sobre X').

**4. ENTREGA**
- SE encontrou algo relevante: enviar ao Samyr via Telegram
- SE não há nada urgente: não fazer nada, não responder nada

**Regra:** Só enviar mensagem se há valor real. Silêncio > mensagem genérica."

tmux send-keys -t "$SESSION" "$PROMPT" Enter
