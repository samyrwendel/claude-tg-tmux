#!/usr/bin/env node
/**
 * poly.js — Polymarket CLI for Degen agent
 * Wraps trader.js from world-monitor-polymarket
 *
 * Usage:
 *   node poly.js balance
 *   node poly.js positions
 *   node poly.js search <query>
 *   node poly.js buy <slug> <YES|NO> <amount>
 *   node poly.js sell <orderId>
 *   node poly.js cancel-all
 *   node poly.js trades
 *   node poly.js cashout <slug>
 *   node poly.js cashout-all
 */

// APP_DIR deve apontar para o clone local do world-monitor-polymarket
// Definir via env POLY_APP_DIR, ou default em $DEV_ROOT/world-monitor-polymarket
const path = require('path');
const APP_DIR = process.env.POLY_APP_DIR
  || path.join(process.env.DEV_ROOT || path.join(process.env.HOME, 'dev'), 'world-monitor-polymarket');

const fs = require('fs');
if (!fs.existsSync(APP_DIR)) {
  console.error(`❌ APP_DIR não encontrado: ${APP_DIR}`);
  console.error('Defina POLY_APP_DIR ou DEV_ROOT no ambiente.');
  process.exit(1);
}
process.chdir(APP_DIR);
// Resolve modules from the app directory
module.paths.unshift(path.join(APP_DIR, 'node_modules'));
require('dotenv').config({ path: APP_DIR + '/.env' });

// Force live mode for manual commands (DRY_RUN only applies to auto-trade)
process.env.DRY_RUN = 'false';

const { PolymarketTrader } = require(APP_DIR + '/src/trader');
const { PolymarketAPI } = require(APP_DIR + '/src/polymarket-api');

const GAMMA_BASE = 'https://gamma-api.polymarket.com';
const PROXY_WALLET = process.env.PROXY_WALLET;

