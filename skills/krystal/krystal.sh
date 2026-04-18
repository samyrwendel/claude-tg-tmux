#!/bin/bash
# Krystal Cloud API - Pool Consultation Tool

set -e

# Config
API_BASE="https://cloud-api.krystal.app"
MIN_VALUE_USD=1  # Valor mínimo pra não ser dust

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Carrega config local (aliases de wallet) — gitignored
# ~/.config/krystal/wallets.conf formato: alias=0xABC...
WALLETS_CONF="${KRYSTAL_WALLETS_CONF:-$HOME/.config/krystal/wallets.conf}"

# Buscar API Key:
#   1. KRYSTAL_API_KEY env var (direto)
#   2. Bitwarden (se KRYSTAL_BW_ID definido)
get_api_key() {
  if [[ -n "$KRYSTAL_API_KEY" ]]; then
    echo "$KRYSTAL_API_KEY"
    return
  fi
  if [[ -n "$KRYSTAL_BW_ID" ]]; then
    export BW_SESSION="$(grep BW_SESSION ~/.bashrc | cut -d'"' -f2 2>/dev/null)"
    bw get password "$KRYSTAL_BW_ID" 2>/dev/null
  fi
}

usage() {
  echo "Krystal Pool Consultation Tool"
  echo ""
  echo "Usage:"
  echo "  $0 positions <wallet|alias> [--no-dust]  - Ver posições abertas"
  echo "  $0 summary <wallet|alias>                - Resumo rápido"
  echo "  $0 search <token> [chain]                - Buscar pools"
  echo ""
  echo "Config:"
  echo "  KRYSTAL_API_KEY  ou KRYSTAL_BW_ID (Bitwarden item ID)"
  echo "  Aliases em: $WALLETS_CONF (formato: alias=0x...)"
  echo ""
  exit 1
}

# Resolver wallet alias via arquivo de config
resolve_wallet() {
  local wallet="$1"
  # Se já é endereço 0x completo, retorna
  [[ "$wallet" =~ ^0x[a-fA-F0-9]{40}$ ]] && { echo "$wallet"; return; }
  # Busca alias no arquivo de config
  if [[ -f "$WALLETS_CONF" ]]; then
    local addr=$(grep -E "^${wallet}=" "$WALLETS_CONF" 2>/dev/null | cut -d= -f2 | head -1)
    [[ -n "$addr" ]] && { echo "$addr"; return; }
  fi
  # Fallback: retorna input (pode ser endereço válido não-0x, usuário decide)
  echo "$wallet"
}

# Formatar número grande
fmt_num() {
  local n=$1
  if (( $(echo "$n >= 1000000" | bc -l) )); then
    printf "%.2fM" $(echo "$n / 1000000" | bc -l)
  elif (( $(echo "$n >= 1000" | bc -l) )); then
    printf "%.2fK" $(echo "$n / 1000" | bc -l)
  else
    printf "%.2f" $n
  fi
}

