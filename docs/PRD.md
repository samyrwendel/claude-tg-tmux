# claude-tg-tmux — Product Requirements Document

**Versão:** 1.0  
**Data:** 2026-04-13  
**Owner:** Samyr Wendel Corrêa de Almeida  
**Status:** Living document — atualizar a cada ciclo de desenvolvimento

---

## 1. Visão Geral

**claude-tg-tmux** é um sistema de orquestração multi-agente que expõe o Claude Code como assistente pessoal via Telegram. O design central é: o usuário tem um único ponto de contato (mainbot), que classifica automaticamente cada demanda e delega para agentes especializados rodando em sessões tmux isoladas.

**Princípio fundador:** mainbot nunca bloqueia. Está sempre disponível para o Samyr enquanto trabalho pesado corre em paralelo.

---

## 2. Contexto e Motivação

### Problema

Antes deste sistema, o Samyr interagia com um único Claude via Telegram (nanobot). Isso criava dois problemas:

1. **Bloqueio:** tarefas longas (código, deploy) travavam a conversa inteira
2. **Especialização zero:** mesmo modelo, mesmo contexto para tudo

### Solução

Sistema de múltiplos agentes Claude especializados, coordenados por um barramento de tarefas baseado em arquivos, com o mainbot como único ponto de contato com o Samyr.

---

## 3. Arquitetura Atual

### 3.1 Stack de Agentes

| Agente | Sessão tmux | Modelo | Papel |
|--------|-------------|--------|-------|
| mainbot | `mainbot` | Sonnet 4.6 | Orquestrador — único contato com Samyr via Telegram |
| devbot | `devbot` | Opus 4.6 | Código, refactor, deploy, SSH, scripts |
| execbot | `execbot` | Sonnet 4.6 | Tasks rápidas: busca, leitura, API calls |
| cronbot | `cronbot` | shell puro | Monitor do bus — sem custo LLM |
| degenbot | `degenbot` | Opus 4.6 | Crypto, DeFi, Polymarket (agente permanente) |
| spawnbots | `<nome>` | configurável | Agentes especializados criados sob demanda |

### 3.2 Barramento de Tarefas (Bus)

```
~/.claude/bus/
├── tasks/          ← YYYYMMDD-NNN.task (texto estruturado)
├── status/         ← YYYYMMDD-NNN.status (DONE | FAILED)
├── promises/       ← arquivos de promessas com prazo
└── agents.registry ← agentes dinâmicos (pipe-separated)
```

**Fluxo:**

```
Samyr → Telegram → mainbot → classifica
                               ↓
                        bus-inject.sh → cria .task → injeta via tmux
                               ↓
                        agente recebe, executa
                               ↓
                        bus-worker.sh done → cria .status
                               ↓
                        cronbot-monitor → detecta → injeta em mainbot
                               ↓
                        mainbot entrega resultado limpo ao Samyr
```

### 3.3 Infraestrutura de Suporte

| Componente | Tipo | Função |
|-----------|------|--------|
| `claude-watchdog.sh` | shell daemon | Resolve prompts interativos que bloqueiam o mainbot |
| `typing-daemon.sh` | systemd service | Mantém "Digitando..." no Telegram durante processamento |
| `telegram-spinner.sh` | hook | Anima emoji de progresso (substitui mensagem interim) |
| `dream-cycle.sh` | hook cron | Reflexão noturna: consolida memória, gera insights |
| `dream-delivery.sh` | hook cron | Entrega do dream report matinal ao Samyr |
| Plugin Telegram | MCP server (bun) | Bridge entre Telegram Bot API e Claude Code |
| BigQuery RAG | Node.js | Logging de conversas + busca semântica de contexto |

### 3.4 Systemd Services Ativos

