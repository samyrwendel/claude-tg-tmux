# Krystal - Skill de Consulta de Pools

Consulta posições de LP, pools e portfolio via Krystal Cloud API.

## Config

Antes de usar:

1. **API Key** — via env ou Bitwarden:
   ```bash
   export KRYSTAL_API_KEY="..."
   # OU (se usar Bitwarden)
   export KRYSTAL_BW_ID="<item-id-no-bitwarden>"
   ```

2. **Aliases de wallet (opcional)** — `~/.config/krystal/wallets.conf`:
   ```
   # alias=endereço
   minha=0xABCDEF...
   secundaria=0x123456...
   ```
   Esse arquivo NÃO vai pro repositório.

## Uso

```bash
# Ver posições abertas (aceita endereço 0x ou alias)
./krystal.sh positions <wallet|alias>

# Ignorar dust (< $1)
./krystal.sh positions <wallet|alias> --no-dust

# Resumo rápido
./krystal.sh summary <wallet|alias>

# Buscar pools por token
./krystal.sh search <token_symbol> [chain]
```

## Exemplos

```bash
# Por endereço
./krystal.sh positions 0xABCDEF0123456789ABCDEF0123456789ABCDEF01

# Por alias (configurado em wallets.conf)
./krystal.sh positions minha
```

## Output

Posições mostram:
- Par (TOKEN/USDT)
- Status (IN_RANGE 🟢, OUT_RANGE 🔴)
- Valor atual em USD
- PnL e ROI %
- APR estimado
- Range configurado vs preço atual
- Fees pendentes

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
