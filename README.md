# claude-tg-tmux

Claude Code CLI rodando em sessão tmux persistente, integrado ao Telegram via plugin oficial. Inclui watchdog automático, sub-agentes, gateway WebSocket para Windows (ClaudeNode), e suporte a TTS/STT.

## Stack

- **Claude Code CLI** — agente principal (mainbot)
- **Plugin Telegram** — `claude-plugins-official`
- **tmux** — sessão persistente
- **systemd** — gestão de processos + reinício automático
- **claude-watchdog** — mantém mainbot vivo e com plugin:telegram carregado
- **ClaudeNode** — agente Windows conectado via WebSocket
- **ElevenLabs** — TTS (opcional) — acompanha skill `elevenlabs-auth` pra diagnóstico e recuperação
- **Whisper** — STT para áudios recebidos (opcional)
- **BigQuery** — logging de conversas (opcional)

## Funcionalidades

| Feature | Descrição |
|---------|-----------|
| Typing indicator | "Digitando..." ou "Gravando áudio..." durante processamento |
| TTS + texto | Responde com áudio ElevenLabs + legenda |
| STT | Transcreve áudios recebidos via Whisper |
| BQ logging | Loga incoming e outgoing no BigQuery |
| Alertas de falha | Notificação Telegram se o serviço cair |
| Auto-restart | Watchdog reinicia mainbot se cair ou perder o plugin |
| Sub-agentes | devbot, execbot, cronbot, degenbot, spawnbot via tmux |
| ClaudeNode | Agente Windows com acesso a câmera, tela, browser e arquivos |

## Skills incluídas

O `install.sh` cria symlinks de todas as skills em `skills/` → `~/.claude/skills/`. Elas ficam disponíveis em qualquer sessão Claude Code rodando no host.

**Skill em destaque — `elevenlabs-auth`** ⭐
Skill obrigatória pro TTS. Diagnostica erro 401/403, troca API key, lista vozes, testa áudio. Dispara automaticamente quando o TTS falha. Scripts em [`skills/elevenlabs-auth/scripts/`](skills/elevenlabs-auth/scripts/):
- `health-check.sh` — valida API key
- `list-voices.sh` — lista voice_ids da conta
- `test-voice.sh` — gera MP3 de teste

Outras skills públicas: `ai-council` `bigquery-rag` `bitwarden` `browse` `dex-chart` `frontend-builder` `goplus` `ingest-youtube` `instagram-transcribe` `investigate` `krystal` `lp-monitor` `megamente` `meta-ads` `pair-agent` `polymarket` `pools` `review` `ship` `speech` `trading` `transcribe` `video-analyze` `youtube-brain-clone`.

Skills pessoais opcionais ficam em `skills-private/` — instala só com `bash install.sh --with-private`.

## Instalação rápida (servidor Linux)

```bash
git clone https://github.com/samyrwendel/claude-tg-tmux ~/claude-tg-tmux
cd ~/claude-tg-tmux

# 1. Gera .env na primeira execução
bash install.sh

# 2. Preencha as variáveis obrigatórias
nano .env

# 3. Instala tudo
bash install.sh
```

## Variáveis (.env)

| Variável | Obrigatória | Descrição |
|----------|-------------|-----------|
| `TELEGRAM_BOT_TOKEN` | ✅ | Token do bot (@BotFather) |
| `ALLOWED_USER_IDS` | ✅ | IDs autorizados (ex: `30289486,99887766`) |
| `ADMIN_CHAT_ID` | — | Chat para alertas (padrão: primeiro da lista) |
| `SESSION_NAME` | — | Nome da sessão tmux (padrão: `mainbot`) |
| `WORKSPACE` | — | Diretório de trabalho do Claude (padrão: `$HOME`) |
| `ELEVENLABS_API_KEY` | — | Chave ElevenLabs para TTS |
| `ELEVENLABS_VOICE_ID` | — | ID da voz ElevenLabs |
| `TTS_ENABLED` | — | `true`/`false` (padrão: `true`) |
| `OPENAI_API_KEY` | — | Chave OpenAI para STT via Whisper |
| `BQ_ENABLED` | — | `true`/`false` (padrão: `false`) |
| `GOOGLE_APPLICATION_CREDENTIALS` | — | Path para service-account.json do BigQuery |
| `TRAY_PORT` | — | Porta do gateway ClaudeNode (padrão: `18791`) |
| `TRAY_PASSWORD` | — | Senha do gateway ClaudeNode |
| `CLAUDE_BIN` | — | Path do binário claude (autodetecta se vazio) |
| `CLAUDE_CHANNEL` | — | Canal do plugin (padrão: `plugin:telegram@claude-plugins-official`) |
| `AGENTS_DIR` | — | Diretório de agents do mainbot (padrão: `~/.claude/agents/mainbot`) |

