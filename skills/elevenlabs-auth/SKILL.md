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

### 1. Health Check

Rodar o script de health check para verificar se a key atual funciona:

```bash
~/.openclaw/skills/elevenlabs-auth/scripts/health-check.sh <API_KEY>
```

Retorna:
- `OK` + quota restante de caracteres
- `FAIL` + motivo (key inválida, erro de rede, etc.)

### 2. Listar vozes disponíveis

```bash
~/.openclaw/skills/elevenlabs-auth/scripts/list-voices.sh <API_KEY>
```

Output: `voice_id | nome` por linha.

### 3. Testar uma voz específica

```bash
~/.openclaw/skills/elevenlabs-auth/scripts/test-voice.sh <API_KEY> <VOICE_ID> "texto de teste" /tmp/test.mp3
```

Gera um arquivo MP3 de teste com a voz selecionada.

## Recuperação da API Key

### Buscar key no Bitwarden

```bash
bw get password "ELEVENLABS_API_KEY"
```

Se `BW_SESSION` não estiver setada, desbloquear primeiro:

```bash
export BW_SESSION=$(bw unlock --raw)
```

### Atualizar config do OpenClaw

Editar a config do gateway para atualizar a API key e/ou voice:

```yaml
messages:
  tts:
    elevenlabs:
      apiKey: "<NOVA_API_KEY>"
      voiceId: "30D0RicpFBZ55TdpseEa"
```

Campos relevantes:
- `messages.tts.elevenlabs.apiKey` — API key da conta ElevenLabs
- `messages.tts.elevenlabs.voiceId` — ID da voz ativa

### Voz padrão

| Nome     | Voice ID                     |
|----------|------------------------------|
| HardCopy | `30D0RicpFBZ55TdpseEa`      |

Esta é a voz atual do Degenerado.

### Reiniciar gateway

Após qualquer alteração na config, reiniciar o gateway:

```
openclaw gateway restart
```

## Fluxo completo de recuperação

1. Rodar health-check com a key atual
2. Se FAIL → buscar key no Bitwarden
3. Rodar health-check com a nova key
4. Se OK → atualizar config do OpenClaw
5. Reiniciar gateway
6. Testar TTS para confirmar