| Service | Tipo | Função |
|---------|------|--------|
| `claude-cli.service` | oneshot | Inicia watchdog + sessão mainbot |
| `mainbot.service` | simple | Health monitor do mainbot (restart on failure) |
| `agents-boot.service` | oneshot | Sobe devbot, execbot, cronbot no boot |
| `claude-typing-daemon.service` | simple | Daemon de typing indicator |

---

## 4. Estado Atual — Funcionalidades

### ✅ Funcionando

- Orquestração mainbot via Telegram
- Bus de tarefas (inject → lock → done/failed → cleanup)
- cronbot-monitor detectando tasks travadas e sessões mortas
- Auto-restart de agentes mortos (via cronbot + launcher scripts)
- Boot recovery via `agents-boot.service`
- Typing indicator animado
- TTS com fallback para texto (ElevenLabs)
- Permissões em bypass (sem prompts de segurança para agentes)
- Agentes com identidade isolada via `--add-dir`
- Dream cycle noturno com entrega matinal
- Promise tracking com alertas de prazo
- BigQuery logging para contexto infinito

### 🔴 Problemas Críticos

**1. Credenciais em plaintext nos hooks**
- `~/.claude/hooks/send-voice.sh:12` — ElevenLabs API key hardcoded
- `~/.claude/hooks/telegram-spinner.sh:5` — Telegram bot token hardcoded
- **Fix:** ler sempre de `~/.claude/channels/telegram/.env` ou variável de ambiente

**2. Service com script inexistente**
- `claude-tg-daemon.service` aponta para `/home/clawd/scripts/claude-tg-daemon.sh` que não existe
- **Fix:** criar o script ou remover o service

**3. Bug de quoting no tmux new-session**
- Launchers passavam o comando como string única para `tmux new-session`, causando falha silenciosa no carregamento de flags (`--dangerously-skip-permissions`, `--add-dir`)
- **Status:** corrigido em devbot-launcher.sh, execbot-launcher.sh, spawnbot.sh, claude-watchdog.sh durante sessão de 2026-04-13

### 🟠 Problemas Altos

**4. Dois watchdogs concorrentes**
- `claude-watchdog.service` (systemd) + `start-claude-tmux.sh` (nohup) podem rodar simultaneamente
- **Fix:** unificar sob um único service; remover `start-claude-tmux.sh` ou torná-lo apenas um wrapper

**5. Sem tratamento de throttling no Telegram**
- `telegram-spinner.sh` faz 1 request/1.5s por até 2min (80 requests por sessão longa)
- Sem retry com backoff em caso de 429
- **Fix:** adicionar sleep exponencial em caso de erro de rate limit

**6. Race condition no agents.registry**
- `cronbot-monitor.sh` e `spawnbot.sh` leem/escrevem `agents.registry` sem lock
- **Fix:** usar `flock` no acesso ao arquivo

**7. Tasks travadas sem fallback**
- Se agente morre durante execução (lock existe, sem status), cronbot alerta após 5min mas não age
- **Fix:** cronbot deve marcar FAILED após timeout e notificar mainbot

### 🟡 Problemas Médios

**8. Sem rotação de logs**
- `/tmp/cronbot-monitor.log` cresce indefinidamente
- **Fix:** adicionar rotação por tamanho (já existe em watchdog, replicar)

**9. Cleanup de /tmp incompleto**
- Arquivos TTS (`.ogg`, `.mp3`) não são removidos em caso de falha
- **Fix:** trap EXIT nos hooks de TTS

**10. Circuit breaker ausente para ElevenLabs**
- Se API offline, cada reply tenta TTS e espera timeout
- **Fix:** flag `/tmp/tts-disabled` com auto-reset após N minutos

---

## 5. Roadmap de Desenvolvimento

### Fase 1 — Hardening (prioridade: agora)

**Objetivo:** tornar o sistema seguro e estável para uso diário sem supervisão.

