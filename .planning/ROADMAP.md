# Roadmap: Mainbot Infrastructure

**Project:** clawd / @mainagentebot  
**Created:** 2026-04-22  
**Phases:** 3 (+ Fase 0 já concluída)

---

## Fase 0 — Input & Roteamento ✅ CONCLUÍDA

**Goal:** Mainbot classifica e processa inputs multimodais automaticamente.

**Requirements:** ROUTE-01, ROUTE-02, ROUTE-03, INPUT-01, INPUT-02

**Entregado:**
- skill-router.sh (UserPromptSubmit hook — keyword routing)
- attachment-handler.sh (PDF pdftotext + áudio Whisper)
- poppler-utils instalado

**Data:** 2026-04-22

---

## Fase 1 — Financeiro + Voice Response

**Goal:** Mainbot alerta proativamente sobre contas vencendo e responde em voz quando input for voz.

**Requirements:** INPUT-03, FIN-01

**Tasks:**
- [ ] Script `cron-financeiro.sh` — parseia contas.md, compara com data atual, envia Telegram se D-3 ou D-0
- [ ] Cron job: executa diariamente às 9h (Manaus)
- [ ] Voice response: quando attachment_kind=voice, após transcrever, gerar resposta em TTS e enviar como voice note

**Success criteria:**
1. Conta vencendo em 3 dias → Telegram com alerta automático sem Samyr perguntar
2. Samyr manda áudio → resposta chega como áudio de volta

---

## Fase 2 — Dream → Ação Automática

**Goal:** Dream cycle gera ações concretas e as executa no ciclo seguinte sem intervenção manual.

**Requirements:** FIN-02, DREAM-01, DREAM-02

**Tasks:**
- [ ] Dream cycle: antes de reportar, lê BQ para reconciliar estado (não reportar itens já resolvidos)
- [ ] Dream: ao identificar projeto novo, cria fase GSD automaticamente via bus-inject
- [ ] dream-actions.md: itens marcados como `[ ]` são injetados no execbot/devbot no próximo ciclo de entrega

**Success criteria:**
1. Dream de hoje gera insight sobre projeto X → amanhã GSD fase criada automaticamente
2. Contas pagas confirmadas via BQ → dream não reporta como pendente

---

## Estado Geral

| Fase | Status | Req | Meta |
|------|--------|-----|------|
| 0 | ✅ Concluída | ROUTE-01/02/03, INPUT-01/02 | Input multimodal + roteamento |
| 1 | ⏳ Pendente | INPUT-03, FIN-01 | Financeiro + voice |
| 2 | ⏳ Pendente | FIN-02, DREAM-01/02 | Dream → ação |
