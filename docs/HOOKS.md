# Hooks — Referência Completa

Hooks são scripts em `hooks/` copiados para `~/.claude/hooks/` pelo `install.sh`.
São disparados pelo Claude Code em eventos específicos do ciclo de vida.

---

## Eventos do Claude Code

| Evento | Quando dispara |
|--------|----------------|
| `SessionStart` | Ao iniciar uma nova sessão Claude |
| `UserPromptSubmit` | Ao receber uma mensagem do usuário |
| `PreToolUse` | Antes de executar uma tool (pode bloquear/modificar) |
| `PostToolUse` | Após executar uma tool |

---

## Telegram — Entrada e Saída

| Hook | Evento | Função | Dependências |
|------|--------|--------|-------------|
| `start-typing.sh` | UserPromptSubmit | Detecta mensagem Telegram (via `chat_id`), cria `/tmp/claude-processing` e `/tmp/claude-typing-chat` para sinalizar ao typing daemon | — |
| `stop-typing.sh` | PostToolUse (reply) | Remove flags de processamento, para o spinner animado | `telegram-spinner.sh stop` |
| `telegram-status.sh` | PostToolUse | Controla o spinner: inicia na primeira tool, atualiza texto nas seguintes, para no reply/react. Ignora tools leves (Read, Glob, Grep) | `telegram-spinner.sh` |
| `telegram-spinner.sh` | (script standalone) | Spinner animado: cria mensagem Telegram com frames `⠋⠙⠹⠸` + emojis `⚙️🔧💻`, edita a cada 1.5s. Auto-kill após 120s. Usa flock para evitar race condition de starts simultâneos | Telegram Bot API |
| `telegram-commands.sh` | UserPromptSubmit | Intercepta comandos `/` do Telegram (`/stat`, `/syscheck`, `/tts`, `/compact`, `/new`, `/restart`, `/model`, `/setkey`, `/listkeys`, `/help`) e responde direto via API, bloqueando processamento pelo Claude | Telegram Bot API |
| `typing-daemon.sh` | (daemon systemd) | Envia `sendChatAction: typing` a cada 4s enquanto `/tmp/claude-processing` existir. Timeout de 5min. Roda como serviço separado, não como hook | Telegram Bot API |
| `typing-indicator.sh` | (legado) | Versão antiga do typing daemon — não usado mais | — |

### Fluxo de uma mensagem Telegram

```
Mensagem chega
  → UserPromptSubmit
      → start-typing.sh       (cria /tmp/claude-processing)
      → telegram-commands.sh  (se for /comando: responde e bloqueia)
      → log-incoming-telegram.sh (loga no BQ async)
  → Claude processa
      → PostToolUse (cada tool)
          → telegram-status.sh (controla spinner)
  → Claude faz reply
      → tts-intercept.sh (PreToolUse: intercepta, gera voz, bloqueia texto)
      → PostToolUse
          → stop-typing.sh (para spinner)
          → log-telegram-reply.sh (loga resposta no BQ async)
```

---

## TTS (Text-to-Speech)

| Hook | Evento | Função |
|------|--------|--------|
| `tts-intercept.sh` | PreToolUse (reply) | Intercepta respostas Telegram com ≥3 palavras. Se TTS ativado (`/tmp/claude-tts-disabled` não existe), gera voz + envia como caption, bloqueia texto original. Se TTS falhar, libera texto normalmente |
| `send-voice.sh` | (script auxiliar) | Gera MP3 via ElevenLabs API → converte para OGG Opus via ffmpeg → envia como `sendVoice`. Carrega `ELEVENLABS_API_KEY` e `ELEVENLABS_VOICE_ID` do `.env` |
| `tts-reply.sh` | (script auxiliar) | Gera MP3 via ElevenLabs e retorna o path do arquivo. Usado por outros scripts que precisam só do áudio |
| `tts-on-reply.sh` | PostToolUse (legado) | **Desabilitado** (`exit 0` no topo). Era a abordagem antiga: gerar voz e deletar mensagem de texto após envio |

**Toggle TTS:** `/tts off` cria `/tmp/claude-tts-disabled`, `/tts on` remove.

---

## BigQuery Logging

| Hook | Evento | Função |
|------|--------|--------|
| `log-incoming-telegram.sh` | UserPromptSubmit | Extrai `chat_id` e texto da tag `<channel>`, loga no BQ via `log-interaction.js`. Fire and forget (`&`). Também toca `/tmp/claude-last-activity` para o dream-cycle |
| `log-telegram-reply.sh` | PostToolUse (reply) | Passa o input completo para `log-interaction.js`. Fire and forget |

**Session ID format:** `tg-{chat_id}-{YYYYMMDD}`  
**Dependência externa:** `/home/clawd/clawd/bigquery-rag/log-interaction.js`

