#!/bin/bash
# Connect to Hyperliquid API
# Usage: ./connect.sh

set -e

# Load config
CONFIG_FILE="${TRADING_CONFIG:-$HOME/.config/trading/config.json}"

if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "❌ Config não encontrado em $CONFIG_FILE"
    echo ""
    echo "Crie o arquivo com:"
    echo '{'
    echo '  "api_key": "SUA_API_KEY",'
    echo '  "api_secret": "SEU_SECRET",'
    echo '  "wallet": "SEU_WALLET",'
    echo '  "mode": "human-in-loop",'
    echo '  "max_position_pct": 2'
    echo '}'
    exit 1
fi

API_KEY=$(jq -r '.api_key' "$CONFIG_FILE")
WALLET=$(jq -r '.wallet' "$CONFIG_FILE")

if [[ "$API_KEY" == "null" || -z "$API_KEY" ]]; then
    echo "❌ API key não configurada"
    exit 1
fi

# Test connection
echo "🔌 Conectando à Hyperliquid..."
echo "   Wallet: ${WALLET:0:10}...${WALLET: -6}"

# TODO: Implementar chamada real à API
# curl -s -X GET "https://api.hyperliquid.xyz/info" \
#     -H "Authorization: Bearer $API_KEY" \
#     | jq .

echo "✅ Conexão OK (simulado - implemente a chamada real)"
echo ""
echo "Próximos passos:"
echo "  1. Configure suas API keys em $CONFIG_FILE"
echo "  2. Teste com: ./trade.sh status"
echo "  3. Execute um trade: ./trade.sh long BTC 10"
