# claude-tg-tmux

Claude Code rodando em sessão tmux persistente, integrado ao Telegram via plugin oficial.

## Stack

- **Claude Code CLI** — agente principal
- **Plugin Telegram** — `claude-plugins-official`
- **tmux** — sessão persistente
- **systemd** — gestão do processo + reinício automático
- **ElevenLabs** — TTS (opcional)
- **Whisper** — STT para áudios recebidos (opcional)
- **BigQuery** — logging de conversas (opcional)

## Funcionalidades

| Feature | Descrição |
|---------|-----------|
| Typing indicator | "Digitando..." ou "Gravando áudio..." durante processamento |
| TTS + texto | Responde com áudio ElevenLabs + legenda de texto |
| STT | Transcreve áudios recebidos via Whisper |
| BQ logging | Loga incoming e outgoing no BigQuery |
| Alertas de falha | Notificação Telegram se o serviço cair |
| Auto-restart | systemd reinicia automaticamente (limite: 3x/10min) |

## Instalação rápida

```bash
git clone <repo> ~/claude-tg-tmux
cd ~/claude-tg-tmux

# 1. Cria e preenche o .env
bash install.sh          # Gera .env.example → .env na primeira execução
nano .env                # Preencha as variáveis

# 2. Instala tudo
bash install.sh
```

## Variáveis (.env)

| Variável | Obrigatória | Descrição |
|----------|-------------|-----------|
| `TELEGRAM_BOT_TOKEN` | ✅ | Token do bot (@BotFather) |
| `ALLOWED_USER_IDS` | ✅ | IDs autorizados (ex: `30289486,99887766`) |
| `ADMIN_CHAT_ID` | — | Chat para alertas (padrão: primeiro da lista) |
| `WORKSPACE` | — | Diretório de trabalho do Claude |
| `SESSION_NAME` | — | Nome da sessão tmux (padrão: `mainbot`) |
| `ELEVENLABS_API_KEY` | — | Chave ElevenLabs para TTS |
| `ELEVENLABS_VOICE_ID` | — | ID da voz (padrão: voz Degenerado) |
| `TTS_ENABLED` | — | `true`/`false` (padrão: `true`) |
| `BQ_ENABLED` | — | `true`/`false` (padrão: `false`) |
| `GOOGLE_APPLICATION_CREDENTIALS` | — | Path para service-account.json |
| `BQ_LOG_SCRIPT` | — | Path para `log-interaction.js` |

## Comandos úteis

```bash
# Ver sessão tmux
tmux attach -t mainbot

# Status do serviço
systemctl --user status mainbot

# Logs em tempo real
journalctl --user -u mainbot -f

# Reiniciar manualmente
systemctl --user restart mainbot

# Parar
systemctl --user stop mainbot
```

## Estrutura

```
claude-tg-tmux/
├── install.sh                  # Installer principal
├── launcher.sh                 # Inicia Claude no tmux
├── notify-failure.sh           # Alerta Telegram de falha
├── .env.example                # Template de variáveis
├── hooks/
│   ├── start-typing.sh         # Typing/record_voice indicator
│   ├── stop-typing.sh          # Para o indicator
│   ├── send-voice.sh           # Gera e envia TTS
│   ├── tts-on-reply.sh         # Hook PostToolUse → TTS
│   ├── log-incoming-telegram.sh # Hook UserPromptSubmit → BQ
│   └── log-telegram-reply.sh   # Hook PostToolUse → BQ
├── systemd/
│   ├── mainbot.service
│   └── mainbot-failure-notify.service
└── telegram/
    └── settings.json.template  # Hooks do Claude Code
```
