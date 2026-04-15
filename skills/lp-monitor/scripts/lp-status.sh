#!/bin/bash
# LP Status - Fetch open positions from Krystal API
# Usage: lp-status.sh <wallet_address> [min_value_usd]

WALLET="${1:?Usage: lp-status.sh <wallet_address> [min_value_usd]}"
MIN_VALUE="${2:-1}"

# Get API key from file
API_KEY_FILE="$HOME/.clawdbot/.krystal-api-key"
if [ ! -f "$API_KEY_FILE" ]; then
    echo '{"error": "Krystal API key file not found"}'
    exit 1
fi
API_KEY=$(cat "$API_KEY_FILE")

# Fetch positions to temp file
TMPFILE=$(mktemp)
trap "rm -f $TMPFILE" EXIT

curl -s --max-time 15 "https://cloud-api.krystal.app/v1/positions?wallet=$WALLET" \
    -H "KC-APIKey: $API_KEY" \
    -H "Content-Type: application/json" > "$TMPFILE"

# Handle API error responses
if jq -e '.error' "$TMPFILE" > /dev/null 2>&1; then
    jq -r '{"error": .error, "count": 0}' "$TMPFILE"
    exit 1
fi

# Filter and format using external jq filter file
jq -r --argjson min "$MIN_VALUE" '
[.[] | select(.currentPositionValue >= $min) | select((.liquidity | tostring) != "0")] |
if length == 0 then
    {"message": "No open positions found", "count": 0}
else
    {
        count: length,
        positions: [.[] | {
            pool: "\(.pool.protocol.name) \([.currentAmounts[]?.token.symbol] | join("/"))",
            chain: .chain.name,
            status: .status,
            value: ((.currentPositionValue * 100 | floor) / 100),
            pnl: ((.performance.pnl * 100 | floor) / 100),
            roi: "\(((.performance.returnOnInvestment * 10000 | floor) / 100))%",
            apr: "\(((.performance.apr.totalApr * 100 | floor) / 100))%",
            price: ((.pool.poolPrice * 10000 | floor) / 10000),
            range: "\(((.minPrice * 100 | floor) / 100)) - \(((.maxPrice * 100 | floor) / 100))",
            fees: (([.tradingFee.pending[]?.value] | add * 100 | floor) / 100)
        }]
    }
end
' "$TMPFILE"