---

## Heartbeat e Atividade

| Hook | Evento | Função |
|------|--------|--------|
| `heartbeat.sh` | SessionStart | Toca `/tmp/claude-heartbeat` para monitor saber que sessão está viva. Cronbot e syscheck usam esse timestamp |

---

## Dream Cycle (Reflexão Noturna)

| Hook | Quando | Função |
|------|--------|--------|
| `dream-cycle.sh` | cron 22h (Manaus) | Processo `claude -p` isolado: consolida memória, identifica padrões, gera insights, lista ações para o dia seguinte. Salva em `memory/dream-insights.md` e `memory/dream-actions.md`. Usa flock para evitar instâncias simultâneas. Desativar: `touch /tmp/dream-cycle-disabled` |
| `dream-delivery.sh` | cron 8h (Manaus) | Entrega os insights do dream para o Samyr via Telegram API direta. Verifica se dream concluiu antes de entregar. Usa `${ADMIN_CHAT_ID:-30289486}` |
| `proactive-checkin.sh` | cron a cada 4h | Injeta prompt de checkin no mainbot via tmux. Verifica promessas, pagamentos, pesquisa proativa. Inclui ações do dream do dia. Só injeta se Claude estiver idle (não em processamento) |

**Flags de controle:**
- `/tmp/dream-cycle-disabled` — desativa dream (temporário, limpa no boot)
- `/tmp/dream-cycle-done` — flag que dream concluiu (usado por dream-delivery)
- `/tmp/dream-cycle-pid` — PID do processo isolado (evita duplicatas)

---

## Watchdog de Sessão

| Hook | Quando | Função |
|------|--------|--------|
| `watchdog.sh` / `claude-watchdog.sh` | Processo contínuo (gerenciado pelo `launcher.sh`) | Monitor ativo da sessão tmux mainbot. Detecta prompts bloqueantes e os resolve automaticamente: trust dialog, Y/n, "Press Enter", confirmações de edit/write, update prompts. Usa hash MD5 da tela para detectar travamento (screen stuck por 3+ checks = força Enter). Reinicia sessão se Claude morrer dentro do tmux. Rotação de log a cada 500 linhas |

**Padrões detectados e ações:**
| Padrão | Ação |
|--------|------|
| `1. Yes` / `Do you want to proceed` | Envia `1` + Enter |
| `❯` + `Enter to confirm` | Envia Enter |
| `(Y/n)` / `(y/N)` | Envia `Y` + Enter |
| `Press Enter` / `continue?` | Envia Enter |
| `trust this folder` / `quick safety check` | Envia `1` + Enter |
| `update available` | Envia Escape (skip) |
| `OAuth expired` | Não interfere (reauth-listener cuida) |
| Tela idêntica por 3+ checks (~90s) | Força Enter como fallback |

---

## GSD Integration (opt-in)

Ativado apenas em projetos com `.planning/config.json` contendo `"hooks": { "community": true }`.

| Hook | Evento | Função |
|------|--------|--------|
| `gsd-session-state.sh` | SessionStart | Injeta lembrete do `STATE.md` do projeto para orientação de contexto |
| `gsd-phase-boundary.sh` | PostToolUse (Write/Edit) | Detecta modificações em `.planning/` e pergunta se `STATE.md` deve ser atualizado |
| `gsd-validate-commit.sh` | PreToolUse (Bash) | Valida que `git commit -m` segue Conventional Commits. Bloqueia se não seguir. Tipos válidos: `feat, fix, docs, style, refactor, perf, test, build, ci, chore`. Máximo 72 chars no subject |

---

## RTK Integration

| Hook | Evento | Função |
|------|--------|--------|
| `rtk-rewrite.sh` | PreToolUse (Bash) | Delega reescrita de comandos para o binário `rtk rewrite`. Economiza 60-90% de tokens em operações de desenvolvimento (git, npm, etc). Requer rtk >= 0.23.0 e jq. Se rtk não estiver instalado, passa silenciosamente |

---

## Dependências externas dos hooks

| Dependência | Usado por | Obrigatório? |
|-------------|----------|-------------|
| `ffmpeg` | `send-voice.sh` (MP3 → OGG) | Para TTS |
| `jq` | `rtk-rewrite.sh` | Para RTK |
| `python3` | Maioria dos hooks (parsing JSON) | Sim |
| `bun` | Plugin Telegram | Sim |
| `rtk` >= 0.23.0 | `rtk-rewrite.sh` | Para savings de tokens |
| `/home/clawd/clawd/bigquery-rag/log-interaction.js` | `log-incoming-telegram.sh`, `log-telegram-reply.sh` | Para logging BQ |
| ElevenLabs API | `send-voice.sh`, `tts-reply.sh` | Para TTS |
| Telegram Bot API | vários | Sim |
