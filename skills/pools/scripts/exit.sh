#!/bin/bash
# Exit a liquidity pool (Zap-Out)
# Usage: ./exit.sh <position_id> [percentage]

set -e

POSITION_ID="${1:-}"
PERCENTAGE="${2:-100}"

CONFIG_FILE="${POOLS_CONFIG:-$HOME/.config/pools/config.json}"

if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "❌ Config não encontrado."
    exit 1
fi

if [[ -z "$POSITION_ID" ]]; then
    echo "Uso: ./exit.sh <position_id> [percentage]"
    echo ""
    echo "Exemplos:"
    echo "  ./exit.sh pos_001        # Sai 100%"
    echo "  ./exit.sh pos_001 50     # Sai 50%"
    exit 1
fi

echo "📤 Saindo da Pool"
echo "================="
echo "Position: $POSITION_ID"
echo "Percentage: ${PERCENTAGE}%"
echo ""

# TODO: Buscar dados da posição via API
echo "📊 Dados da posição:"
echo "   Pool: ETH/USDC"
echo "   TVL atual: \$5,230"
echo "   PnL: +\$320 (+6.5%)"
echo "   Fees não coletados: \$45"
echo ""

if [[ "$PERCENTAGE" == "100" ]]; then
    echo "⚠️  Fechando posição COMPLETAMENTE"
else
    echo "⚠️  Saindo ${PERCENTAGE}% da posição"
fi

echo ""
echo "Confirma? (s/n)"
read -r confirm

if [[ "$confirm" != "s" && "$confirm" != "S" ]]; then
    echo "❌ Cancelado"
    exit 0
fi

echo ""
echo "🚀 Executando Zap-Out... (simulado)"
echo ""

if [[ "$PERCENTAGE" == "100" ]]; then
    echo "✅ Posição fechada!"
    echo "   Recebido: \$5,595 (principal + fees + PnL)"
else
    VALUE_OUT=$((5230 * PERCENTAGE / 100))
    echo "✅ Saída parcial executada!"
    echo "   Recebido: \$$VALUE_OUT"
    echo "   Restante na pool: \$$(( 5230 - VALUE_OUT ))"
fi
echo ""
echo "⚠️ Dados simulados"