| Item | Esforço | Impacto |
|------|---------|---------|
| Mover credenciais para .env (ElevenLabs + Telegram token) | S | 🔴 Crítico |
| Remover/criar `claude-tg-daemon.sh` | S | 🔴 Crítico |
| Unificar watchdog em único service | M | 🟠 Alto |
| Adicionar flock em agents.registry | S | 🟠 Alto |
| FAILED automático em tasks com lock expirado | M | 🟠 Alto |
| Rotação de log no cronbot-monitor | S | 🟡 Médio |
| Cleanup de /tmp em hooks de TTS | S | 🟡 Médio |

### Fase 2 — RPC para Subagentes

**Objetivo:** substituir `tmux send-keys` por comunicação estruturada com ACK.

**Motivação:** o bus atual é one-way — mainbot injeta e "torce". Não sabe se o agente recebeu, entendeu, ou está travado até o cronbot avisar após 5min.

**Design:**

```
bus-rpc.py (servidor por agente, stdin/stdout JSON-RPC)
  ← bus-client.sh (substitui bus-inject.sh)
  → resposta: {accepted: true, task_id: "...", eta: null}
```

Mantém compatibilidade com `.task`/`.status` existentes.

**Entregáveis:**
- `bus-rpc.py` — servidor leve JSON-RPC por agente
- `bus-client.sh` — cliente com ACK e retry
- Integração com cronbot (monitorar via RPC ao invés de polling)

### Fase 3 — Migrador OpenClaw → claude-tg-tmux

**Objetivo:** script de migração para usuários saindo do OpenClaw.

**O que migra:**

| Origem (OpenClaw) | Destino (claude-tg-tmux) |
|------------------|--------------------------|
| `SOUL.md` | `~/.claude/CLAUDE.md` (merge com seções do bus) |
| `USER.md` | `~/.claude/projects/-home-clawd/memory/user_*.md` |
| `MEMORY.md` | `~/.claude/projects/-home-clawd/memory/` |
| `TEAM.md` + `soul-*.md` | launchers + CLAUDE.md por agente |
| `.openclaw/openclaw.json` | `.env` (bot token, model, workspace) |

**Entregáveis:**
- `migrate-openclaw.sh` com `--dry-run` por padrão, `--apply` para executar
- Validação pós-migração

### Fase 4 — User Modeling (Honcho-style)

**Objetivo:** fechar o loop do dream cycle para modelagem do Samyr.

**Design:**
- Dream cycle já coleta comportamento, padrões, preferências
- Adicionar fase 7 ao prompt do dream: atualizar `USER.md` com perfil refinado
- Seções: estilo de comunicação, horários ativos, projetos prioritários, decisões recorrentes

**Entregáveis:**
- Seção adicional no `dream-cycle.sh` prompt
- Schema estruturado para `USER.md`
- Hook que carrega `USER.md` no contexto de sessão

---

## 6. Decisões de Design

### 6.1 Por que arquivos ao invés de Redis/SQLite para o bus?

- Zero dependências externas
- Debuggável com `cat`, `ls`, `tail`
- Cronbot pode monitorar via `inotify` ou polling sem biblioteca
- Compatível com qualquer agente shell

### 6.2 Por que tmux ao invés de API direta?

- Claude Code foi projetado para terminal interativo
- tmux dá PTY real, necessário para o Claude funcionar corretamente
- Permite debug visual (`tmux attach -t devbot`)
- Compatível com o plugin Telegram sem modificações

### 6.3 Por que cronbot é shell puro (sem LLM)?

- Monitor roda a cada 60s — LLM seria custo constante
- Lógica é determinística: checar arquivo, injetar string
- Resposta mais rápida e previsível
- Falha silenciosa menos catastrófica

### 6.4 Por que Sonnet para mainbot e Opus para devbot/degenbot?

- mainbot faz classificação e roteamento — tarefa de orquestração, não de raciocínio profundo
- devbot executa código complexo, refactoring, debugging — precisa de capacidade máxima
- degenbot analisa DeFi, estratégias de pool — domínio técnico complexo
- execbot faz busca rápida e API calls — Sonnet suficiente

