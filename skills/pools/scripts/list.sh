#!/bin/bash
# List open liquidity positions
# Usage: ./list.sh [chain]

set -e

CHAIN="${1:-}"
CONFIG_FILE="${POOLS_CONFIG:-$HOME/.config/pools/config.json}"

if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "❌ Config não encontrado em $CONFIG_FILE"
    echo ""
    echo "Crie o arquivo com a estrutura do SKILL.md"
    exit 1
fi

API_KEY=$(jq -r '.krystal_api_key' "$CONFIG_FILE")
WALLET=$(jq -r '.wallet_address' "$CONFIG_FILE")
DEFAULT_CHAIN=$(jq -r '.default_chain // "arbitrum"' "$CONFIG_FILE")

CHAIN="${CHAIN:-$DEFAULT_CHAIN}"

if [[ "$API_KEY" == "null" || -z "$API_KEY" ]]; then
    echo "❌ Krystal API key não configurada"
    exit 1
fi

echo "📊 Posições de Liquidez"
echo "========================"
echo "Wallet: ${WALLET:0:10}...${WALLET: -6}"
echo "Chain: $CHAIN"
echo ""

# TODO: Implementar chamada real à Krystal API
# curl -s -X GET "https://cloud-api.krystal.app/v1/positions?wallet=$WALLET&chainId=$CHAIN" \
#     -H "KC-APIKey: $API_KEY" \
#     -H "Content-Type: application/json"

echo "ID         | Pool       | TVL       | APR    | PnL     | Status"
echo "-----------|------------|-----------|--------|---------|--------"
echo "pos_001    | ETH/USDC   | \$5,230   | 45.2%  | +\$320  | ✅ In Range"
echo "pos_002    | ARB/ETH    | \$2,100   | 32.1%  | +\$85   | ✅ In Range"
echo "pos_003    | WBTC/ETH   | \$8,500   | 18.5%  | -\$120  | ⚠️ Out of Range"
echo ""
echo "Total TVL: \$15,830"
echo "Total PnL: +\$285"
echo ""
echo "⚠️ Dados simulados - configure a API key pra dados reais"
