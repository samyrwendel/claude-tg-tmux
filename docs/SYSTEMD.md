# Systemd — Serviços e Timers

Todos os serviços rodam no contexto do usuário (`systemctl --user`).

---

## Serviços

### `mainbot.service`
**Função:** Processo principal — lança `launcher.sh` que cria a sessão tmux mainbot e mantém health monitor.  
**ExecStart:** `launcher.sh` (health loop: verifica sessão a cada 60s, sai com erro se morrer → systemd reinicia)  
**Restart:** `on-failure` com `RestartSec=10`  
**OnFailure:** `mainbot-failure-notify.service`  
**StartLimitBurst:** 3 tentativas em 600s (após isso para e notifica)

### `mainbot-failure-notify.service`
**Função:** Oneshot chamado pelo `OnFailure` do `mainbot.service`. Envia notificação Telegram ao Samyr com cooldown de 600s (evita spam em crash-loop).  
**ExecStart:** `notify-failure.sh`  
**Lê:** `${TELEGRAM_BOT_TOKEN}` e `${ADMIN_CHAT_ID}` do ambiente

### `agents-boot.service`
**Função:** Oneshot que sobe todos os sub-agentes após o boot da rede.  
**ExecStart:** `start-all-agents.sh`  
**After:** `network-online.target`  
**Nota:** mainbot NÃO é iniciado aqui — é gerenciado pelo `mainbot.service`

### `tmux-doctor.service`
**Função:** Oneshot de diagnóstico. Verifica sessão mainbot: recria se não existe, aceita trust dialog, reinicia se MCP desconectou, corrige `hasTrustDialogAccepted` no `.claude.json`.  
**ExecStart:** `~/.local/bin/tmux-doctor.sh`  
**EnvironmentFile:** `~/claude-tg-tmux/.env` (opcional, prefixado com `-`)  
**Nota:** `Environment=TMUX=` garante que tmux funciona mesmo rodando de dentro de tmux

### `tmux-doctor.timer`
**Função:** Dispara `tmux-doctor.service` a cada 2 minutos.  
**OnBootSec:** 60s (aguarda boot estabilizar antes do primeiro check)  
**OnUnitActiveSec:** 2min  
**AccuracySec:** 30s

---

## Boot order completo

```
systemd
  ├── mainbot.service          (After: network-online.target)
  │     └── launcher.sh
  │           └── tmux mainbot (@mainagentebot)
  │                 └── claude-watchdog.sh (health loop interno)
  │
  ├── agents-boot.service      (After: network-online.target)
  │     └── start-all-agents.sh
  │           ├── devbot-launcher.sh
  │           ├── execbot-launcher.sh
  │           ├── cronbot-launcher.sh
  │           ├── degenbot-launcher.sh
  │           └── spawnbot-launcher.sh
  │
  └── tmux-doctor.timer        (a cada 2min)
        └── tmux-doctor.service
              └── tmux-doctor.sh
```

---

## Comandos úteis

```bash
# Status geral
systemctl --user status mainbot.service
systemctl --user status agents-boot.service
systemctl --user list-timers

# Reiniciar mainbot
systemctl --user restart mainbot.service

# Ver logs
journalctl --user -u mainbot.service -f
journalctl --user -u tmux-doctor.service --since "1h ago"

# Instalar/recarregar após mudança nos .service
systemctl --user daemon-reload
systemctl --user enable mainbot.service agents-boot.service tmux-doctor.timer
systemctl --user start tmux-doctor.timer
```

---

## Instalação (via install.sh)

O `install.sh` copia os `.service` e `.timer` de `systemd/` para `~/.config/systemd/user/`, executa `daemon-reload`, habilita e inicia os serviços automaticamente.

---

## Falhas e recuperação

| Cenário | O que acontece |
|---------|----------------|
| mainbot cai | `mainbot.service` reinicia após 10s. Após 3 falhas em 600s, para e notifica |
| trust dialog trava mainbot | `tmux-doctor.timer` detecta em até 2min e resolve |
| MCP Telegram desconecta | `tmux-doctor.sh` detecta e reinicia sessão |
| Sub-agente cai | `agents-watchdog.sh` (cron 1min) reinicia via launcher |
| Reboot | `mainbot.service` e `agents-boot.service` sobem automaticamente |
| Agente spawnado morre | `cronbot-monitor.sh` reinicia via launcher gerado pelo spawnbot |
