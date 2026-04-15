# Instalação — Novo Servidor

Guia completo para instalar o claude-tg-tmux em um servidor limpo.

---

## Pré-requisitos

```bash
# Obrigatórios
sudo apt install tmux jq python3 ffmpeg

# Node.js (via nvm recomendado)
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.0/install.sh | bash
nvm install --lts

# Claude CLI
npm install -g @anthropic-ai/claude-code

# bun (para o plugin Telegram)
curl -fsSL https://bun.sh/install | bash

# RTK (opcional — savings de tokens)
cargo install rtk  # requer Rust
```

---

## Passos

### 1. Clonar o repositório

```bash
git clone https://github.com/samyrwendel/claude-tg-tmux.git ~/claude-tg-tmux
cd ~/claude-tg-tmux
```

### 2. Configurar `.env`

```bash
cp .env.example .env
nano .env
```

Preencher obrigatoriamente:
```
TELEGRAM_BOT_TOKEN=   # token do @BotFather
ALLOWED_USER_IDS=     # IDs de usuários permitidos (ex: 30289486)
ADMIN_CHAT_ID=        # chat_id para notificações de sistema
```

Opcionais para TTS:
```
ELEVENLABS_API_KEY=
ELEVENLABS_VOICE_ID=
```

### 3. Instalar

```bash
bash install.sh
```

O installer faz automaticamente:
- Verifica dependências
- Copia hooks para `~/.claude/hooks/`
- Configura plugin Telegram em `~/.claude/channels/telegram/.env`
- Cria `access.json` com usuários permitidos
- Registra comandos no BotFather via `setMyCommands`
- Copia `systemd/*.service` e `*.timer` para `~/.config/systemd/user/`
- Habilita e inicia `mainbot.service`, `agents-boot.service`, `tmux-doctor.timer`
- Instala `tmux-doctor.sh` em `~/.local/bin/`
- Copia skills para `~/.claude/skills/`
- Configura bus (`bus-setup.sh`)

### 4. Instalar o plugin Telegram

```bash
claude mcp install @claude-plugins-official/telegram
```

### 5. Iniciar o mainbot

O `mainbot.service` deve ter sido iniciado pelo installer. Verificar:

```bash
systemctl --user status mainbot.service
tmux attach -t mainbot
```

### 6. Iniciar sub-agentes

```bash
bash ~/claude-tg-tmux/scripts/start-all-agents.sh
```

Ou aguardar o reboot (agents-boot.service faz isso automaticamente).

---

## Verificação pós-instalação

```bash
# Sessões tmux
tmux list-sessions

# Enviar /stat no Telegram → deve mostrar status de todos os agentes

# Logs
journalctl --user -u mainbot.service -f
cat /tmp/tmux-doctor.log
cat /tmp/cronbot-monitor.log
```

---

## Estrutura criada após instalação

```
~/.claude/
  hooks/              ← hooks ativos (copiados de claude-tg-tmux/hooks/)
  channels/telegram/
    .env              ← TELEGRAM_BOT_TOKEN
    access.json       ← usuários permitidos
  agents/
    mainbot/          ← config Claude CLI mainbot
    devbot/           ← config + protocolo bus
    execbot/
    cronbot/
    degenbot/
    spawnbot/
  bus/
    tasks/            ← tasks do barramento multi-agent
    status/
    promises/
    agents.registry   ← agentes spawnados dinamicamente
    watchdog.registry ← agentes monitorados pelo watchdog

~/.config/systemd/user/
  mainbot.service
  mainbot-failure-notify.service
  agents-boot.service
  tmux-doctor.service
  tmux-doctor.timer

~/.local/bin/
  tmux-doctor.sh

/home/clawd/
  mainbot-dev/        ← workspace devbot
  mainbot-exec/       ← workspace execbot
  mainbot-cron/       ← workspace cronbot
  mainbot-degen/      ← workspace degenbot
  mainbot-spawn/      ← workspace spawnbot
```

---

## Tokens e segurança

- `TELEGRAM_BOT_TOKEN` vive em `~/.claude/channels/telegram/.env` (não no repo)
- `.env` do projeto está em `.gitignore` — nunca commitar
- Permissões recomendadas: `chmod 600 ~/claude-tg-tmux/.env`
- `ALLOWED_USER_IDS` restringe quem pode interagir com o bot
- Comandos sensíveis (`/setkey`, `/listkeys`) verificam `SAMYR_ID` hardcoded no hook

---

## Atualizar

```bash
cd ~/claude-tg-tmux
git pull origin master
bash install.sh  # reinstala hooks e systemd
```
