#!/bin/bash
# List open positions
# Usage: ./positions.sh

set -e

CONFIG_FILE="${TRADING_CONFIG:-$HOME/.config/trading/config.json}"

if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "❌ Config não encontrado. Execute ./connect.sh primeiro."
    exit 1
fi

echo "📊 Posições Abertas"
echo "==================="
echo ""

# TODO: Implementar chamada real à API Hyperliquid
# Exemplo de resposta simulada:

echo "Symbol  | Side  | Size      | Entry    | PnL"
echo "--------|-------|-----------|----------|--------"
echo "BTC     | LONG  | 0.01 BTC  | \$98,500  | +\$125"
echo "ETH     | SHORT | 0.5 ETH   | \$3,200   | -\$15"
echo ""
echo "Total PnL: +\$110"
echo ""
echo "⚠️  Dados simulados - implemente a chamada real à API"
