## Arquitetura de Bots — DEFINITIVO

### Os dois sistemas (nunca confundir)

| Sistema | Bot Telegram | Processo | Config |
|---------|-------------|----------|--------|
| **Degenerado (OpenClaw)** | @mentordegenbot | PM2 `clawdbot-gw` | `/home/clawd/.openclaw/openclaw.json` |
| **Mainbot (claude-tg-tmux)** | @mainagentebot | tmux `mainbot` | `/home/clawd/.claude/channels/telegram/.env` |

**Regra:** nunca tocar no OpenClaw/clawdbot-gw. Qualquer trabalho de bot é no mainbot.

### Fluxo de boot do mainbot

```
systemd boot
  └── claude-cli.service
        └── start-claude-tmux.sh → claude-watchdog.sh → tmux mainbot (@mainagentebot)

  └── (manual) scripts/start-all-agents.sh
        ├── devbot   (Opus 4.6)
        ├── execbot  (Sonnet 4.6)
        ├── cronbot  (monitor shell)
        ├── degenbot (Opus 4.6)
        └── spawnbot (Sonnet 4.6)

PM2 (separado — NÃO TOCAR)
  └── clawdbot-gw → @mentordegenbot (Degenerado/OpenClaw)
```

### Scripts chave

| Script | Função |
|--------|--------|
| `start-claude-tmux.sh` | Sobe mainbot via systemd |
| `scripts/start-all-agents.sh` | Sobe sub-agentes (devbot, execbot, etc) |
| `scripts/agents-watchdog.sh` | Monitora e reinicia agentes caídos |
| `scripts/mainbot-launcher.sh` | Recria sessão tmux mainbot |
| `scripts/tmux-doctor.sh` | Auto-fix trust dialog e MCP desconectado |
| `scripts/reboot-check.sh` | Verifica todos agentes após reboot |

### Tokens

- @mainagentebot: `TELEGRAM_BOT_TOKEN` em `/home/clawd/.claude/channels/telegram/.env`
- @mentordegenbot: `botToken` em `/home/clawd/.openclaw/openclaw.json` — **não expor**

### Skills instaladas

| Skill | Uso |
|-------|-----|
| `ingest-youtube` | URL YouTube → yt-dlp + Whisper → wiki local |
| `youtube-brain-clone` | Canal inteiro → NotebookLM + Gemini |
