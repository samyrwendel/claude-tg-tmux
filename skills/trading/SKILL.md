---
name: trading
description: Trading automatizado em perps/spot via Hyperliquid API. Long/short, stop-loss, take-profit, gestão de risco, e análise de sentimento.
metadata: {"clawdbot":{"emoji":"📈"}}
---

# Trading Skill

Skill de trading automatizado integrada com Hyperliquid API.

## Funcionalidades

### Execução de Trades
- Long/Short em perps
- Spot trading
- Stop-loss e take-profit automáticos

### Análise
- Sentimento de mercado (Twitter/X)
- Análise técnica básica (RSI, médias móveis)
- Trump-Tracker (volatilidade política)

### Gestão de Risco
- Regra 1-2%: máximo 2% do equity por posição
- Anti-Knife Catching: só entra alinhado com tendência
- Human-in-the-loop para trades grandes

### Auto-Aprendizado
- Post-mortem automático em cada trade
- Estratégias vencedoras = "High Probability"
- 3 losses consecutivos = estratégia "benched"
- RAG memory pra evitar repetir erros

## Configuração

### Variáveis de Ambiente (ou em TOOLS.md)

```
HYPERLIQUID_API_KEY=<sua-api-key>
HYPERLIQUID_API_SECRET=<seu-secret>
HYPERLIQUID_WALLET=<seu-wallet-address>
TRADING_MODE=human-in-loop  # ou auto-trade
MAX_POSITION_PCT=2          # máximo % do equity por posição
```

## Comandos

### Via Chat
- `trade long BTC 100 USDT` — abre long em BTC
- `trade short ETH 50 USDT` — abre short em ETH
- `positions` — lista posições abertas
- `pnl` — mostra PnL atual
- `close BTC` — fecha posição em BTC
- `status trading` — status do sistema de trading

### Via Script
```bash
# Conectar à Hyperliquid
./scripts/connect.sh

# Executar trade
./scripts/trade.sh long BTC 100

# Ver posições
./scripts/positions.sh

# Fechar posição
./scripts/close.sh BTC
```

## Modos de Operação

### 1. Human-in-the-Loop (Recomendado pra começar)
- Bot analisa e sugere trades
- Você aprova via botão no Telegram
- Trades grandes sempre pedem confirmação

### 2. Auto-Trade (Avançado)
- Bot executa automaticamente
- Respeita limites de risco configurados
- Notifica após execução

## Integração com Clawdbot/Moltbot

A skill se integra nativamente:
- Recebe comandos via Telegram/Discord/WhatsApp
- Usa memory search pra contexto histórico
- Pode ser invocada por outras skills

## TODO

- [ ] Configurar API keys
- [ ] Testar conexão com Hyperliquid
- [ ] Implementar execução básica
- [ ] Adicionar análise de sentimento
- [ ] Implementar RAG memory pra trades
- [ ] Dashboard de performance
