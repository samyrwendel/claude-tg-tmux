---
name: polymarket
description: Trade and manage Polymarket prediction market positions. Use when user wants to check balance, view open positions, search markets, buy/sell YES or NO shares, or cancel orders on Polymarket. Trigger words: polymarket, apostar, aposta, posição, mercado predição, odds, YES, NO, saldo polymarket.
---

# Polymarket

## Overview

This skill wraps the `poly.js` CLI to interact with Polymarket prediction markets on Polygon (USDC.e). It supports checking balances, browsing and searching markets, placing market orders, monitoring positions, and cancelling orders.

## Commands

All commands follow the pattern:
```bash
node /home/clawd/.openclaw/skills/polymarket/scripts/poly.js <command>
```

---

### balance
Show on-chain USDC.e balance for the proxy wallet.

```bash
node /home/clawd/.openclaw/skills/polymarket/scripts/poly.js balance
```

Example output:
```
💰 USDC Balance (on-chain): $124.50
```

---

### positions
List all open positions with PnL details.

```bash
node /home/clawd/.openclaw/skills/polymarket/scripts/poly.js positions
```

Example output:
```
📊 Open Positions (2):

• Will the Fed cut rates in March 2026?
  YES | 50.00 shares | avg $0.620 → now $0.710 | PnL: +$4.50 (+14.5%) | ends 2026-03-31

Total PnL: +$4.50
```

---

### search
Search for active markets by keyword.

```bash
node /home/clawd/.openclaw/skills/polymarket/scripts/poly.js search <query>
```

Example:
```bash
node /home/clawd/.openclaw/skills/polymarket/scripts/poly.js search bitcoin ETF
```

Example output:
```
🔍 Markets matching "bitcoin ETF":

• Will Bitcoin ETF reach $50B AUM in 2026?
  Slug: bitcoin-etf-50b-aum-2026
  YES: $0.420 | NO: $0.580 | Vol24h: $18432
  Ends: 2026-12-31
```

---

### market
Show detailed info and current orderbook for a specific market by slug.

```bash
node /home/clawd/.openclaw/skills/polymarket/scripts/poly.js market <slug>
```

Example:
```bash
node /home/clawd/.openclaw/skills/polymarket/scripts/poly.js market bitcoin-etf-50b-aum-2026
```

Example output:
```
📌 Will Bitcoin ETF reach $50B AUM in 2026?
  Slug: bitcoin-etf-50b-aum-2026
  Condition ID: 0xabc...
  YES token: 0x123...
  NO token: 0x456...
  Tick size: 0.01
  Best YES ask: $0.425
  Best YES bid: $0.415
```

---

### buy
Place a market order for YES or NO shares.

```bash
node /home/clawd/.openclaw/skills/polymarket/scripts/poly.js buy <slug> YES|NO <amount>
```

- `slug`: market slug from search results
- `YES|NO`: direction to bet
- `amount`: amount in USDC to spend

Example:
```bash
node /home/clawd/.openclaw/skills/polymarket/scripts/poly.js buy bitcoin-etf-50b-aum-2026 YES 10
```

Example output:
```
🎯 Buying YES on "bitcoin-etf-50b-aum-2026" for $10...
✅ Order placed!
  Order ID: 0xdeadbeef...
  Status: submitted

Save this order ID if you need to cancel: 0xdeadbeef...
```

---

### sell / cancel
Cancel a specific open order by order ID.

```bash
node /home/clawd/.openclaw/skills/polymarket/scripts/poly.js sell <orderId>
```

Example:
```bash
node /home/clawd/.openclaw/skills/polymarket/scripts/poly.js sell 0xdeadbeef...
```

Example output:
```
✅ Order 0xdeadbeef... cancelled
```

---

### cancel-all
Cancel all open orders at once.

```bash
node /home/clawd/.openclaw/skills/polymarket/scripts/poly.js cancel-all
```

Example output:
```
✅ All orders cancelled
```

---

### trades
Show recent trade history (last 10 trades).

```bash
node /home/clawd/.openclaw/skills/polymarket/scripts/poly.js trades
```

Example output:
```
📜 Recent Trades (5):

• Will the Fed cut rates in March 2026?
  {"outcome":"YES","price":0.62,"size":50,"timestamp":"2026-03-10T..."}
```

---

## Workflow

Typical flow for placing a trade:

1. **Check balance** — confirm available USDC before trading:
   ```bash
   node /home/clawd/.openclaw/skills/polymarket/scripts/poly.js balance
   ```

2. **Search for a market** — find the market slug:
   ```bash
   node /home/clawd/.openclaw/skills/polymarket/scripts/poly.js search <topic>
   ```

3. **Inspect the market (optional)** — check orderbook and token details:
   ```bash
   node /home/clawd/.openclaw/skills/polymarket/scripts/poly.js market <slug>
   ```

4. **Place the order** — buy YES or NO shares:
   ```bash
   node /home/clawd/.openclaw/skills/polymarket/scripts/poly.js buy <slug> YES|NO <amount>
   ```
   Save the returned Order ID.

5. **Monitor positions** — check PnL on open positions:
   ```bash
   node /home/clawd/.openclaw/skills/polymarket/scripts/poly.js positions
   ```

6. **Cancel if needed** — cancel a specific order or all orders:
   ```bash
   node /home/clawd/.openclaw/skills/polymarket/scripts/poly.js sell <orderId>
   # or
   node /home/clawd/.openclaw/skills/polymarket/scripts/poly.js cancel-all
   ```

## Notes

- Credentials (`PROXY_WALLET`, private keys) are loaded from `/home/clawd/clawd-dev/world-monitor-polymarket/.env`.
- `DRY_RUN` is forced to `false` in `poly.js` — all commands execute live trades on Polygon mainnet.
- Token: USDC.e on Polygon. Make sure the proxy wallet has sufficient USDC.e before buying.
- The `sell` and `cancel` commands are aliases — both cancel an open order (Polymarket uses a CLOB; positions are exited by cancelling limit orders or placing opposing market orders).
- Market slugs come from search results — always use `search` first to get the correct slug.
