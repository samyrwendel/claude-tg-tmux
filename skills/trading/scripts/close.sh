#!/bin/bash
# Close position
# Usage: ./close.sh <symbol> [all]

set -e

SYMBOL="${1:-}"
CLOSE_ALL="${2:-}"

CONFIG_FILE="${TRADING_CONFIG:-$HOME/.config/trading/config.json}"

if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "❌ Config não encontrado. Execute ./connect.sh primeiro."
    exit 1
fi

MODE=$(jq -r '.mode // "human-in-loop"' "$CONFIG_FILE")

if [[ -z "$SYMBOL" ]]; then
    echo "Uso: ./close.sh <symbol> [all]"
    echo ""
    echo "Exemplos:"
    echo "  ./close.sh BTC      # fecha posição em BTC"
    echo "  ./close.sh ETH      # fecha posição em ETH"
    echo "  ./close.sh all      # fecha todas as posições"
    exit 1
fi

if [[ "$SYMBOL" == "all" ]]; then
    echo "⚠️  Fechando TODAS as posições"
else
    echo "📤 Fechando posição em $SYMBOL"
fi

if [[ "$MODE" == "human-in-loop" ]]; then
    echo ""
    echo "⚠️  HUMAN-IN-LOOP ativo"
    echo "Confirma fechamento? (s/n)"
    read -r confirm
    if [[ "$confirm" != "s" && "$confirm" != "S" ]]; then
        echo "❌ Cancelado"
        exit 0
    fi
fi

# TODO: Implementar fechamento real via API
echo ""
echo "🚀 Executando... (simulado)"
if [[ "$SYMBOL" == "all" ]]; then
    echo "✅ Todas as posições fechadas"
else
    echo "✅ Posição $SYMBOL fechada @ market"
fi
