# Scripts — Referência Completa

Mapa de todos os scripts do claude-tg-tmux, função, estado e interdependências.

---

## Bus (barramento multi-agent)

| Script | Função | Quem usa | Estado |
|--------|--------|----------|--------|
| `bus-setup.sh` | Cria estrutura `~/.claude/bus/` (tasks/, status/, promises/) | `start-all-agents.sh` no boot | ✅ ok |
| `bus-inject.sh` | Mainbot cria task e injeta no agente via tmux | mainbot | ✅ ok — suporta nativos + registry |
| `bus-worker.sh` | Agentes fazem lock/done/fail de tasks | devbot, execbot, etc | ✅ ok |
| `bus-promise.sh` | Cria, lista e resolve promessas com deadline | mainbot, cronbot | ✅ ok |

### Fluxo de uma task

```
mainbot
  └── bus-inject.sh dev "tarefa" → cria task file + lock + injeta tmux devbot
        └── devbot executa
              └── bus-worker.sh done TASK_ID "resumo"
                    └── cronbot-monitor.sh detecta → notifica mainbot
```

---

## Inicialização

| Script | Função | Quando rodar | Estado |
|--------|--------|-------------|--------|
| `start-all-agents.sh` | Sobe devbot, execbot, cronbot, degenbot, spawnbot + bus-setup | Manual ou após reboot | ✅ ok |
| `mainbot-launcher.sh` | Cria sessão tmux mainbot | systemd `claude-cli.service` | ✅ ok |
| `devbot-launcher.sh` | Cria sessão tmux devbot (Opus 4.6) + workspace mainbot-dev | `start-all-agents.sh`, watchdog | ✅ ok |
| `execbot-launcher.sh` | Cria sessão tmux execbot (Sonnet 4.6) + workspace mainbot-exec | `start-all-agents.sh`, watchdog | ✅ ok |
| `cronbot-launcher.sh` | Cria sessão tmux cronbot (shell monitor) | `start-all-agents.sh`, watchdog | ✅ ok |
| `degenbot-launcher.sh` | Cria sessão tmux degenbot (Opus 4.6) via spawnbot | `start-all-agents.sh`, watchdog | ✅ ok |
| `spawnbot-launcher.sh` | Cria sessão tmux spawnbot (Sonnet 4.6) + workspace mainbot-spawn | `start-all-agents.sh`, watchdog | ✅ ok |
| `reboot-check.sh` | Após reboot: verifica e reinicia nativos + spawnados (watchdog.registry) | systemd, manual | ✅ ok |
| `telegram-plugin-launcher.sh` | Inicia plugin telegram (detecta versão mais recente automaticamente) | manual se necessário | ✅ ok |

---

## Agentes dinâmicos (spawnbot)

| Script | Função | Estado |
|--------|--------|--------|
| `spawnbot.sh create <nome> "<esp>" [modelo] [emoji]` | Provisiona agente completo: workspace, IDENTITY.md, CLAUDE.md, launcher, watchdog.registry, bus registry, sessão tmux | ✅ ok |
| `spawnbot.sh list` | Lista nativos + spawnados com status online/offline | ✅ ok |
| `spawnbot.sh kill/fire <nome>` | Remove tudo: sessão, workspace, config dir, launcher, registries | ✅ ok |
| `{nome}-launcher.sh` (gerado) | Reinicia agente spawnado com workspace e config corretos | gerado pelo spawnbot | ✅ ok |

### O que spawnbot.sh create provisiona

```
/home/clawd/mainbot-{nome}/        ← workspace com identidade
  IDENTITY.md                      ← quem é, especialidade, limites
  CLAUDE.md                        ← protocolo operacional
  memory/                          ← memória persistente

~/.claude/agents/{nome}/           ← config dir (bus protocol)
  CLAUDE.md

scripts/{nome}-launcher.sh         ← launcher executável com recovery

~/.claude/bus/watchdog.registry    ← para restart automático
~/.claude/bus/agents.registry      ← para delegação via bus-inject
```

---

## Monitoramento

| Script | Função | Roda onde | Estado |
|--------|--------|-----------|--------|
| `agents-watchdog.sh` | Detecta agentes DOWN ou em loop, reinicia — lê watchdog.registry para spawnados | cron a cada 1 min | ✅ ok |
| `cronbot-monitor.sh` | Loop shell dentro do cronbot: monitora tasks, promises, sessões (nativos + watchdog.registry) | tmux `cronbot` | ✅ ok |
| `tmux-doctor.sh` | Auto-fix: recria mainbot se morto, aceita trust dialog, reinicia se MCP desconectou | systemd timer a cada 2 min | ✅ ok |
| `watchdog-alerts.sh` | Drena fila de alerts pendentes e injeta no mainbot | startup do mainbot (hooks/watchdog.sh) | ✅ ok |

---

## Registries

| Arquivo | Conteúdo | Quem escreve | Quem lê |
|---------|----------|-------------|---------|
| `~/.claude/bus/agents.registry` | `nome\|modelo\|workspace\|especialidade\|criado` | `spawnbot.sh create/kill` | `bus-inject.sh`, `spawnbot.sh list` |
| `~/.claude/bus/watchdog.registry` | `nome` (um por linha) | `spawnbot.sh create/kill` | `agents-watchdog.sh`, `cronbot-monitor.sh`, `reboot-check.sh` |
| `~/.claude/bus/tasks/` | Arquivos `.task` por task ID | `bus-inject.sh` | `cronbot-monitor.sh`, `bus-worker.sh` |
| `~/.claude/bus/status/` | Arquivos `.status` por task ID | `bus-worker.sh done/fail` | `cronbot-monitor.sh` |
| `~/.claude/bus/promises/` | Arquivos `.promise` por slug | `bus-promise.sh create` | `bus-promise.sh check/list`, `cronbot-monitor.sh` |

---

## Workspaces dos agentes

| Workspace | Agente | Modelo |
|-----------|--------|--------|
| `/home/clawd/mainbot-dev/` | devbot 💻 | Opus 4.6 |
| `/home/clawd/mainbot-exec/` | execbot ⚡ | Sonnet 4.6 |
| `/home/clawd/mainbot-cron/` | cronbot ⏰ | shell (sem LLM) |
| `/home/clawd/mainbot-degen/` | degenbot 🦧 | Opus 4.6 |
| `/home/clawd/mainbot-spawn/` | spawnbot 🔁 | Sonnet 4.6 |
| `/home/clawd/mainbot-{nome}/` | agente spawnado | conforme criação |

Cada workspace contém `IDENTITY.md` (alma do agente), `CLAUDE.md` (protocolo) e `memory/`.

---

## Boot order completo

```
systemd boot
  └── claude-cli.service
        └── start-claude-tmux.sh → claude-watchdog.sh → tmux mainbot

  └── (manual) start-all-agents.sh
        ├── bus-setup.sh
        ├── devbot-launcher.sh    → tmux devbot   (mainbot-dev)
        ├── execbot-launcher.sh   → tmux execbot  (mainbot-exec)
        ├── cronbot-launcher.sh   → tmux cronbot  (cronbot-monitor.sh)
        ├── degenbot-launcher.sh  → tmux degenbot (mainbot-degen)
        └── spawnbot-launcher.sh  → tmux spawnbot (mainbot-spawn)

  └── systemd timers
        ├── tmux-doctor.timer (2min) → tmux-doctor.sh
        └── cron (1min)              → agents-watchdog.sh

PM2 (SEPARADO — NÃO TOCAR)
  └── clawdbot-gw → @mentordegenbot (OpenClaw/Degenerado)
  └── bq-sync-daemon → sync BigQuery
```
