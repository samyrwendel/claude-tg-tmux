---
name: elevenlabs-auth
description: Autenticação e recuperação do ElevenLabs TTS. Use quando o TTS falhar com erro 401/403, key inválida, voz não encontrada, ou quando precisar trocar a API key/voz ativa. Contém scripts de health-check, listagem de vozes e teste de áudio.
---

# ElevenLabs Auth & Recovery

## Quando esta skill dispara

- Erro TTS com status 401 ou 403
- API key inválida ou expirada
- Quota de caracteres esgotada
- Voz não encontrada (voice_id inválido)
- Necessidade de trocar API key ou voz ativa

## Diagnóstico

Os scripts estão em `{baseDir}/scripts/`. Em claude-tg-tmux resolvem para `~/.claude/skills/elevenlabs-auth/scripts/` via symlink.

### 1. Health Check

```bash
{baseDir}/scripts/health-check.sh <API_KEY>
```

Retorna:
- `OK` + quota restante de caracteres
- `FAIL` + motivo (key inválida, erro de rede, etc.)

### 2. Listar vozes disponíveis

```bash
{baseDir}/scripts/list-voices.sh <API_KEY>
```

Output: `voice_id | nome` por linha.

### 3. Testar uma voz específica

```bash
{baseDir}/scripts/test-voice.sh <API_KEY> <VOICE_ID> "texto de teste" /tmp/test.mp3
```

Gera um arquivo MP3 de teste com a voz selecionada.

## Recuperação da API Key

### Fontes possíveis

1. Variável de ambiente `ELEVENLABS_API_KEY`
2. Bitwarden (se `bw` CLI disponível):
   ```bash
   export BW_SESSION=$(bw unlock --raw)   # se ainda não desbloqueado
   bw get password "ELEVENLABS_API_KEY"
   ```
3. Conta no painel ElevenLabs (https://elevenlabs.io) → API Keys

### Usar a key

Injete a key no app/gateway que consome o TTS. Duas formas comuns:

**a) Via env var:**
```bash
export ELEVENLABS_API_KEY="<nova_api_key>"
```

**b) Editar config do host (exemplo OpenClaw):**
```yaml
messages:
  tts:
    elevenlabs:
      apiKey: "<NOVA_API_KEY>"
      voiceId: "<voice_id>"
```

Campos relevantes:
- `apiKey` — API key da conta ElevenLabs
- `voiceId` — ID da voz ativa (obtido via `list-voices.sh`)

### Reiniciar o host

Após alterar config, reinicie o processo que usa o TTS. Exemplo OpenClaw:
```bash
openclaw gateway restart
```

Outros hosts: `pm2 restart <app>`, `systemctl restart <service>`, etc.

## Fluxo completo de recuperação

1. Rodar `health-check.sh` com a key atual
2. Se FAIL → buscar key nova (env var / Bitwarden / painel)
3. Rodar health-check com a nova key
4. Se OK → atualizar config do host
5. Reiniciar host
6. Testar TTS para confirmar
