#!/bin/bash
# Claim fees from a position
# Usage: ./claim.sh <position_id>

set -e

POSITION_ID="${1:-}"

CONFIG_FILE="${POOLS_CONFIG:-$HOME/.config/pools/config.json}"

if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "❌ Config não encontrado."
    exit 1
fi

if [[ -z "$POSITION_ID" ]]; then
    echo "Uso: ./claim.sh <position_id>"
    exit 1
fi

echo "🫴 Coletando Fees"
echo "================="
echo "Position: $POSITION_ID"
echo ""

# TODO: Buscar fees pendentes via API
echo "📊 Fees pendentes:"
echo "   Token0 (ETH): 0.015 ETH (~\$48)"
echo "   Token1 (USDC): 32.50 USDC"
echo "   Total: ~\$80.50"
echo ""

echo "Confirma coleta? (s/n)"
read -r confirm

if [[ "$confirm" != "s" && "$confirm" != "S" ]]; then
    echo "❌ Cancelado"
    exit 0
fi

echo ""
echo "🚀 Coletando... (simulado)"
echo ""
echo "✅ Fees coletados!"
echo "   0.015 ETH + 32.50 USDC enviados pra sua wallet"
echo ""
echo "⚠️ Dados simulados"
