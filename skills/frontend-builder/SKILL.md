---
name: frontend-builder
description: Criar sites, landing pages, dashboards e qualquer frontend usando Claude com prompts otimizados do Anthropic Cookbook. Use quando o usuário pedir para criar, gerar ou fazer um site, página web, landing page, dashboard, app web, frontend, HTML, interface visual, ou qualquer coisa relacionada a criação de sites. Aciona em: "cria um site", "faz uma landing page", "quero um dashboard", "gera um HTML", "constrói uma interface", "faz o frontend de", "cria uma página".
---

# Frontend Builder

Gera frontends bonitos e distintivos usando o Anthropic Cookbook de estética frontend.

## Fluxo

1. Entender o que o usuário quer (tipo, tema, conteúdo, stack preferida)
2. Construir o system prompt completo (base + aesthetics + tema opcional)
3. Delegar ao Claude Code para gerar o HTML/projeto
4. Entregar o arquivo gerado e preview path

## Stack padrão

- **Simples (1 arquivo):** HTML + CSS + JS inline + Tailwind CDN
- **Projeto React:** Vite + React + Tailwind (via Claude Code em dir separado)

## Prompts

Os prompts de estética estão em `references/aesthetics.md`. Sempre ler esse arquivo antes de gerar.

### Composição do system prompt

```
BASE_SYSTEM + AESTHETICS_FULL + [TEMA_ESPECÍFICO se pedido]
```

Para controle isolado (só tipografia, só cores, etc.), usar as seções isoladas de `references/aesthetics.md`.

## Execução (Claude Code)

```bash
# HTML single-file
OUTDIR="/home/clawd/clawd-dev/sites/<nome-do-projeto>"
mkdir -p "$OUTDIR"
cd "$OUTDIR" && claude --permission-mode bypassPermissions --print \
  'Crie <descrição>. Use o seguinte system prompt: <SYSTEM_PROMPT_MONTADO>. Salve o resultado em index.html neste diretório.'
```

```bash
# Projeto React
OUTDIR="/home/clawd/clawd-dev/sites/<nome-do-projeto>"
cd "$OUTDIR" && claude --permission-mode bypassPermissions --print \
  'Crie um projeto Vite+React+Tailwind para <descrição>. <SYSTEM_PROMPT_MONTADO>. Inicialize o projeto, instale deps e crie os componentes.'
```

## Entrega

- Informar o path do arquivo gerado
- Se HTML single-file: mencionar que pode abrir direto no browser
- Se React: mencionar como rodar (`npm run dev`)

## Referências

- `references/aesthetics.md` — prompts de estética e tech stack base
- Cookbook local: `/home/clawd/clawd-dev/anthropic-cookbook/`