# Comando: positions
cmd_positions() {
  local wallet=$(resolve_wallet "$1")
  local no_dust=false
  [[ "$2" == "--no-dust" ]] && no_dust=true
  
  local api_key=$(get_api_key)
  if [[ -z "$api_key" ]]; then
    echo "❌ Erro: Não consegui obter API key do Bitwarden"
    exit 1
  fi
  
  echo "🔍 Buscando posições para ${wallet:0:6}...${wallet: -4}"
  echo ""
  
  local response=$(curl -s "${API_BASE}/v1/positions?wallet=${wallet}" \
    -H "KC-APIKey: ${api_key}" \
    -H "Content-Type: application/json")
  
  # Verificar erro
  if echo "$response" | jq -e '.error' >/dev/null 2>&1; then
    echo "❌ Erro na API: $(echo "$response" | jq -r '.error')"
    exit 1
  fi
  
  # Contar posições
  local total=$(echo "$response" | jq 'length')
  local open_count=0
  local total_value=0
  
  echo "═══════════════════════════════════════════════════════"
  
  # Iterar posições
  echo "$response" | jq -c '.[]' | while read -r pos; do
    local liquidity=$(echo "$pos" | jq -r '.liquidity')
    local value=$(echo "$pos" | jq -r '.currentPositionValue')
    local status=$(echo "$pos" | jq -r '.status')
    
    # Pular posições fechadas
    [[ "$liquidity" == "0" ]] && continue
    
    # Pular dust se --no-dust
    if $no_dust && (( $(echo "$value < $MIN_VALUE_USD" | bc -l) )); then
      continue
    fi
    
    # Extrair dados
    local token0=$(echo "$pos" | jq -r '.currentAmounts[0].token.symbol')
    local token1=$(echo "$pos" | jq -r '.currentAmounts[1].token.symbol')
    local chain=$(echo "$pos" | jq -r '.chain.name')
    local protocol=$(echo "$pos" | jq -r '.pool.protocol.name')
    local pnl=$(echo "$pos" | jq -r '.performance.pnl')
    local roi=$(echo "$pos" | jq -r '.performance.returnOnInvestment')
    local apr=$(echo "$pos" | jq -r '.performance.apr.totalApr // .apr.totalApr // 0')
    local pool_price=$(echo "$pos" | jq -r '.pool.poolPrice')
    local min_price=$(echo "$pos" | jq -r '.minPrice')
    local max_price=$(echo "$pos" | jq -r '.maxPrice')
    local fee_pending=$(echo "$pos" | jq -r '[.tradingFee.pending[].value // 0] | add')
    
    # Status emoji
    local status_emoji="🟢"
    [[ "$status" == "OUT_RANGE" ]] && status_emoji="🔴"
    
    # PnL color
    local pnl_display=$(printf "%.2f" $pnl)
    local roi_display=$(printf "%.1f" $roi)
    
    echo -e "${BLUE}${token0}/${token1}${NC} | ${chain} | ${protocol}"
    echo -e "  Status: ${status_emoji} ${status}"
    echo -e "  Valor: \$$(fmt_num $value)"
    
    if (( $(echo "$pnl >= 0" | bc -l) )); then
      echo -e "  PnL: ${GREEN}+\$${pnl_display}${NC} (${GREEN}+${roi_display}%${NC})"
    else
      echo -e "  PnL: ${RED}\$${pnl_display}${NC} (${RED}${roi_display}%${NC})"
    fi
    
    echo -e "  APR: ${YELLOW}$(printf "%.0f" $apr)%${NC}"
    echo -e "  Range: $(printf "%.4f" $min_price) - $(printf "%.4f" $max_price)"
    echo -e "  Preço atual: $(printf "%.4f" $pool_price)"
    
    if (( $(echo "$fee_pending > 0.01" | bc -l) )); then
      echo -e "  Fees pendentes: ${GREEN}\$$(printf "%.4f" $fee_pending)${NC}"
    fi
    
    echo "───────────────────────────────────────────────────────"
  done
  
  echo ""
}

# Comando: summary
cmd_summary() {
  local wallet=$(resolve_wallet "$1")
  local api_key=$(get_api_key)
  
  echo "📊 Resumo: ${wallet:0:6}...${wallet: -4}"
  echo ""
  
  local response=$(curl -s "${API_BASE}/v1/positions?wallet=${wallet}" \
    -H "KC-APIKey: ${api_key}" \
    -H "Content-Type: application/json")
  
  # Calcular totais (ignorando dust)
  local stats=$(echo "$response" | jq '
    [.[] | select(.liquidity != "0" and .currentPositionValue > 1)] |
    {
      count: length,
      total_value: (map(.currentPositionValue) | add // 0),
      total_pnl: (map(.performance.pnl) | add // 0),
      in_range: (map(select(.status == "IN_RANGE")) | length),
      out_range: (map(select(.status == "OUT_RANGE")) | length)
    }
  ')
  
  local count=$(echo "$stats" | jq -r '.count')
  local total_value=$(echo "$stats" | jq -r '.total_value')
  local total_pnl=$(echo "$stats" | jq -r '.total_pnl')
  local in_range=$(echo "$stats" | jq -r '.in_range')
  local out_range=$(echo "$stats" | jq -r '.out_range')
  
  echo "Posições abertas: $count"
  echo "Valor total: \$$(fmt_num $total_value)"
  echo "PnL total: \$$(printf "%.2f" $total_pnl)"
  echo "In range: 🟢 $in_range | Out range: 🔴 $out_range"
}

# Main
[[ $# -lt 1 ]] && usage

case "$1" in
  positions|pos|p)
    [[ -z "$2" ]] && usage
    cmd_positions "$2" "$3"
    ;;
  summary|sum|s)
    [[ -z "$2" ]] && usage
    cmd_summary "$2"
    ;;
  *)
    usage
    ;;
esac
