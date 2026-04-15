#!/bin/bash
# Enter a liquidity pool (Zap-In)
# Usage: ./enter.sh <pair> <amount_usd> [chain] [dex]

set -e

PAIR="${1:-}"
AMOUNT="${2:-0}"
CHAIN="${3:-}"
DEX="${4:-}"

CONFIG_FILE="${POOLS_CONFIG:-$HOME/.config/pools/config.json}"

if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "❌ Config não encontrado. Veja SKILL.md"
    exit 1
fi

if [[ -z "$PAIR" || "$AMOUNT" == "0" ]]; then
    echo "Uso: ./enter.sh <pair> <amount_usd> [chain] [dex]"
    echo ""
    echo "Exemplos:"
    echo "  ./enter.sh ETH/USDC 1000"
    echo "  ./enter.sh ARB/ETH 500 arbitrum uniswapv3"
    echo "  ./enter.sh WBTC/ETH 2000 ethereum pancakeswapv3"
    exit 1
fi

API_KEY=$(jq -r '.krystal_api_key' "$CONFIG_FILE")
WALLET=$(jq -r '.wallet_address' "$CONFIG_FILE")
DEFAULT_CHAIN=$(jq -r '.default_chain // "arbitrum"' "$CONFIG_FILE")
DEFAULT_DEX=$(jq -r '.default_dex // "uniswapv3"' "$CONFIG_FILE")
SLIPPAGE=$(jq -r '.settings.slippage_pct // 0.5' "$CONFIG_FILE")

CHAIN="${CHAIN:-$DEFAULT_CHAIN}"
DEX="${DEX:-$DEFAULT_DEX}"

echo "📥 Entrando na Pool"
echo "==================="
echo "Par: $PAIR"
echo "Amount: \$$AMOUNT"
echo "Chain: $CHAIN"
echo "DEX: $DEX"
echo "Slippage: ${SLIPPAGE}%"
echo ""

# Buscar melhores pools pra esse par
echo "🔍 Buscando melhores pools pra $PAIR..."
echo ""

# TODO: Implementar chamada real à API
echo "Pools encontradas:"
echo ""
echo "  1. Uniswap V3 (0.3% fee) - APR: 45.2% - TVL: \$12.5M"
echo "  2. Uniswap V3 (0.05% fee) - APR: 32.1% - TVL: \$8.2M"
echo "  3. PancakeSwap V3 - APR: 38.5% - TVL: \$5.1M"
echo ""

echo "⚠️  HUMAN-IN-LOOP ativo"
echo "Selecione a pool (1-3) ou 'c' pra cancelar:"
read -r selection

if [[ "$selection" == "c" || "$selection" == "C" ]]; then
    echo "❌ Cancelado"
    exit 0
fi

echo ""
echo "🚀 Executando Zap-In... (simulado)"
echo ""
echo "✅ Posição criada!"
echo "   ID: pos_new_001"
echo "   Pool: $PAIR ($DEX)"
echo "   Valor: \$$AMOUNT"
echo "   Range: \$3,100 - \$3,500"
echo ""
echo "⚠️ Dados simulados - configure a API key pra execução real"