async function main() {
  const [,, cmd, ...args] = process.argv;

  if (!cmd || cmd === 'help') {
    console.log(`poly.js — Polymarket CLI
Commands:
  balance              Show USDC balance
  positions            List open positions
  search <query>       Search active markets
  buy <slug> YES|NO <amount>   Place market order
  sell <orderId>       Cancel an open order
  cancel-all           Cancel all open orders
  trades               Recent trade history
  market <slug>        Show market details
  cashout <slug>       Cash out a position (FOK sell at best bid)
  cashout-all          Cash out ALL open positions`);
    return;
  }

  const trader = new PolymarketTrader();

  if (cmd === 'balance') {
    // On-chain USDC.e balance on Polygon via 1rpc.io
    const USDC_CONTRACT = '0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174';
    const padded = PROXY_WALLET.toLowerCase().replace('0x', '').padStart(64, '0');
    const res = await fetch('https://1rpc.io/matic', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        jsonrpc: '2.0', method: 'eth_call',
        params: [{ to: USDC_CONTRACT, data: '0x70a08231' + padded }, 'latest'],
        id: 1,
      }),
    });
    const data = await res.json();
    if (data.result) {
      const balance = parseInt(data.result, 16) / 1e6;
      console.log(`💰 USDC Balance (on-chain): $${balance.toFixed(2)}`);
    } else {
      console.log(`Balance query failed: ${JSON.stringify(data.error || data)}`);
    }
    return;
  }

  if (cmd === 'positions') {
    // Use data-api.polymarket.com for positions
    const res = await fetch(`https://data-api.polymarket.com/positions?user=${PROXY_WALLET}`);
    if (!res.ok) {
      console.error(`Positions API error: ${res.status}`);
      return;
    }
    const positions = await res.json();
    if (!positions.length) {
      console.log('No open positions.');
      return;
    }
    console.log(`📊 Open Positions (${positions.length}):\n`);
    let totalPnl = 0;
    for (const p of positions) {
      const outcome = p.outcome || '?';
      const size = parseFloat(p.size || 0).toFixed(2);
      const avgPrice = parseFloat(p.avgPrice || 0).toFixed(3);
      const curPrice = parseFloat(p.curPrice || 0).toFixed(3);
      const cashPnl = parseFloat(p.cashPnl || 0);
      const pctPnl = parseFloat(p.percentPnl || 0).toFixed(1);
      totalPnl += cashPnl;
      const pnlStr = `${cashPnl >= 0 ? '+' : ''}$${cashPnl.toFixed(2)} (${pctPnl >= 0 ? '+' : ''}${pctPnl}%)`;
      const endDate = p.endDate ? ` | ends ${p.endDate}` : '';
      console.log(`• ${p.title}`);
      console.log(`  ${outcome} | ${size} shares | avg $${avgPrice} → now $${curPrice} | PnL: ${pnlStr}${endDate}\n`);
    }
    console.log(`Total PnL: ${totalPnl >= 0 ? '+' : ''}$${totalPnl.toFixed(2)}`);
    return;
  }

  if (cmd === 'search') {
    const query = args.join(' ');
    if (!query) { console.error('Usage: poly.js search <query>'); return; }
    const api = new PolymarketAPI();
    const results = await api.searchMarkets(query.split(' '), null);
    if (!results.length) { console.log('No markets found.'); return; }
    console.log(`🔍 Markets matching "${query}":\n`);
    for (const r of results) {
      console.log(`• ${r.marketQuestion}`);
      console.log(`  Slug: ${r.marketSlug}`);
      console.log(`  YES: $${r.yesPrice.toFixed(3)} | NO: $${r.noPrice.toFixed(3)} | Vol24h: $${Math.round(r.volume24h)}`);
      if (r.endDate) console.log(`  Ends: ${r.endDate}`);
      console.log('');
    }
    return;
  }

  if (cmd === 'market') {
    const slug = args[0];
    if (!slug) { console.error('Usage: poly.js market <slug>'); return; }
    await trader.init();
    const m = await trader.resolveMarket(slug);
    console.log(`📌 ${m.question}`);
    console.log(`  Slug: ${m.slug}`);
    console.log(`  Condition ID: ${m.conditionId}`);
    console.log(`  YES token: ${m.yesTokenId}`);
    console.log(`  NO token: ${m.noTokenId}`);
    console.log(`  Tick size: ${m.tickSize}`);
    // Get orderbook
    const ob = await trader.client.getOrderBook(m.yesTokenId);
    if (ob?.asks?.length) console.log(`  Best YES ask: $${ob.asks[0].price}`);
    if (ob?.bids?.length) console.log(`  Best YES bid: $${ob.bids[0].price}`);
    return;
  }

  if (cmd === 'buy') {
    const [slug, dir, amtStr] = args;
    if (!slug || !dir || !amtStr) {
      console.error('Usage: poly.js buy <slug> YES|NO <amount>');
      return;
    }
    const direction = dir.toUpperCase();
    if (direction !== 'YES' && direction !== 'NO') {
      console.error('Direction must be YES or NO');
      return;
    }
    const amount = parseFloat(amtStr);
    if (isNaN(amount) || amount <= 0) {
      console.error('Amount must be a positive number');
      return;
    }
    await trader.init();
    console.log(`🎯 Buying ${direction} on "${slug}" for $${amount}...`);
    const result = await trader.placeMarketOrder(slug, direction, amount);
    console.log(`✅ Order placed!`);
    console.log(`  Order ID: ${result.orderID || result.id || JSON.stringify(result).slice(0, 100)}`);
    console.log(`  Status: ${result.status || 'submitted'}`);
    if (result.orderID) console.log(`\nSave this order ID if you need to cancel: ${result.orderID}`);
    return;
  }

  if (cmd === 'sell' || cmd === 'cancel') {
    const orderId = args[0];
    if (!orderId) { console.error('Usage: poly.js sell <orderId>'); return; }
    await trader.init();
    const result = await trader.cancelOrder(orderId);
    console.log(`✅ Order ${orderId} cancelled`);
    console.log(JSON.stringify(result, null, 2));
    return;
  }

  if (cmd === 'cancel-all') {
    await trader.init();
    const result = await trader.cancelAll();
    console.log('✅ All orders cancelled');
    console.log(JSON.stringify(result, null, 2));
    return;
  }

  if (cmd === 'trades') {
    await trader.init();
    const trades = await trader.getTrades();
    if (!trades?.length) { console.log('No trades found.'); return; }
    console.log(`📜 Recent Trades (${trades.length}):\n`);
    for (const t of trades.slice(0, 10)) {
      console.log(`• ${t.market || t.outcome || 'Trade'}`);
      console.log(`  ${JSON.stringify(t).slice(0, 120)}\n`);
    }
    return;
  }

  // ── Cash Out ──────────────────────────────────────────────────────────────
  if (cmd === 'cashout') {
    const slug = args[0];
    if (!slug) { console.error('Usage: poly.js cashout <slug>'); return; }

    // Fetch positions and find the matching one
    const res = await fetch(`https://data-api.polymarket.com/positions?user=${PROXY_WALLET}`);
    if (!res.ok) { console.error(`Positions API error: ${res.status}`); return; }
    const positions = await res.json();

    const pos = positions.find(p =>
      (p.slug || '').toLowerCase().includes(slug.toLowerCase()) ||
      (p.title || '').toLowerCase().includes(slug.replace(/-/g, ' ').toLowerCase())
    );

    if (!pos) {
      console.error(`❌ Position not found for slug: ${slug}`);
      console.error('Run `node poly.js positions` to see open positions.');
      return;
    }

    console.log(`💸 Cashing out: ${pos.title}`);
    console.log(`   Outcome: ${pos.outcome} | Size: ${pos.size} | Avg price: $${parseFloat(pos.avgPrice || 0).toFixed(3)}`);

    const { Side, OrderType } = require('@polymarket/clob-client');
    await trader.init();
    const client = trader.client;

    // Get best bid for this asset
    const book = await client.getOrderBook(pos.asset);
    const bestBid = book?.bids?.[0]?.price;
    if (!bestBid) { console.error('❌ No bids in orderbook — cannot cash out'); return; }

    // Sell at 1% below best bid to guarantee fill (FOK)
    const price = Math.max(0.01, Math.round(parseFloat(bestBid) * 0.99 * 100) / 100);
    const size = parseFloat(pos.size || 0);

    console.log(`   Best bid: $${parseFloat(bestBid).toFixed(3)} → using $${price} (FOK)`);
    console.log(`   Size: ${size} shares → recovery: ~$${(size * price).toFixed(2)}`);
    console.log('   Placing FOK sell order...');

    const result = await client.createAndPostOrder(
      { tokenID: pos.asset, price, size, side: Side.SELL, orderType: OrderType.FOK },
      { tickSize: '0.01', negRisk: pos.negativeRisk || false }
    );

    console.log(`✅ Cash out submitted!`);
    console.log(`   Order ID: ${result?.orderID || result?.orderID || 'unknown'}`);
    console.log(`   Status: ${result?.status || 'submitted'}`);
    return;
  }

  if (cmd === 'cashout-all') {
    const res = await fetch(`https://data-api.polymarket.com/positions?user=${PROXY_WALLET}`);
    if (!res.ok) { console.error(`Positions API error: ${res.status}`); return; }
    const positions = await res.json();
    if (!positions.length) { console.log('No open positions to cash out.'); return; }

    const { Side, OrderType } = require('@polymarket/clob-client');
    await trader.init();
    const client = trader.client;

    console.log(`💸 Cashing out all ${positions.length} positions...\n`);
    const results = [];
    for (const pos of positions) {
      try {
        const book = await client.getOrderBook(pos.asset);
        const bestBid = book?.bids?.[0]?.price;
        if (!bestBid) {
          console.log(`⏭️  ${pos.title} — no bids, skipping`);
          continue;
        }
        const price = Math.max(0.01, Math.round(parseFloat(bestBid) * 0.99 * 100) / 100);
        const size = parseFloat(pos.size || 0);
        const recovery = (size * price).toFixed(2);
        const result = await client.createAndPostOrder(
          { tokenID: pos.asset, price, size, side: Side.SELL, orderType: OrderType.FOK },
          { tickSize: '0.01', negRisk: pos.negativeRisk || false }
        );
        console.log(`✅ ${pos.title.slice(0, 50)} → $${recovery} (order: ${result?.orderID || 'submitted'})`);
        results.push({ title: pos.title, recovery, orderId: result?.orderID });
      } catch (err) {
        console.log(`❌ ${pos.title}: ${err.message}`);
      }
    }
    const total = results.reduce((s, r) => s + parseFloat(r.recovery), 0);
    console.log(`\n💰 Total recovery: ~$${total.toFixed(2)} from ${results.length}/${positions.length} positions`);
    return;
  }

  console.error(`Unknown command: ${cmd}. Run 'node poly.js help' for usage.`);
}

main().catch(err => {
  console.error(`❌ Error: ${err.message}`);
  process.exit(1);
});
