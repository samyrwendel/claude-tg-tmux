# Requirements: Mainbot Infrastructure

**Project:** clawd / @mainagentebot  
**Version:** v1  
**Last updated:** 2026-04-22

---

## v1 Requirements

### Roteamento e Classificação

- [x] **ROUTE-01**: Mensagens Telegram classificadas por keywords antes do Claude processar (skill-router)
- [x] **ROUTE-02**: Roteamento para devbot, execbot, degenbot, promise ou direct
- [x] **ROUTE-03**: Override para skill management (instala skill, remove skill) → direct

### Input Multimodal

- [x] **INPUT-01**: Arquivos de áudio enviados como documento → transcrição automática via Whisper
- [x] **INPUT-02**: PDFs enviados como documento → extração de texto via pdftotext
- [ ] **INPUT-03**: Voice input (voz) → resposta automática em voz (TTS via ElevenLabs)

### Financeiro

- [ ] **FIN-01**: Cron D-3 e D-0 parseia contas.md e envia alerta Telegram com contas vencendo
- [ ] **FIN-02**: Dream cycle lê BQ para reconciliar estado antes de reportar pendências

### Dream → Ação

- [ ] **DREAM-01**: Dream cycle detecta projetos identificados e cria fases GSD automaticamente
- [ ] **DREAM-02**: Ações do dream-actions.md são executadas automaticamente no ciclo seguinte

---

## v2 (deferred)

- Skill router com modelo externo (Gemini Flash) quando API key disponível
- Dashboard de visualização de ações pendentes do dream
- Auto-summarização de PDFs longos antes de injetar no contexto

---

## Out of Scope

- Interface web — Telegram é suficiente
- Multi-usuário — sistema pessoal
- Migration de BQ schema — estrutura atual funciona

---

## Traceability

| REQ-ID | Phase | Status |
|--------|-------|--------|
| ROUTE-01 | Fase 0 (done) | ✅ |
| ROUTE-02 | Fase 0 (done) | ✅ |
| ROUTE-03 | Fase 0 (done) | ✅ |
| INPUT-01 | Fase 0 (done) | ✅ |
| INPUT-02 | Fase 0 (done) | ✅ |
| INPUT-03 | Fase 1 | ⏳ |
| FIN-01 | Fase 1 | ⏳ |
| FIN-02 | Fase 2 | ⏳ |
| DREAM-01 | Fase 2 | ⏳ |
| DREAM-02 | Fase 2 | ⏳ |
