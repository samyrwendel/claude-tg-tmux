# Project: Mainbot Infrastructure — clawd

**Created:** 2026-04-22  
**Owner:** Samyr Wendel  
**Status:** Active  

---

## What This Is

Evolução contínua da infraestrutura do mainbot (claude-tg-tmux / @mainagentebot). O mainbot é o orquestrador central que recebe comandos do Samyr via Telegram, classifica, delega para sub-agentes especializados (devbot, execbot, degenbot) e retorna resultados.

O projeto organiza as melhorias inspiradas no SandeClaw + automações do dream cycle + pipeline financeiro + robustez geral.

---

## Core Value

**Mainbot autônomo e proativo** — recebe, classifica, executa e alerta sem precisar de intervenção manual para fluxos recorrentes.

---

## Context

- **Codebase:** `/home/clawd/claude-tg-tmux/`
- **Bot:** @mainagentebot (Sonnet 4.6)
- **Sub-agentes:** devbot (Opus), execbot (Sonnet), degenbot (Opus), cronbot (monitor)
- **Runtime:** Claude Code CLI com plugin:telegram
- **Hooks ativos:** log-incoming-telegram, cronbot-alerts, skill-router, attachment-handler

### Estado atual (22/04/2026)

**Implementado nesta sessão:**
- ✅ `skill-router.sh` — pré-classifica mensagens antes do Claude processar
- ✅ `attachment-handler.sh` — extrai PDF e transcreve áudio-arquivo automaticamente
- ✅ `pdftotext` (poppler-utils) instalado

**Pendente (dream-actions.md):**
- ❌ Cron financeiro D-3/D-0 — alerta proativo de contas vencendo
- ❌ Dream → GSD pipeline — dream cycle criar ações GSD automaticamente
- ❌ PreSessionStart hook melhorado — load-context BQ mais eficiente
- ❌ Voice TTS response — responder em áudio quando input for voz

---

## Requirements

### Validated (já implementado)

- ✓ Roteamento automático de mensagens por keywords (skill-router)
- ✓ Transcrição automática de áudios via Whisper (attachment-handler)
- ✓ Extração de texto de PDF via pdftotext (attachment-handler)
- ✓ BQ RAG logging de mensagens Telegram (log-incoming-telegram)
- ✓ Injeção de contexto BQ no SessionStart (bq-session-context)
- ✓ Dream cycle 3am + delivery 8am

### Active

- [ ] Alerta financeiro proativo D-3/D-0 (cron parseia contas.md)
- [ ] Dream → GSD: detecção automática de projetos e criação de fases
- [ ] Voice input → voice output (TTS automático quando input for voz)
- [ ] Reconciliação de estado financeiro pelo dream cycle (ler BQ antes de reportar)

### Out of Scope

- Interface web / dashboard de controle — Telegram é suficiente
- Multi-usuário — sistema pessoal do Samyr
- Migração de SQLite — BigQuery já implementado e funciona

---

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Hooks em UserPromptSubmit | Sem API key externa, processamento em shell puro antes do Claude | ✅ Funciona |
| Whisper local | Privacidade, sem custo de API | ✅ Ativo |
| Dream cycle 3am | Análise noturna sem interferir no uso diurno | ✅ Ativo |

---

## Evolution

Este documento evolui a cada fase concluída.

---
*Last updated: 2026-04-22 após inicialização*
