# Multi-Agent Bus — Design Spec
> Data: 2026-04-13 | Autor: Samyr + Main | Status: APROVADO

---

## Problema

O mainbot (orquestrador) some do ar enquanto executa tarefas longas, deixando Samyr sem resposta. Não há mecanismo de delegação, monitoramento de promessas, ou fila durável entre sessões Claude.

---

## Solução

Arquitetura de 4 agentes com barramento de arquivos. Mainbot classifica e delega, nunca executa. Cronbot monitora tudo como shell script leve.

---

## 1. Agentes

| Sessão tmux | Modelo | Papel |
|-------------|--------|-------|
| `mainbot` | Sonnet 4.6 | Orquestrador — sempre disponível pro Samyr |
| `execbot` | Sonnet 4.6 | Tasks rápidas (busca, API, leitura) |
| `devbot` | Opus 4.6 | Código, debug, deploy, SSH |
| `cronbot` | Haiku 4.5 | Monitoramento puro — nunca executa tasks |

**Regra de ouro:** mainbot nunca executa nada pesado. Classifica, delega, entrega.

---

## 2. Classificação automática (mainbot)

Mainbot lê cada mensagem do Samyr e classifica sem precisar de prefixo explícito:

| Sinal na mensagem | Destino |
|------------------|---------|
| Código, refactor, bug, deploy, SSH, script | devbot |
| Preço, busca rápida, leitura de arquivo, consulta API | execbot |
| Cron, automação, monitoramento | devbot (escreve) + cronbot (registra) |
| "depois", "me avisa", "te falo", prazo explícito | promise |
| Análise simples, DeFi, Polymarket, pergunta direta | mainbot responde direto |
| Ambíguo | mainbot confirma antes de agir |

Samyr pode mencionar o agente explicitamente ("fala pro dev que...") — mainbot respeita e não reclassifica.

Confirmação visual só em caso de ambiguidade real. Fluxo normal não é interrompido.

---

## 3. Estrutura de arquivos (bus)

```
~/.claude/bus/
  tasks/
    {YYYYMMDD-NNN}.task       # task pendente (texto estruturado)
    {YYYYMMDD-NNN}.task.lock  # lock enquanto agente processa
  status/
    {YYYYMMDD-NNN}.status     # STARTED / DONE / FAILED + resultado
  promises/
    {slug}.promise            # promessa com prazo
```

### Formato de task

```
TASK_ID: 20260413-001
AGENT: dev
PRIORITY: normal
DEADLINE: -

TAREFA: Refatorar auth.js — adicionar refresh token
CONTEXTO: /home/clawd/clawd/auth.js usa JWT sem refresh token
CRITÉRIO: testes passando, sem regressão
ARQUIVOS: /home/clawd/clawd/auth.js

AO TERMINAR: escrever em ~/.claude/bus/status/20260413-001.status
```

### Formato de status (agente escreve ao concluir)

```
STATUS: DONE
RESUMO: Refresh token implementado — 3 arquivos modificados
COMMIT: abc1234
DETALHES: (opcional)
```

### Formato de promise

```
PROMISE_ID: 20260413-001
DEADLINE: 2026-04-14 18:00
CONTEXTO: Samyr pediu update do portfólio no checkin das 18h
STATUS: OPEN
```

---

## 4. Ciclo de vida de uma task

```
1. Mainbot classifica mensagem do Samyr
2. Mainbot escreve ~/.claude/bus/tasks/{id}.task
3. Mainbot injeta task no agente via: tmux send-keys -t {session} "{task}" Enter
4. Mainbot avisa Samyr: "Mandei pro dev. Te aviso quando concluir."
5. Agente lê task → cria .task.lock → atualiza status: STARTED
6. Agente conclui → escreve {id}.status com DONE/FAILED + resultado limpo
7. Cronbot detecta novo status → injeta no mainbot via tmux send-keys
8. Mainbot filtra resultado → entrega ao Samyr via Telegram
9. Mainbot faz cleanup (deleta task + lock + status)
```

---

## 5. Protocolo de resultado

Cronbot injeta no mainbot:
```
[DEVBOT] Task 20260413-001 CONCLUÍDA
Refresh token implementado — 3 arquivos modificados
Commit: abc1234
```

Mainbot entrega ao Samyr (limpo, sem narração interna):
```
Dev concluiu: refresh token no auth.js ✅ (commit abc1234)
```

---

## 6. Cronbot — monitoramento

Cronbot é um **shell script em loop** (`cronbot-monitor.sh`), não um Claude ativo. Custo zero quando tudo está ok. Só acorda o mainbot quando detecta algo.

| Check | Frequência | Ação |
|-------|-----------|------|
| Task sem update > 5min | 1min | Injeta alerta no mainbot |
| Task com status FAILED | 1min | Injeta erro + contexto no mainbot |
| Sessão tmux devbot/execbot caiu | 1min | Reinicia + avisa mainbot |
| Promises com prazo < 24h | 15min | Injeta lembrete no mainbot |
| Promises vencidas | 15min | Injeta alerta urgente no mainbot |
| Crontab — valida jobs ativos | 1h | Report de saúde ao mainbot |

Implementação: loop `while true; do sleep 60; ... done` rodando dentro da sessão tmux `cronbot`, ou como systemd service.

---

## 7. Protocolo de falha

```
Task travada > 5min:
  cronbot → mainbot: "[CRONBOT] ⚠️ devbot sem resposta (task 001, 5min)"
  mainbot decide: reinjeta task OU avisa Samyr

Sessão caiu:
  cronbot reinicia tmux automaticamente
  cronbot → mainbot: "[CRONBOT] devbot reiniciado. Reinjeta task 001?"

Falha 2x na mesma task:
  mainbot → Samyr: "Dev falhou 2x na task X: [erro]. Preciso de ajuda."
  (sem mais retry automático — escala ao humano)
```

---

## 8. Skills — global + override por agente

```
~/.claude/CLAUDE.md                 # base: identidade, BQ logging, regras globais
~/.claude/agents/
  mainbot/CLAUDE.md                 # + Telegram, GSD, dream, bus classifier
  devbot/CLAUDE.md                  # + ferramentas de código, bus worker protocol
  execbot/CLAUDE.md                 # + busca, APIs, bus worker leve
  cronbot/CLAUDE.md                 # + monitoramento, regra: NUNCA executa tasks
```

Cada agente lê o CLAUDE.md global + o seu específico ao iniciar. O launcher de cada sessão tmux passa o `--system-prompt` ou aponta pro diretório correto.

---

## 9. Componentes a implementar

1. **`~/.claude/bus/`** — criar estrutura de diretórios
2. **`bus-worker.sh`** — script que agentes usam pra ler/lock/update tasks
3. **`cronbot-monitor.sh`** — loop de monitoramento (cron ou systemd)
4. **`bus-inject.sh`** — helper que mainbot usa pra criar task + injetar no agente
5. **`~/.claude/agents/{agent}/CLAUDE.md`** — identidade e regras por agente
6. **Launchers tmux** — um script por agente com modelo correto + CLAUDE.md correto
7. **Integração no mainbot** — classifier + prompt de sistema ensinando a usar o bus

---

## 10. Fora do escopo (v1)

- Analista como revisor obrigatório (v1: devbot auto-valida)
- Paralelismo de tasks (v1: uma task por agente por vez)
- Interface web de monitoramento
- Retry automático de tasks (v1: cronbot avisa mainbot, mainbot decide)
