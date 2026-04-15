---
name: dex-chart
description: Gera gráficos de candlestick de pools em DEX (Uniswap, PancakeSwap, etc.) via GeckoTerminal API.
homepage: https://geckoterminal.com
metadata: {"clawdbot":{"emoji":"📊","requires":{"bins":["python3"]}}}
---

# DEX Chart Skill

Gera gráficos de candlestick usando dados reais de pools em DEX.
Suporta **proxy rotation** para contornar rate limit.

## Quick Start

```bash
# Ativar venv e rodar
source /home/clawd/clawd/.venv/bin/activate && python3 {baseDir}/scripts/dex_chart.py [OPTIONS]
```

## Opções

| Flag | Descrição | Default |
|------|-----------|---------|
| `--chain`, `-c` | Rede (eth, bsc, arbitrum, base, polygon) | eth |
| `--pair`, `-p` | Endereço do par na DEX | WBTC/USDC Uniswap |
| `--timeframe`, `-t` | 1m, 5m, 15m, 30m, 1h, 4h, 1d | 1h |
| `--output`, `-o` | Arquivo de saída | dex_chart.png |
| `--title` | Título do gráfico | auto |
| `--proxy-file`, `-P` | Arquivo com lista de proxies | ~/.config/dex-chart/proxies.txt |
| `--no-proxy` | Desabilitar uso de proxies | false |

## Proxy Rotation

Para contornar o rate limit de 30 req/min, use proxies:

### Configurar proxies

```bash
# Criar arquivo de proxies
mkdir -p ~/.config/dex-chart
cat > ~/.config/dex-chart/proxies.txt << 'EOF'
http://proxy1.example.com:8080
http://user:pass@proxy2.example.com:3128
socks5://127.0.0.1:1080
EOF
```

### Usar proxies

```bash
# Usa proxies do arquivo padrão automaticamente
python3 dex_chart.py --chain bsc --pair 0x886... --timeframe 1h

# Usar arquivo de proxies específico
python3 dex_chart.py --proxy-file /path/to/proxies.txt

# Desabilitar proxies
python3 dex_chart.py --no-proxy
```

### Via variável de ambiente

```bash
export DEX_CHART_PROXIES="http://proxy1:8080,http://proxy2:8080"
python3 dex_chart.py
```

## Exemplos

```bash
# WBTC/USDC Uniswap 1h (default)
source /home/clawd/clawd/.venv/bin/activate && python3 {baseDir}/scripts/dex_chart.py

# ETH/USDC no Uniswap 4h
python3 {baseDir}/scripts/dex_chart.py --chain eth --pair 0x88e6A0c2dDD26FEEb64F039a2c41296FcB3f5640 --timeframe 4h

# BNB/USDT na PancakeSwap 15m
python3 {baseDir}/scripts/dex_chart.py --chain bsc --pair 0x16b9a82891338f9bA80E2D6970FddA79D1eb0daE --timeframe 15m

# RIVER/USDT todos os timeframes
for tf in 15m 1h 4h 1d; do
  python3 {baseDir}/scripts/dex_chart.py --chain bsc --pair 0x886928EB467EF5E69B4EBc2c8Af4275b21aF41BD --timeframe $tf --output river_$tf.png
done
```

## Pares Úteis

### Ethereum (Uniswap V3)
| Par | Endereço |
|-----|----------|
| WBTC/USDC | 0x99ac8cA7087fA4A2A1FB6357269965A2014ABc35 |
| ETH/USDC | 0x88e6A0c2dDD26FEEb64F039a2c41296FcB3f5640 |
| ETH/USDT | 0x4e68Ccd3E89f51C3074ca5072bbAC773960dFa36 |

### BSC (PancakeSwap / Uniswap)
| Par | Endereço |
|-----|----------|
| BNB/USDT | 0x16b9a82891338f9bA80E2D6970FddA79D1eb0daE |
| BTCB/USDT | 0x46cf1cF8c69595804ba91dFdd8d6b960c9B0a7C4 |
| RIVER/USDT | 0x886928EB467EF5E69B4EBc2c8Af4275b21aF41BD |

### Arbitrum
| Par | Endereço |
|-----|----------|
| ETH/USDC | 0xC31E54c7a869B9FcBEcc14363CF510d1c41fa443 |
| WBTC/ETH | 0x2f5e87C9312fa29aed5c179E456625D79015299c |

## Features

- ✅ **Cache de pares** - Info do par cacheada por 24h (~/.cache/dex-chart/)
- ✅ **Retry com backoff** - 3 tentativas com espera progressiva
- ✅ **Proxy rotation** - Round-robin com fallback automático
- ✅ **Eixo X inteligente** - Formato de data baseado no range
- ✅ **Estilo dark degen** - Tema escuro com cores verde/vermelho

## API

Usa GeckoTerminal API (gratuita, sem auth).
- Rate limit: ~30 req/min (por IP)
- OHLCV: últimos 100 candles
- Com proxies: rate limit multiplicado pelo número de proxies
