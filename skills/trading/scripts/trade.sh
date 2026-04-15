#!/bin/bash
# Execute trades on Hyperliquid
# Usage: ./trade.sh <long|short|status> <symbol> <amount_usdt>

set -e

ACTION="${1:-status}"
SYMBOL="${2:-BTC}"
AMOUNT="${3:-0}"

CONFIG_FILE="${TRADING_CONFIG:-$HOME/.config/trading/config.json}"

if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "❌ Config não encontrado. Execute ./connect.sh primeiro."
    exit 1
fi

API_KEY=$(jq -r '.api_key' "$CONFIG_FILE")
MODE=$(jq -r '.mode // "human-in-loop"' "$CONFIG_FILE")
MAX_PCT=$(jq -r '.max_position_pct // 2' "$CONFIG_FILE")

case "$ACTION" in
    status)
        echo "📊 Status do Trading"
        echo "===================="
        echo "Modo: $MODE"
        echo "Max posição: ${MAX_PCT}%"
        echo "Symbol: $SYMBOL"
        echo ""
        echo "TODO: Implementar chamada à API pra status real"
        ;;
    
    long)
        echo "📈 Abrindo LONG em $SYMBOL"
        echo "Amount: $AMOUNT USDT"
        echo "Mode: $MODE"
        echo ""
        
        if [[ "$MODE" == "human-in-loop" ]]; then
            echo "⚠️  HUMAN-IN-LOOP ativo"
            echo "Confirma execução? (s/n)"
            read -r confirm
            if [[ "$confirm" != "s" && "$confirm" != "S" ]]; then
                echo "❌ Cancelado"
                exit 0
            fi
        fi
        
        # TODO: Implementar execução real
        echo "🚀 Executando... (simulado)"
        echo "✅ LONG $SYMBOL @ market | Size: $AMOUNT USDT"
        ;;
    
    short)
        echo "📉 Abrindo SHORT em $SYMBOL"
        echo "Amount: $AMOUNT USDT"
        echo "Mode: $MODE"
        echo ""
        
        if [[ "$MODE" == "human-in-loop" ]]; then
            echo "⚠️  HUMAN-IN-LOOP ativo"
            echo "Confirma execução? (s/n)"
            read -r confirm
            if [[ "$confirm" != "s" && "$confirm" != "S" ]]; then
                echo "❌ Cancelado"
                exit 0
            fi
        fi
        
        # TODO: Implementar execução real
        echo "🚀 Executando... (simulado)"
        echo "✅ SHORT $SYMBOL @ market | Size: $AMOUNT USDT"
        ;;
    
    *)
        echo "Uso: ./trade.sh <long|short|status> <symbol> <amount_usdt>"
        echo ""
        echo "Exemplos:"
        echo "  ./trade.sh status"
        echo "  ./trade.sh long BTC 100"
        echo "  ./trade.sh short ETH 50"
        exit 1
        ;;
esac
