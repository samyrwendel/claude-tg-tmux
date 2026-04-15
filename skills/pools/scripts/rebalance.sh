#!/bin/bash
# Rebalance position to new range
# Usage: ./rebalance.sh <position_id> [lower_price] [upper_price]

set -e

POSITION_ID="${1:-}"
LOWER="${2:-}"
UPPER="${3:-}"

CONFIG_FILE="${POOLS_CONFIG:-$HOME/.config/pools/config.json}"

if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "❌ Config não encontrado."
    exit 1
fi

if [[ -z "$POSITION_ID" ]]; then
    echo "Uso: ./rebalance.sh <position_id> [lower_price] [upper_price]"
    echo ""
    echo "Exemplos:"
    echo "  ./rebalance.sh pos_001              # Rebalance automático"
    echo "  ./rebalance.sh pos_001 3000 3500    # Range manual"
    exit 1
fi

echo "🤹 Rebalance de Posição"
echo "======================="
echo "Position: $POSITION_ID"
echo ""

# TODO: Buscar dados da posição via API
echo "📊 Posição atual:"
echo "   Pool: ETH/USDC"
echo "   Range atual: \$3,100 - \$3,500"
echo "   Preço atual: \$3,450"
echo "   Status: ✅ In Range (mas próximo do limite)"
echo ""

if [[ -z "$LOWER" || -z "$UPPER" ]]; then
    echo "🤖 Calculando range otimizado..."
    echo ""
    echo "Range sugerido: \$3,200 - \$3,700"
    echo "   - Baseado em volatilidade 7d"
    echo "   - APR estimado: 42.5%"
    echo ""
    LOWER="3200"
    UPPER="3700"
fi

echo "Novo range: \$$LOWER - \$$UPPER"
echo ""
echo "⚠️  Isso vai:"
echo "   1. Fechar a posição atual"
echo "   2. Reabrir no novo range"
echo "   3. Custar ~\$2-5 em gas"
echo ""

echo "Confirma rebalance? (s/n)"
read -r confirm

if [[ "$confirm" != "s" && "$confirm" != "S" ]]; then
    echo "❌ Cancelado"
    exit 0
fi

echo ""
echo "🚀 Executando rebalance... (simulado)"
echo ""
echo "✅ Rebalance executado!"
echo "   Novo range: \$$LOWER - \$$UPPER"
echo "   Gas usado: \$3.20"
echo ""
echo "⚠️ Dados simulados"
