# Krystal - Skill de Consulta de Pools

Consulta posições de LP, pools e portfolio via Krystal Cloud API.

## Uso

```bash
# Ver posições abertas de uma wallet
./krystal.sh positions <wallet>

# Ver posições abertas (valor > $1, ignora dust)
./krystal.sh positions <wallet> --no-dust

# Ver detalhes de uma pool específica
./krystal.sh pool <chain> <pool_address>

# Buscar pools por token
./krystal.sh search <token_symbol> [chain]
```

## Exemplos

```bash
# Posições do Samyr
./krystal.sh positions 0x8b095455e1f828f895f01f26e651962e8b4c0a0a

# Pools RIVER na BSC
./krystal.sh search RIVER bsc
```

## Wallets Conhecidas

| Final | Endereço | Dono |
|-------|----------|------|
| 2188 | 0x0bcBB81c245BAA172Dd1564B1b6B02c8f69D2188 | Degenerado (opero) |
| 0a0a | 0x8b095455e1f828f895f01f26e651962e8b4c0a0a | Samyr (só consulta) |

## Output

Posições mostram:
- Par (TOKEN/USDT)
- Status (IN_RANGE 🟢, OUT_RANGE 🔴)
- Valor atual em USD
- PnL e ROI %
- APR estimado
- Range configurado vs preço atual
- Fees pendentes

## API Key

Usa Bitwarden: `KRYSTAL_API_KEY_2` (2a167c4d-...)

## Filtros

- **--no-dust**: Ignora posições < $1
- **--chain**: Filtra por chain (bsc, ethereum, arbitrum, etc)

## Chains Suportadas

| Chain | ID |
|-------|-----|
| Ethereum | 1 |
| BSC | 56 |
| Polygon | 137 |
| Arbitrum | 42161 |
| Base | 8453 |
| Optimism | 10 |
