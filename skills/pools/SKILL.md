---
name: pools
description: Gerenciamento de pools de liquidez (LP) via Krystal API. Zap-in, zap-out, claim fees, compound, rebalance, e auto-operações.
metadata: {"clawdbot":{"emoji":"🏊"}}
---

# Pools Skill

Skill de gerenciamento de pools de liquidez via Krystal API.

## Funcionalidades

### Operações Básicas
- 📥 **Entrar na pool** — Zap-In com 1 token
- 📤 **Sair da pool** — Zap-Out pra 1 token
- 🫴 **Claim Fees** — Coletar fees acumulados
- ♻️ **Compound** — Reinvestir fees

### Operações Avançadas
- 🤹 **Rebalance** — Ajustar range da posição
- 🤖 **Auto-Rebalance** — Rebalanceamento automático
- 🤖 **Auto-Compound** — Compound automático
- 🤖 **Auto-Exit** — Sair em condição específica

### Monitoramento
- 📊 Listar posições abertas
- 💰 Ver PnL e IL (Impermanent Loss)
- 📈 APR atual das posições
- 🔔 Alertas de preço/range

## DEXs Suportadas

- Uniswap V3
- PancakeSwap V3
- SushiSwap
- Aerodrome
- Velodrome
- Camelot
- +30 outras via Krystal

## Chains Suportadas

- Ethereum
- Arbitrum
- Base
- BSC (BNB Chain)
- Polygon
- Avalanche
- Optimism
- Fantom

## Configuração

### Variáveis de Ambiente

Crie o arquivo `~/.config/pools/config.json`:

```json
{
  "krystal_api_key": "SUA_KRYSTAL_API_KEY",
  "wallet_address": "0xSEU_WALLET",
  "private_key": "SUA_PRIVATE_KEY_PARA_ASSINAR_TX",
  "default_chain": "arbitrum",
  "default_dex": "uniswapv3",
  "settings": {
    "slippage_pct": 0.5,
    "gas_limit_multiplier": 1.2,
    "auto_compound_threshold_usd": 10,
    "auto_rebalance_pct_out_of_range": 5
  },
  "notifications": {
    "telegram": true,
    "on_enter": true,
    "on_exit": true,
    "on_out_of_range": true,
    "daily_summary": true
  },
  "auto_exit": {
    "enabled": false,
    "conditions": {
      "il_pct_max": 10,
      "price_below": null,
      "price_above": null,
      "apr_below": 5
    }
  }
}
```

### Variáveis Necessárias

| Variável | Descrição | Obrigatória |
|----------|-----------|-------------|
| `krystal_api_key` | API Key da Krystal Cloud | ✅ |
| `wallet_address` | Endereço da wallet | ✅ |
| `private_key` | Chave privada (pra assinar transações) | ✅ |
| `default_chain` | Chain padrão (ethereum, arbitrum, etc.) | ❌ |
| `default_dex` | DEX padrão (uniswapv3, pancakeswapv3) | ❌ |

## Comandos

### Via Chat

```
pool list                          # Lista posições abertas
pool enter ETH/USDC 1000 arbitrum  # Entra na pool com $1000
pool exit <position_id>            # Sai da pool
pool exit <position_id> 50%        # Sai parcialmente
pool claim <position_id>           # Coleta fees
pool compound <position_id>        # Reinveste fees
pool rebalance <position_id>       # Rebalanceia
pool status                        # Status geral
pool pnl                           # PnL de todas posições
```

### Auto-Operações

```
pool auto-compound <position_id> on   # Ativa auto-compound
pool auto-rebalance <position_id> on  # Ativa auto-rebalance
pool auto-exit <position_id> il:10%   # Auto-exit se IL > 10%
pool auto-exit <position_id> apr:<5   # Auto-exit se APR < 5%
```

### Via Script

```bash
./scripts/list.sh                     # Lista posições
./scripts/enter.sh ETH/USDC 1000      # Entrar
./scripts/exit.sh <position_id>       # Sair
./scripts/claim.sh <position_id>      # Claim fees
./scripts/compound.sh <position_id>   # Compound
./scripts/rebalance.sh <position_id>  # Rebalance
```

## APIs Utilizadas

### Krystal Cloud API
```
Base: https://cloud-api.krystal.app/v1/
Docs: https://api-docs.krystal.app/docs/index.html
```

### Endpoints Principais
- `GET /pools` — Listar pools disponíveis
- `GET /positions` — Listar posições do wallet
- `POST /liquidity/add` — Adicionar liquidez
- `POST /liquidity/remove` — Remover liquidez
- `POST /liquidity/claim` — Coletar fees
- `POST /liquidity/compound` — Compound
- `POST /liquidity/rebalance` — Rebalancear

## Fluxo de Operação

### Entrar na Pool
1. Usuário: `pool enter ETH/USDC 1000`
2. Bot consulta melhores pools pra esse par
3. Bot mostra opções com APR
4. Usuário confirma (human-in-loop)
5. Bot executa Zap-In via Krystal
6. Notifica resultado

### Auto-Exit
1. Bot monitora posição periodicamente
2. Se condição atingida (IL > X%, APR < Y%)
3. Notifica usuário
4. Se auto-exit ON → executa saída
5. Se auto-exit OFF → só avisa

## TODO

- [ ] Configurar Krystal API key
- [ ] Testar conexão
- [ ] Implementar listagem de posições
- [ ] Implementar enter/exit básico
- [ ] Adicionar Zap-In/Zap-Out
- [ ] Implementar auto-compound
- [ ] Implementar auto-rebalance
- [ ] Implementar auto-exit
- [ ] Dashboard de performance
- [ ] Alertas de out-of-range
