# Instalação do Clawd Tray

## Lado clawd (servidor) — automático

O gateway sobe automaticamente com `start-all-agents.sh`.
Para subir manualmente:
```bash
bash ~/claude-tg-tmux/scripts/tray-gateway.sh
```

Verificar se está rodando:
```bash
curl -s http://127.0.0.1:18792/status
```

## Lado Windows (PC do Samyr)

### Pré-requisitos
1. [Node.js 18+](https://nodejs.org) instalado
2. Git (opcional — pode baixar o zip)

### Instalação

```bat
:: 1. Baixar o projeto (ou clonar)
git clone https://github.com/samyrwendel/claude-tg-tmux.git
cd claude-tg-tmux\tray

:: 2. Instalar dependências
npm install

:: 3. Instalar Chromium (Playwright)
npx playwright install chromium

:: 4. Configurar
copy config.example.json config.json
:: Editar config.json:
::   gatewayUrl: "ws://100.66.236.96:18791"
::   password: (senha configurada no .env do clawd)
::   nodeName: "PC do Samyr"
```

### Rodar

```bat
:: Com janela (debug)
node index.js

:: Sem janela (produção)
wscript start.vbs
```

### Autostart no Windows

Criar atalho para `start.vbs` na pasta:
```
%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\
```

## Configuração da senha

No clawd, editar `~/claude-tg-tmux/.env`:
```
TRAY_PASSWORD=senha_forte_aqui
```

No Windows, `config.json`:
```json
{
  "password": "senha_forte_aqui"
}
```

## Verificar conexão (via Telegram)

Mandar para o mainbot:
> "status do tray"

ou direto:
```bash
bash ~/claude-tg-tmux/scripts/tray.sh status
```
