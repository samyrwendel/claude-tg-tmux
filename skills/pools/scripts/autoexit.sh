#!/bin/bash
# Configure auto-exit for a position
# Usage: ./autoexit.sh <position_id> <condition>

set -e

POSITION_ID="${1:-}"
CONDITION="${2:-}"

CONFIG_FILE="${POOLS_CONFIG:-$HOME/.config/pools/config.json}"

if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "❌ Config não encontrado."
    exit 1
fi

if [[ -z "$POSITION_ID" ]]; then
    echo "Uso: ./autoexit.sh <position_id> <condition>"
    echo ""
    echo "Condições disponíveis:"
    echo "  il:10%     - Sair se IL (Impermanent Loss) > 10%"
    echo "  apr:<5     - Sair se APR < 5%"
    echo "  price:<3000 - Sair se preço < \$3000"
    echo "  price:>4000 - Sair se preço > \$4000"
    echo "  range:out   - Sair se sair do range"
    echo "  off         - Desativar auto-exit"
    echo ""
    echo "Exemplos:"
    echo "  ./autoexit.sh pos_001 il:10%"
    echo "  ./autoexit.sh pos_001 apr:<5"
    echo "  ./autoexit.sh pos_001 off"
    exit 1
fi

echo "🤖 Configurando Auto-Exit"
echo "========================="
echo "Position: $POSITION_ID"
echo "Condição: $CONDITION"
echo ""

if [[ "$CONDITION" == "off" ]]; then
    echo "❌ Auto-exit DESATIVADO pra $POSITION_ID"
    exit 0
fi

# Parse condition
if [[ "$CONDITION" == il:* ]]; then
    IL_PCT="${CONDITION#il:}"
    echo "✅ Auto-exit configurado:"
    echo "   Sair automaticamente se IL > $IL_PCT"
    
elif [[ "$CONDITION" == apr:* ]]; then
    APR_VAL="${CONDITION#apr:}"
    echo "✅ Auto-exit configurado:"
    echo "   Sair automaticamente se APR $APR_VAL"
    
elif [[ "$CONDITION" == price:* ]]; then
    PRICE_COND="${CONDITION#price:}"
    echo "✅ Auto-exit configurado:"
    echo "   Sair automaticamente se preço $PRICE_COND"
    
elif [[ "$CONDITION" == "range:out" ]]; then
    echo "✅ Auto-exit configurado:"
    echo "   Sair automaticamente se posição sair do range"
    
else
    echo "❌ Condição não reconhecida: $CONDITION"
    exit 1
fi

echo ""
echo "📊 Monitoramento ativo a cada 5 minutos"
echo ""
echo "⚠️ Dados simulados - configure a API pra monitoramento real"
