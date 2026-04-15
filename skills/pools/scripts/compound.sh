#!/bin/bash
# Compound fees back into position
# Usage: ./compound.sh <position_id>

set -e

POSITION_ID="${1:-}"

CONFIG_FILE="${POOLS_CONFIG:-$HOME/.config/pools/config.json}"

if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "❌ Config não encontrado."
    exit 1
fi

if [[ -z "$POSITION_ID" ]]; then
    echo "Uso: ./compound.sh <position_id>"
    exit 1
fi

echo "♻️ Compound de Fees"
echo "==================="
echo "Position: $POSITION_ID"
echo ""

# TODO: Buscar fees pendentes via API
echo "📊 Fees disponíveis pra compound:"
echo "   Token0 (ETH): 0.015 ETH (~\$48)"
echo "   Token1 (USDC): 32.50 USDC"
echo "   Total: ~\$80.50"
echo ""
echo "Após compound:"
echo "   TVL atual: \$5,230 → \$5,310.50 (+1.5%)"
echo ""

echo "Confirma compound? (s/n)"
read -r confirm

if [[ "$confirm" != "s" && "$confirm" != "S" ]]; then
    echo "❌ Cancelado"
    exit 0
fi

echo ""
echo "🚀 Executando compound... (simulado)"
echo ""
echo "✅ Compound executado!"
echo "   Fees reinvestidos na posição"
echo "   Novo TVL: \$5,310.50"
echo ""
echo "⚠️ Dados simulados"
