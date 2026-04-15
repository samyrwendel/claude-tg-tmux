#!/bin/bash
# tray.sh — interface dos agentes com o clawd-tray (PC do Samyr)
# Uso: tray.sh <comando> [args...]
#
# Comandos:
#   status                         — verifica se tray está conectado
#   screenshot                     — captura tela → retorna path do arquivo
#   notify <titulo> <mensagem>     — toast notification no PC
#   clipboard                      — lê clipboard do Windows
#   clipboard-write <texto>        — escreve no clipboard
#   shell <comando>                — executa comando shell no Windows
#   browser <json>                 — ação no browser (ex: '{"action":"navigate","url":"..."}')
#   browser-screenshot             — screenshot do browser (página atual)
#   camera-list                    — lista câmeras disponíveis
#   camera-snap [nome-camera]      — captura foto da câmera
#   ping                           — teste de conectividade

GATEWAY_URL="${TRAY_GATEWAY:-http://127.0.0.1:18792}"
TIMEOUT="${TRAY_TIMEOUT:-30}"

cmd="${1:-status}"
shift

err() { echo "[tray] ERRO: $*" >&2; exit 1; }

# Verificar se gateway está rodando
check_gateway() {
  curl -sf "${GATEWAY_URL}/status" > /dev/null 2>&1 || err "Gateway não está rodando. Execute: bash ~/claude-tg-tmux/scripts/tray-gateway.sh"
}

case "$cmd" in
  status)
    result=$(curl -sf "${GATEWAY_URL}/status" 2>/dev/null) || err "Gateway offline"
    connected=$(echo "$result" | python3 -c "import sys,json; d=json.load(sys.stdin); print('sim' if d.get('connected') else 'não')" 2>/dev/null)
    name=$(echo "$result" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('node',{}).get('nodeName','?'))" 2>/dev/null)
    echo "Tray: ${connected} | Node: ${name}"
    ;;

  screenshot|screen)
    check_gateway
    result=$(curl -sf --max-time "$TIMEOUT" -X POST "${GATEWAY_URL}/screenshot" 2>/dev/null) \
      || err "Falha ao capturar tela"
    path=$(echo "$result" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('path',''))" 2>/dev/null)
    [ -n "$path" ] && echo "$path" || echo "$result"
    ;;

  notify)
    check_gateway
    title="${1:-Clawd}"
    msg="${2:-}"
    curl -sf --max-time 10 -X POST "${GATEWAY_URL}/notify" \
      -H "Content-Type: application/json" \
      -d "{\"title\":\"${title}\",\"message\":\"${msg}\"}" > /dev/null \
      && echo "Notificação enviada" || err "Falha ao notificar"
    ;;

  clipboard|clip)
    check_gateway
    result=$(curl -sf --max-time 10 "${GATEWAY_URL}/clipboard" 2>/dev/null) \
      || err "Falha ao ler clipboard"
    echo "$result" | python3 -c "import sys,json; print(json.load(sys.stdin).get('text',''))" 2>/dev/null
    ;;

  clipboard-write|clip-write)
    check_gateway
    text="${1:-}"
    curl -sf --max-time 10 -X POST "${GATEWAY_URL}/clipboard" \
      -H "Content-Type: application/json" \
      -d "{\"text\":$(python3 -c "import json,sys; print(json.dumps(sys.argv[1]))" "$text")}" > /dev/null \
      && echo "Clipboard atualizado" || err "Falha ao escrever clipboard"
    ;;

  shell|run)
    check_gateway
    command="${1:-echo ok}"
    timeout="${2:-60000}"
    result=$(curl -sf --max-time "$((timeout/1000 + 5))" -X POST "${GATEWAY_URL}/shell" \
      -H "Content-Type: application/json" \
      -d "{\"command\":$(python3 -c "import json,sys; print(json.dumps(sys.argv[1]))" "$command"),\"timeout\":${timeout}}" 2>/dev/null) \
      || err "Falha ao executar comando"
    echo "$result" | python3 -c "
import sys,json
d=json.load(sys.stdin)
if d.get('stdout'): print(d['stdout'], end='')
if d.get('stderr'): print(d['stderr'], end='', file=sys.stderr)
sys.exit(d.get('exitCode',0))
" 2>/dev/null
    ;;

  browser)
    check_gateway
    body="${1:-{\"action\":\"status\"}}"
    curl -sf --max-time "$TIMEOUT" -X POST "${GATEWAY_URL}/browser" \
      -H "Content-Type: application/json" \
      -d "$body" 2>/dev/null || err "Falha na ação do browser"
    ;;

  browser-screenshot|bscreenshot)
    check_gateway
    result=$(curl -sf --max-time 30 -X POST "${GATEWAY_URL}/browser" \
      -H "Content-Type: application/json" \
      -d '{"action":"screenshot"}' 2>/dev/null) || err "Falha ao capturar browser"
    b64=$(echo "$result" | python3 -c "import sys,json; print(json.load(sys.stdin).get('base64',''))" 2>/dev/null)
    if [ -n "$b64" ]; then
      out="/tmp/clawd-tray/browser_${EPOCHSECONDS}.jpg"
      echo "$b64" | base64 -d > "$out"
      echo "$out"
    else
      echo "$result"
    fi
    ;;

  camera-list|cameras)
    check_gateway
    curl -sf --max-time 10 "${GATEWAY_URL}/camera/list" 2>/dev/null || err "Falha ao listar câmeras"
    ;;

  camera-snap|snap)
    check_gateway
    camera="${1:-}"
    body="{}"
    [ -n "$camera" ] && body="{\"camera\":\"${camera}\"}"
    result=$(curl -sf --max-time 30 -X POST "${GATEWAY_URL}/camera/snap" \
      -H "Content-Type: application/json" -d "$body" 2>/dev/null) || err "Falha ao capturar câmera"
    path=$(echo "$result" | python3 -c "import sys,json; print(json.load(sys.stdin).get('path',''))" 2>/dev/null)
    [ -n "$path" ] && echo "$path" || echo "$result"
    ;;

  ping)
    check_gateway
    result=$(curl -sf --max-time 5 -X POST "${GATEWAY_URL}/ping" 2>/dev/null) \
      && echo "pong" || err "Sem resposta do tray"
    ;;

  *)
    echo "Uso: tray.sh <comando> [args]"
    echo ""
    echo "Comandos:"
    echo "  status                         verifica conexão"
    echo "  screenshot                     captura tela do PC"
    echo "  notify <titulo> <msg>          toast notification"
    echo "  clipboard                      lê clipboard"
    echo "  clipboard-write <texto>        escreve no clipboard"
    echo "  shell <cmd> [timeout_ms]       executa no Windows"
    echo "  browser <json>                 ação no browser"
    echo "  browser-screenshot             screenshot do browser"
    echo "  camera-list                    lista câmeras"
    echo "  camera-snap [nome]             foto da câmera"
    echo "  ping                           teste de conectividade"
    exit 1
    ;;
esac
