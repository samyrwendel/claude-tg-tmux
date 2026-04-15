# GoPlus Security Skill

Verifica segurança de tokens via GoPlus API. Detecta honeypots, rug pulls, e red flags.

## Uso

```bash
# Verificar token por endereço
./goplus.sh <chain> <token_address>

# Chains suportadas: eth, bsc, polygon, arbitrum, base, optimism, avalanche
```

## Exemplos

```bash
# Verificar PEPE na Ethereum
./goplus.sh eth 0x6982508145454ce325ddbe47a25d4ec3d2311933

# Verificar token na BSC
./goplus.sh bsc 0x...
```

## Output

Retorna diagnóstico com:
- Honeypot detection
- Mintable check
- Owner privileges
- Trading restrictions
- Tax info
- Holder count
- Security score (0-100)

## Chain IDs

| Chain | Código |
|-------|--------|
| Ethereum | eth |
| BSC | bsc |
| Polygon | polygon |
| Arbitrum | arbitrum |
| Base | base |
| Optimism | optimism |
| Avalanche | avalanche |

## API

GoPlus API é pública, sem necessidade de API key para uso básico.
Endpoint: `https://api.gopluslabs.io/api/v1/token_security/{chainId}?contract_addresses={address}`
