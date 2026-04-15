#!/bin/bash
# GoPlus Token Security Check

set -e

# Chain ID mapping
declare -A CHAINS=(
  ["eth"]="1"
  ["ethereum"]="1"
  ["bsc"]="56"
  ["polygon"]="137"
  ["arbitrum"]="42161"
  ["base"]="8453"
  ["optimism"]="10"
  ["avalanche"]="43114"
  ["avax"]="43114"
)

usage() {
  echo "Usage: $0 <chain> <token_address>"
  echo ""
  echo "Chains: eth, bsc, polygon, arbitrum, base, optimism, avalanche"
  echo ""
  echo "Example: $0 eth 0x6982508145454ce325ddbe47a25d4ec3d2311933"
  exit 1
}

[[ $# -lt 2 ]] && usage

CHAIN=$1
ADDRESS=$2

# Get chain ID
CHAIN_ID=${CHAINS[$CHAIN]}
if [[ -z "$CHAIN_ID" ]]; then
  echo "❌ Chain '$CHAIN' não suportada"
  echo "Chains válidas: ${!CHAINS[*]}"
  exit 1
fi

# Normalize address to lowercase
ADDRESS=$(echo "$ADDRESS" | tr '[:upper:]' '[:lower:]')

# Call GoPlus API
URL="https://api.gopluslabs.io/api/v1/token_security/${CHAIN_ID}?contract_addresses=${ADDRESS}"

RESPONSE=$(curl -s "$URL")

# Check if request succeeded
CODE=$(echo "$RESPONSE" | jq -r '.code // "error"')
if [[ "$CODE" != "1" ]]; then
  MSG=$(echo "$RESPONSE" | jq -r '.message // "Unknown error"')
  echo "❌ Erro na API: $MSG"
  exit 1
fi

# Extract token data
TOKEN=$(echo "$RESPONSE" | jq -r ".result[\"$ADDRESS\"] // empty")

if [[ -z "$TOKEN" || "$TOKEN" == "null" ]]; then
  echo "❌ Token não encontrado no GoPlus"
  exit 1
fi

# Parse fields
TOKEN_NAME=$(echo "$TOKEN" | jq -r '.token_name // "Unknown"')
TOKEN_SYMBOL=$(echo "$TOKEN" | jq -r '.token_symbol // "?"')
HOLDER_COUNT=$(echo "$TOKEN" | jq -r '.holder_count // "?"')

# Security flags (0 = safe, 1 = danger)
IS_HONEYPOT=$(echo "$TOKEN" | jq -r '.is_honeypot // "0"')
IS_MINTABLE=$(echo "$TOKEN" | jq -r '.is_mintable // "0"')
CAN_TAKE_OWNERSHIP=$(echo "$TOKEN" | jq -r '.can_take_back_ownership // "0"')
OWNER_CHANGE_BALANCE=$(echo "$TOKEN" | jq -r '.owner_change_balance // "0"')
HIDDEN_OWNER=$(echo "$TOKEN" | jq -r '.hidden_owner // "0"')
SELFDESTRUCT=$(echo "$TOKEN" | jq -r '.selfdestruct // "0"')
EXTERNAL_CALL=$(echo "$TOKEN" | jq -r '.external_call // "0"')
CANNOT_BUY=$(echo "$TOKEN" | jq -r '.cannot_buy // "0"')
CANNOT_SELL_ALL=$(echo "$TOKEN" | jq -r '.cannot_sell_all // "0"')
TRADING_COOLDOWN=$(echo "$TOKEN" | jq -r '.trading_cooldown // "0"')
TRANSFER_PAUSABLE=$(echo "$TOKEN" | jq -r '.transfer_pausable // "0"')
IS_BLACKLISTED=$(echo "$TOKEN" | jq -r '.is_blacklisted // "0"')
IS_WHITELISTED=$(echo "$TOKEN" | jq -r '.is_whitelisted // "0"')
IS_PROXY=$(echo "$TOKEN" | jq -r '.is_proxy // "0"')
IS_OPEN_SOURCE=$(echo "$TOKEN" | jq -r '.is_open_source // "0"')

# Taxes
BUY_TAX=$(echo "$TOKEN" | jq -r '.buy_tax // "0"')
SELL_TAX=$(echo "$TOKEN" | jq -r '.sell_tax // "0"')

# Calculate security score
SCORE=100
ISSUES=()

[[ "$IS_HONEYPOT" == "1" ]] && { SCORE=$((SCORE - 100)); ISSUES+=("🚨 HONEYPOT"); }
[[ "$IS_MINTABLE" == "1" ]] && { SCORE=$((SCORE - 20)); ISSUES+=("⚠️ Mintable"); }
[[ "$CAN_TAKE_OWNERSHIP" == "1" ]] && { SCORE=$((SCORE - 25)); ISSUES+=("⚠️ Can reclaim ownership"); }
[[ "$OWNER_CHANGE_BALANCE" == "1" ]] && { SCORE=$((SCORE - 30)); ISSUES+=("🚨 Owner can change balances"); }
[[ "$HIDDEN_OWNER" == "1" ]] && { SCORE=$((SCORE - 15)); ISSUES+=("⚠️ Hidden owner"); }
[[ "$SELFDESTRUCT" == "1" ]] && { SCORE=$((SCORE - 50)); ISSUES+=("🚨 Self-destruct function"); }
[[ "$EXTERNAL_CALL" == "1" ]] && { SCORE=$((SCORE - 10)); ISSUES+=("⚠️ External calls"); }
[[ "$CANNOT_BUY" == "1" ]] && { SCORE=$((SCORE - 50)); ISSUES+=("🚨 Cannot buy"); }
[[ "$CANNOT_SELL_ALL" == "1" ]] && { SCORE=$((SCORE - 40)); ISSUES+=("🚨 Cannot sell all"); }
[[ "$TRADING_COOLDOWN" == "1" ]] && { SCORE=$((SCORE - 10)); ISSUES+=("⚠️ Trading cooldown"); }
[[ "$TRANSFER_PAUSABLE" == "1" ]] && { SCORE=$((SCORE - 15)); ISSUES+=("⚠️ Transfer pausable"); }
[[ "$IS_BLACKLISTED" == "1" ]] && { SCORE=$((SCORE - 10)); ISSUES+=("⚠️ Has blacklist"); }
[[ "$IS_PROXY" == "1" ]] && { SCORE=$((SCORE - 5)); ISSUES+=("ℹ️ Proxy contract"); }
[[ "$IS_OPEN_SOURCE" == "0" ]] && { SCORE=$((SCORE - 15)); ISSUES+=("⚠️ Not open source"); }

# Tax penalties
BUY_TAX_NUM=$(echo "$BUY_TAX" | awk '{printf "%.0f", $1 * 100}')
SELL_TAX_NUM=$(echo "$SELL_TAX" | awk '{printf "%.0f", $1 * 100}')
[[ $BUY_TAX_NUM -gt 10 ]] && { SCORE=$((SCORE - 10)); ISSUES+=("⚠️ High buy tax: ${BUY_TAX_NUM}%"); }
[[ $SELL_TAX_NUM -gt 10 ]] && { SCORE=$((SCORE - 10)); ISSUES+=("⚠️ High sell tax: ${SELL_TAX_NUM}%"); }

# Ensure score doesn't go below 0
[[ $SCORE -lt 0 ]] && SCORE=0

# Output
echo "══════════════════════════════════════"
echo "🔍 GoPlus Security Report"
echo "══════════════════════════════════════"
echo ""
echo "Token: $TOKEN_NAME ($TOKEN_SYMBOL)"
echo "Chain: $CHAIN (ID: $CHAIN_ID)"
echo "Address: $ADDRESS"
echo "Holders: $HOLDER_COUNT"
echo ""

# Score with color indication
if [[ $SCORE -ge 80 ]]; then
  echo "Security Score: ✅ $SCORE/100 (SAFE)"
elif [[ $SCORE -ge 50 ]]; then
  echo "Security Score: ⚠️ $SCORE/100 (CAUTION)"
else
  echo "Security Score: 🚨 $SCORE/100 (DANGER)"
fi

echo ""
echo "Taxes: Buy ${BUY_TAX_NUM}% | Sell ${SELL_TAX_NUM}%"
echo ""

if [[ ${#ISSUES[@]} -eq 0 ]]; then
  echo "✅ Nenhum problema detectado"
else
  echo "Issues encontradas:"
  for issue in "${ISSUES[@]}"; do
    echo "  $issue"
  done
fi

echo ""
echo "══════════════════════════════════════"

# JSON output option
if [[ "$3" == "--json" ]]; then
  echo ""
  echo "Raw JSON:"
  echo "$TOKEN" | jq .
fi
