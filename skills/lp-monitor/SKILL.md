---
name: lp-monitor
description: Monitor LP positions via Krystal API and pool data via DexScreener. Use when checking LP positions, pool status, fees, PnL, or setting up monitoring for DeFi liquidity positions.
---

# LP Monitor

Monitor liquidity positions and pools on DEXes.

## Quick Commands

```bash
# List open positions for a wallet
scripts/lp-status.sh <wallet_address>

# Get pool info from DexScreener  
scripts/pool-info.sh <chain> <pool_address>
```

## Position Filtering

- **Open position:** liquidity != "0" AND value >= $1
- **Closed/dust:** liquidity == "0" OR value < $1 (ignore these)

## Key Metrics

| Metric | Source | Meaning |
|--------|--------|---------|
| status | Krystal | IN_RANGE / OUT_RANGE |
| currentPositionValue | Krystal | Total USD value |
| pnl | Krystal | Profit/Loss in USD |
| apr.totalApr | Krystal | Estimated APR |
| minPrice/maxPrice | Krystal | Position range |
| pool.poolPrice | Krystal | Current price |
| volume.h24 | DexScreener | 24h volume |
| liquidity.usd | DexScreener | Pool TVL |

## Alert Conditions

Notify user when:
- Position goes OUT_RANGE
- PnL drops below -10%
- Volume drops >50% from average
- Price approaches range edges (<5% margin)

## API Details

### Krystal Cloud API
- Base: `https://cloud-api.krystal.app`
- Auth: `KC-APIKey` header
- Key location: Bitwarden `REDACTED_BW_ITEM_ID`

### DexScreener API
- Base: `https://api.dexscreener.com/latest/dex/pairs/{chain}/{address}`
- No auth required

## Chains

| Chain | Krystal ID | DexScreener |
|-------|------------|-------------|
| BSC | 56 | bsc |
| Ethereum | 1 | ethereum |
| Arbitrum | 42161 | arbitrum |
| Base | 8453 | base |
| Polygon | 137 | polygon |
