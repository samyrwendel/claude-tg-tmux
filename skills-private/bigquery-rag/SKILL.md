---
name: bigquery-rag
description: Search conversation history using BigQuery vector search. Use when you need to recall past conversations, find what was discussed about a topic, or retrieve historical context.
homepage: https://cloud.google.com/bigquery/docs/vector-search
metadata: {"clawdbot":{"emoji":"🔍","requires":{"bins":["node"]}}}
---

# BigQuery RAG - Conversation Memory Search

Semantic search over all past conversations stored in BigQuery using VECTOR_SEARCH.

## Quick Search

```bash
# Basic search
node ~/clawd/bigquery-rag/search.js "o que discutimos sobre trading?"

# Search with filters
node ~/clawd/bigquery-rag/search.js --role user "pools de liquidez"
node ~/clawd/bigquery-rag/search.js --limit 10 "configuracao do bot"
node ~/clawd/bigquery-rag/search.js --from 2026-03-01 "projetos ativos"

# JSON output (for parsing)
node ~/clawd/bigquery-rag/search.js --json "decisoes tomadas"
```

## Options

| Flag | Description |
|------|-------------|
| `--role <user\|assistant>` | Filter by message role |
| `--limit <n>` | Number of results (default: 20) |
| `--from <date>` | Filter from date (ISO format) |
| `--to <date>` | Filter to date (ISO format) |
| `--session <id>` | Filter by session ID |
| `--min-score <0-1>` | Minimum similarity (default: 0.3) |
| `--json` | Output as JSON |

## When to Use

- "O que eu disse sobre X?"
- "Quando discutimos Y?"
- "Qual foi a decisao sobre Z?"
- "Buscar contexto historico de conversas"
- "Lembrar de algo que foi mencionado antes"

## Database Info

- **Table**: `gtm-mpvs7v5-ndvim.clawdbot.conversations_rag`
- **Embeddings**: OpenAI text-embedding-3-small (512 dims)
- **Search**: BigQuery VECTOR_SEARCH (cosine similarity)

## Example Output

```
🔍 Search: "trading de crypto"
📊 Found 5 results
────────────────────────────────────────────────────────────
👤 [87.3%] 05/03/2026, 14:32 (a1b2c3d4...)
   Quero configurar alertas de trading para BTC quando...
────────────────────────────────────────────────────────────
🤖 [82.1%] 05/03/2026, 14:33 (a1b2c3d4...)
   Configurei o monitor de BTC com os seguintes parametros...
```

## Guardrails

- Resultados sao ordenados por similaridade (score mais alto = mais relevante)
- Use filtros de data para buscas mais precisas
- Combine com `--role user` para encontrar o que VOCE disse
- Combine com `--role assistant` para encontrar o que o BOT respondeu
