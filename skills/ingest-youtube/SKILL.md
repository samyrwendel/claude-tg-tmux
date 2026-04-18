---
name: ingest-youtube
description: Ingere um vídeo do YouTube no wiki local. Baixa o áudio com yt-dlp, transcreve com Whisper, salva em raw/transcripts/ e cria página em wiki/sources/. Ativa quando o usuário manda uma URL do YouTube com intenção de salvar, estudar, transcrever, ingerar, ou similar. Palavras-chave: transcreve, ingerir, salva no wiki, baixa esse vídeo, anota isso.
---

# Ingest YouTube → Wiki Local

Transcreve um vídeo do YouTube e salva num wiki local.

## Config

Defina `WIKI_ROOT` no ambiente (ou no `.env` do projeto):

```bash
export WIKI_ROOT="$HOME/wiki"  # ajuste ao teu setup
```

Estrutura esperada em `$WIKI_ROOT`:
- `tools/ingest-youtube.py` — script de ingestão
- `raw/transcripts/` — áudios + transcrições
- `wiki/sources/` — páginas geradas
- `wiki/index.md` + `wiki/log.md` — índice/log

## Quando usar

- Usuário manda URL do YouTube e pede pra salvar, transcrever, ingerar, ou "quero estudar isso"
- **NÃO usar** quando o pedido é análise de canal inteiro ou clonar personalidade — para isso usar `youtube-brain-clone`

## Execução

```bash
python "$WIKI_ROOT/tools/ingest-youtube.py" "<URL>" --lang pt
```

Flags opcionais:
- `--model` — modelo Whisper: `tiny` (rápido), `small` (padrão), `medium` (mais preciso)
- `--lang` — hint de idioma: `pt`, `en`, `es`

## O que o script faz

1. Pega o título do vídeo via yt-dlp
2. Baixa o áudio em MP3 para `raw/transcripts/<slug>.mp3`
3. Transcreve com Whisper → salva em `raw/transcripts/<slug>.txt`
4. Cria página wiki em `wiki/sources/<slug>.md` com frontmatter, excerto e link pro transcript
5. Atualiza `wiki/index.md` e appenda em `wiki/log.md`

## Pós-ingest

Após rodar o script, ler a página criada em `wiki/sources/<slug>.md` e:
- Extrair os principais insights
- Criar ou atualizar páginas em `wiki/concepts/` ou `wiki/entities/` se relevante
- Informar o usuário com resumo do que foi ingerido

## Exemplo

Usuário manda: "transcreve isso https://youtube.com/watch?v=xxx"

```bash
python "$WIKI_ROOT/tools/ingest-youtube.py" "https://youtube.com/watch?v=xxx" --lang pt
```

Depois ler o arquivo criado e responder com resumo do conteúdo.