## Instalação Windows — ClaudeNode

O ClaudeNode conecta o PC Windows ao servidor Linux via WebSocket, dando ao mainbot acesso a câmera, tela, browser e arquivos do Windows.

```
tray/
└── INSTALAR.bat    ← execute este no Windows
```

O instalador pede host (IP do servidor), porta, senha e nome do PC, gera `config.json` e inicia o agente. Para iniciar sem terminal: use `start.vbs`.

## Sub-agentes

```bash
# Inicia todos os sub-agentes
bash scripts/start-all-agents.sh

# Monitora e reinicia automaticamente
bash scripts/agents-watchdog.sh
```

| Agente | Modelo | Papel |
|--------|--------|-------|
| mainbot | Sonnet 4.6 | Orquestrador — recebe mensagens do Telegram |
| devbot | Opus 4.6 | Código, deploy, SSH |
| execbot | Sonnet 4.6 | Tasks rápidas, busca, API |
| cronbot | Sonnet 4.6 | Monitor shell — tasks, promessas |
| degenbot | Opus 4.6 | Crypto, DeFi |
| spawnbot | Sonnet 4.6 | Sub-tarefas paralelas |

## Comandos úteis

```bash
# Ver sessão mainbot
tmux attach -t mainbot

# Status dos serviços
systemctl --user status mainbot claude-watchdog

# Logs em tempo real
journalctl --user -u mainbot -f
journalctl --user -u claude-watchdog -f
tail -f /tmp/claude-watchdog.log

# Reiniciar manualmente
systemctl --user restart mainbot
systemctl --user restart claude-watchdog

# Sub-agentes
tmux attach -t devbot
tmux attach -t execbot
```

## Estrutura

```
claude-tg-tmux/
├── install.sh                      # Installer principal
├── launcher.sh                     # Inicia Claude no tmux
├── notify-failure.sh               # Alerta Telegram de falha
├── .env.example                    # Template de variáveis
├── skills/                         # Skills públicas (symlinkadas p/ ~/.claude/skills)
│   ├── elevenlabs-auth/            # ⭐ TTS: health, vozes, recuperação
│   ├── bigquery-rag/               # Memória de conversas via VECTOR_SEARCH
│   ├── polymarket/ krystal/ ...    # Crypto/DeFi
│   └── ...
├── skills-private/                 # Skills pessoais (opt-in via --with-private)
├── hooks/                          # Hooks do Claude Code
│   ├── start-typing.sh
│   ├── stop-typing.sh
│   ├── send-voice.sh
│   ├── tts-on-reply.sh
│   ├── log-incoming-telegram.sh
│   └── log-telegram-reply.sh
├── scripts/                        # Scripts operacionais
│   ├── claude-watchdog.sh          # Watchdog do mainbot
│   ├── start-all-agents.sh         # Sobe todos os sub-agentes
│   ├── agents-watchdog.sh          # Monitora sub-agentes
│   ├── tray-gateway.sh             # Inicia gateway ClaudeNode
│   ├── tray.sh                     # CLI wrapper para o gateway
│   └── ...launchers dos agentes
├── systemd/                        # Serviços systemd de usuário
│   ├── mainbot.service
│   ├── claude-watchdog.service
│   ├── agents-boot.service
│   ├── tmux-doctor.service
│   ├── tmux-doctor.timer
│   └── mainbot-failure-notify.service
├── tray/                           # ClaudeNode — agente Windows
│   ├── INSTALAR.bat                # Instalador interativo Windows
│   ├── INICIAR.bat                 # Inicia o agente
│   ├── start.vbs                   # Inicia sem janela de terminal
│   ├── index.js                    # Cliente Windows (systray)
│   ├── config.example.json         # Template de config
│   └── gateway/                    # Servidor WebSocket (Linux)
│       └── server.js
└── telegram/
    └── settings.json.template      # Hooks do Claude Code
```
