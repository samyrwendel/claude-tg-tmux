#!/bin/bash
# Pool Info - Fetch pool data from DexScreener
# Usage: pool-info.sh <chain> <pool_address>

CHAIN="${1:?Usage: pool-info.sh <chain> <pool_address>}"
POOL="${2:?Usage: pool-info.sh <chain> <pool_address>}"

curl -s "https://api.dexscreener.com/latest/dex/pairs/$CHAIN/$POOL" | \
jq '.pair | {
    name: "\(.baseToken.symbol)/\(.quoteToken.symbol)",
    dex: .dexId,
    price: .priceUsd,
    price_change: {
        "5m": .priceChange.m5,
        "1h": .priceChange.h1,
        "6h": .priceChange.h6,
        "24h": .priceChange.h24
    },
    volume: {
        "5m": .volume.m5,
        "1h": .volume.h1,
        "6h": .volume.h6,
        "24h": .volume.h24
    },
    txns_24h: (.txns.h24.buys + .txns.h24.sells),
    liquidity_usd: .liquidity.usd,
    fdv: .fdv,
    market_cap: .marketCap,
    pair_address: .pairAddress,
    base_token: .baseToken.address,
    socials: [.info.socials[]? | "\(.type): \(.url)"]
}'
