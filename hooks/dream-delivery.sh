#!/bin/bash
# dream-delivery.sh — Entrega matinal dos insights do dream cycle
# Roda às 8h (Manaus) via cron

SESSION="nanobot"

# Só entrega se o dream rodou essa noite
if [ ! -f /tmp/dream-cycle-done ]; then
  exit 0
fi

# Verificar se sessão está ativa
if ! tmux has-session -t "$SESSION" 2>/dev/null; then
  exit 0
fi

PANE=$(tmux capture-pane -t "$SESSION" -p 2>/dev/null | tail -5)
if echo "$PANE" | grep -qiE "thinking|tokens|✢|⏵|Actualizing|Razzle|Running|Shenanigating|Burrowing|Ruminating"; then
  exit 0
fi

INSIGHTS_FILE="$HOME/.claude/projects/-home-clawd/memory/dream-insights.md"

PROMPT="[DREAM DELIVERY] Durante a noite você pensou e gerou insights. Execute em ordem:

1. Ler a última entrada de hoje em ${INSIGHTS_FILE}
2. Para cada insight, classificar:
   - 💡 Ideia pequena/melhoria pontual → só reportar no Telegram
   - 🚀 Ideia grande com escopo claro → executar /gsd-new-project ou /gsd-new-milestone AGORA, sem pedir confirmação
3. Enviar mensagem pro Samyr (30289486) com o vibe de 'durante o sono pensei sobre isso...' — natural, direto, sem formalidade. Incluir o que foi só reportado E o que já foi iniciado como projeto GSD
4. Após enviar, deletar /tmp/dream-cycle-done

Critério pra 🚀 ideia grande: tem nome claro, objetivo definido, e benefício óbvio pro Samyr. Se tiver dúvida se é grande o suficiente, reportar e deixar ele decidir.

Só entregar se houver insights reais. Se o arquivo estiver vazio ou sem entrada de hoje, silêncio."

tmux send-keys -t "$SESSION" "$PROMPT" Enter