---

## 7. Configuração e Deploy

### Requisitos

```
claude CLI >= 2.1.100
tmux >= 3.0
bun (para plugin Telegram)
jq, python3, curl
ffmpeg (opcional, para TTS)
```

### Instalação

```bash
git clone <repo> ~/claude-tg-tmux
cd ~/claude-tg-tmux
cp .env.example .env
# editar .env com TELEGRAM_BOT_TOKEN, ALLOWED_USER_IDS, ELEVENLABS_API_KEY
bash install.sh
```

### Variáveis de Ambiente (.env)

| Variável | Obrigatório | Descrição |
|----------|------------|-----------|
| `TELEGRAM_BOT_TOKEN` | ✅ | Token do bot Telegram |
| `ALLOWED_USER_IDS` | ✅ | IDs autorizados (comma-separated) |
| `ADMIN_CHAT_ID` | ✅ | Chat para notificações de falha |
| `ELEVENLABS_API_KEY` | ❌ | TTS (desabilitado se ausente) |
| `ELEVENLABS_VOICE_ID` | ❌ | ID de voz ElevenLabs |
| `SESSION_NAME` | ❌ | Nome da sessão tmux (default: mainbot) |
| `BQ_ENABLED` | ❌ | Habilitar BigQuery logging |
| `BQ_LOG_SCRIPT` | ❌ | Path para write-message.js |

---

## 8. Operação

### Comandos Principais

```bash
# Status geral
bash ~/claude-tg-tmux/scripts/spawnbot.sh list

# Injetar task manualmente
bash ~/claude-tg-tmux/scripts/bus-inject.sh dev "Refatorar auth.js" "/home/clawd/clawd/auth.js"

# Criar promise
bash ~/claude-tg-tmux/scripts/bus-promise.sh create "deploy-prod" "2026-04-20 18:00" "Deploy versão 2.0"

# Ver tasks ativas
ls ~/.claude/bus/tasks/

# Logs cronbot
tail -f /tmp/cronbot-monitor.log

# Restartar mainbot
systemctl --user restart claude-cli.service

# Restartar todos os agentes
systemctl --user restart agents-boot.service
```

### Comandos Telegram

| Comando | Função |
|---------|--------|
| `/help` | Lista comandos |
| `/syscheck` | Status do sistema |
| `/model` | Modelo atual |
| `/tts on\|off` | Liga/desliga voz |
| `/compact` | Compacta contexto |
| `/new` | Nova conversa |
| `/restart` | Reinicia sessão |

---

## 9. Métricas de Sucesso

| Métrica | Meta | Como medir |
|---------|------|-----------|
| Disponibilidade mainbot | >99% | systemd restart logs |
| Tempo de resposta | <5s para respostas diretas | Timestamp BQ |
| Tasks concluídas sem timeout | >95% | bus/status/ DONE vs FAILED |
| Uptime agentes especializados | >99% | cronbot restart count |
| Custo por sessão | Redução vs nanobot único | BigQuery token logs |

---

## 10. Glossário

| Termo | Definição |
|-------|-----------|
| **Bus** | Sistema de fila baseado em arquivos para comunicação entre agentes |
| **Task** | Unidade de trabalho delegada, com ID, arquivo `.task` e ciclo lock→status |
| **Promise** | Compromisso com prazo criado pelo mainbot, monitorado pelo cronbot |
| **Inject** | Enviar texto para sessão tmux via `tmux send-keys` |
| **Cronbot** | Monitor shell que opera o bus sem custo LLM |
| **Spawnbot** | Utilitário para criar agentes dinâmicos especializados |
| **Dream cycle** | Rotina LLM noturna de consolidação de memória e geração de insights |
| **Watchdog** | Processo que detecta e resolve prompts interativos que bloqueiam o Claude |
