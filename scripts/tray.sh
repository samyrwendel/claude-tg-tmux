#!/bin/bash
# tray.sh — interface dos agentes com o clawd-tray (PC do Samyr)
# Uso: tray.sh <comando> [args...]
#
# Comandos disponíveis:
#   status                               — verifica se tray está conectado
#   screenshot                           — captura tela → retorna path do arquivo
#   screen-record [segundos]             — grava tela → retorna path do vídeo
#   notify <titulo> <mensagem>           — toast notification no PC
#   clipboard                            — lê clipboard do Windows
#   clipboard-write <texto>              — escreve no clipboard
#   shell <comando> [timeout_ms]         — executa comando no Windows
#   file-read <path>                     — lê arquivo do Windows
#   file-write <path> <conteúdo>         — escreve arquivo no Windows
#   file-list <path>                     — lista diretório no Windows
#   file-exists <path>                   — verifica se arquivo existe
#   file-delete <path>                   — deleta arquivo no Windows
#   file-stat <path>                     — info do arquivo (tamanho, datas)
#   browser <json>                       — ação genérica no browser
#   browser-navigate <url>               — navega para URL
#   browser-screenshot                   — screenshot da página atual
#   browser-snapshot                     — árvore de acessibilidade da página
#   browser-content                      — HTML da página
#   browser-text                         — texto da página
#   browser-click <selector>             — clica em elemento
#   browser-type <selector> <texto>      — digita em elemento
#   browser-evaluate <js>                — executa JavaScript na página
#   browser-cookies                      — lista cookies
#   browser-tabs                         — lista abas
#   browser-tab-new [url]                — abre nova aba
#   camera-list                          — lista câmeras disponíveis
#   camera-snap [nome-camera]            — captura foto da câmera
#   camera-clip [nome-camera] [segundos] — grava clipe da câmera
#   ping                                 — teste de conectividade

GATEWAY_URL="${TRAY_GATEWAY:-http://127.0.0.1:18792}"
TIMEOUT="${TRAY_TIMEOUT:-30}"

cmd="${1:-status}"
shift

err() { echo "[tray] ERRO: $*" >&2; exit 1; }

json_str() {
  # Converte string para JSON string escapada
  python3 -c "import json,sys; print(json.dumps(sys.argv[1]))" "$1"
}

check_gateway() {
  curl -sf "${GATEWAY_URL}/status" > /dev/null 2>&1 \
    || err "Gateway não está rodando. Execute: bash ~/claude-tg-tmux/scripts/tray-gateway.sh"
}

mkdir -p /tmp/clawd-tray

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
    path=$(echo "$result" | python3 -c "import sys,json; print(json.load(sys.stdin).get('path',''))" 2>/dev/null)
    [ -n "$path" ] && echo "$path" || echo "$result"
    ;;

  screen-record|record)
    check_gateway
    duration="${1:-5}"
    result=$(curl -sf --max-time $((duration + 30)) -X POST "${GATEWAY_URL}/screen/record" \
      -H "Content-Type: application/json" \
      -d "{\"duration\":${duration}}" 2>/dev/null) || err "Falha ao gravar tela"
    # resultado pode ter path (arquivo grande) ou base64 (inline)
    path=$(echo "$result" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('path',''))" 2>/dev/null)
    if [ -n "$path" ]; then
      echo "$path"
    else
      b64=$(echo "$result" | python3 -c "import sys,json; print(json.load(sys.stdin).get('base64',''))" 2>/dev/null)
      if [ -n "$b64" ]; then
        out="/tmp/clawd-tray/screen_record_${EPOCHSECONDS}.mp4"
        echo "$b64" | base64 -d > "$out"
        echo "$out"
      else
        echo "$result"
      fi
    fi
    ;;

  notify)
    check_gateway
    title="${1:-Clawd}"
    msg="${2:-}"
    curl -sf --max-time 10 -X POST "${GATEWAY_URL}/notify" \
      -H "Content-Type: application/json" \
      -d "{\"title\":$(json_str "$title"),\"message\":$(json_str "$msg")}" > /dev/null \
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
      -d "{\"text\":$(json_str "$text")}" > /dev/null \
      && echo "Clipboard atualizado" || err "Falha ao escrever clipboard"
    ;;

  shell|run)
    check_gateway
    command="${1:-echo ok}"
    timeout="${2:-60000}"
    result=$(curl -sf --max-time $((timeout/1000 + 10)) -X POST "${GATEWAY_URL}/shell" \
      -H "Content-Type: application/json" \
      -d "{\"command\":$(json_str "$command"),\"timeout\":${timeout}}" 2>/dev/null) \
      || err "Falha ao executar comando"
    echo "$result" | python3 -c "
import sys,json
d=json.load(sys.stdin)
if d.get('stdout'): print(d['stdout'], end='')
if d.get('stderr'): print(d['stderr'], end='', file=sys.stderr)
sys.exit(d.get('exitCode',0))
" 2>&1
    ;;

  # ─── File operations ────────────────────────────────────────────────────────

  file-read|fread)
    check_gateway
    fpath="${1:?Uso: tray.sh file-read <path>}"
    result=$(curl -sf --max-time 15 -X POST "${GATEWAY_URL}/file/read" \
      -H "Content-Type: application/json" \
      -d "{\"path\":$(json_str "$fpath")}" 2>/dev/null) || err "Falha ao ler arquivo"
    # se for binário retorna base64, senão texto
    echo "$result" | python3 -c "
import sys,json,base64
d=json.load(sys.stdin)
if d.get('base64'):
    sys.stdout.buffer.write(base64.b64decode(d['base64']))
elif d.get('content') is not None:
    print(d['content'], end='')
else:
    print(json.dumps(d))
" 2>/dev/null
    ;;

  file-write|fwrite)
    check_gateway
    fpath="${1:?Uso: tray.sh file-write <path> <conteúdo>}"
    content="${2:-}"
    curl -sf --max-time 15 -X POST "${GATEWAY_URL}/file/write" \
      -H "Content-Type: application/json" \
      -d "{\"path\":$(json_str "$fpath"),\"content\":$(json_str "$content")}" > /dev/null \
      && echo "Arquivo escrito" || err "Falha ao escrever arquivo"
    ;;

  file-list|flist|ls)
    check_gateway
    fpath="${1:?Uso: tray.sh file-list <path>}"
    result=$(curl -sf --max-time 10 -X POST "${GATEWAY_URL}/file/list" \
      -H "Content-Type: application/json" \
      -d "{\"path\":$(json_str "$fpath")}" 2>/dev/null) || err "Falha ao listar diretório"
    echo "$result" | python3 -c "
import sys,json
d=json.load(sys.stdin)
for f in d.get('files',[]):
    print(f'{f[\"name\"]}\t{f.get(\"type\",\"?\")}\t{f.get(\"size\",\"\")}')
" 2>/dev/null
    ;;

  file-exists|fexists)
    check_gateway
    fpath="${1:?Uso: tray.sh file-exists <path>}"
    result=$(curl -sf --max-time 5 -G "${GATEWAY_URL}/file/exists" \
      --data-urlencode "path=$fpath" 2>/dev/null) || err "Falha ao verificar arquivo"
    exists=$(echo "$result" | python3 -c "import sys,json; print('sim' if json.load(sys.stdin).get('exists') else 'não')" 2>/dev/null)
    echo "$exists"
    ;;

  file-delete|fdelete|frm)
    check_gateway
    fpath="${1:?Uso: tray.sh file-delete <path>}"
    curl -sf --max-time 10 -X POST "${GATEWAY_URL}/file/delete" \
      -H "Content-Type: application/json" \
      -d "{\"path\":$(json_str "$fpath")}" > /dev/null \
      && echo "Arquivo deletado" || err "Falha ao deletar arquivo"
    ;;

  file-stat|fstat)
    check_gateway
    fpath="${1:?Uso: tray.sh file-stat <path>}"
    result=$(curl -sf --max-time 5 -G "${GATEWAY_URL}/file/stat" \
      --data-urlencode "path=$fpath" 2>/dev/null) || err "Falha ao obter info do arquivo"
    echo "$result" | python3 -c "
import sys,json
d=json.load(sys.stdin)
if d.get('error'):
    print('Erro:', d['error'])
else:
    print(f'Tamanho: {d.get(\"size\",\"?\")} bytes')
    print(f'Tipo: {d.get(\"type\",\"?\")}')
    print(f'Modificado: {d.get(\"mtime\",\"?\")}')
    print(f'Criado: {d.get(\"ctime\",\"?\")}')
" 2>/dev/null
    ;;

  # ─── Browser ────────────────────────────────────────────────────────────────

  browser)
    check_gateway
    body="${1:-{\"action\":\"status\"}}"
    curl -sf --max-time "$TIMEOUT" -X POST "${GATEWAY_URL}/browser" \
      -H "Content-Type: application/json" \
      -d "$body" 2>/dev/null || err "Falha na ação do browser"
    ;;

  browser-navigate|bnav)
    check_gateway
    url="${1:?Uso: tray.sh browser-navigate <url>}"
    curl -sf --max-time 30 -X POST "${GATEWAY_URL}/browser" \
      -H "Content-Type: application/json" \
      -d "{\"action\":\"navigate\",\"url\":$(json_str "$url")}" 2>/dev/null \
      || err "Falha ao navegar"
    ;;

  browser-screenshot|bscreenshot|bss)
    check_gateway
    result=$(curl -sf --max-time 30 -X POST "${GATEWAY_URL}/browser" \
      -H "Content-Type: application/json" \
      -d '{"action":"screenshot"}' 2>/dev/null) || err "Falha ao capturar browser"
    # gateway já converte base64 → path se for grande
    path=$(echo "$result" | python3 -c "import sys,json; print(json.load(sys.stdin).get('path',''))" 2>/dev/null)
    if [ -n "$path" ]; then
      echo "$path"
    else
      b64=$(echo "$result" | python3 -c "import sys,json; print(json.load(sys.stdin).get('base64',''))" 2>/dev/null)
      if [ -n "$b64" ]; then
        out="/tmp/clawd-tray/browser_${EPOCHSECONDS}.jpg"
        echo "$b64" | base64 -d > "$out"
        echo "$out"
      else
        echo "$result"
      fi
    fi
    ;;

  browser-snapshot|bsnap)
    check_gateway
    result=$(curl -sf --max-time 15 -X POST "${GATEWAY_URL}/browser" \
      -H "Content-Type: application/json" \
      -d '{"action":"snapshot"}' 2>/dev/null) || err "Falha ao obter snapshot"
    echo "$result" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('tree') or d.get('dom') or json.dumps(d))" 2>/dev/null
    ;;

  browser-content|bcontent|bhtml)
    check_gateway
    result=$(curl -sf --max-time 15 -X POST "${GATEWAY_URL}/browser" \
      -H "Content-Type: application/json" \
      -d '{"action":"content"}' 2>/dev/null) || err "Falha ao obter conteúdo"
    echo "$result" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('html') or json.dumps(d))" 2>/dev/null
    ;;

  browser-text|btext)
    check_gateway
    result=$(curl -sf --max-time 15 -X POST "${GATEWAY_URL}/browser" \
      -H "Content-Type: application/json" \
      -d '{"action":"text"}' 2>/dev/null) || err "Falha ao obter texto"
    echo "$result" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('text') or json.dumps(d))" 2>/dev/null
    ;;

  browser-click|bclick)
    check_gateway
    selector="${1:?Uso: tray.sh browser-click <selector>}"
    curl -sf --max-time 15 -X POST "${GATEWAY_URL}/browser" \
      -H "Content-Type: application/json" \
      -d "{\"action\":\"click\",\"selector\":$(json_str "$selector")}" > /dev/null \
      && echo "Clicado" || err "Falha ao clicar"
    ;;

  browser-type|btype)
    check_gateway
    selector="${1:?Uso: tray.sh browser-type <selector> <texto>}"
    text="${2:-}"
    curl -sf --max-time 15 -X POST "${GATEWAY_URL}/browser" \
      -H "Content-Type: application/json" \
      -d "{\"action\":\"type\",\"selector\":$(json_str "$selector"),\"text\":$(json_str "$text")}" > /dev/null \
      && echo "Digitado" || err "Falha ao digitar"
    ;;

  browser-evaluate|beval|bjs)
    check_gateway
    js="${1:?Uso: tray.sh browser-evaluate <javascript>}"
    result=$(curl -sf --max-time 15 -X POST "${GATEWAY_URL}/browser" \
      -H "Content-Type: application/json" \
      -d "{\"action\":\"evaluate\",\"script\":$(json_str "$js")}" 2>/dev/null) \
      || err "Falha ao executar JS"
    echo "$result" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('result',''))" 2>/dev/null
    ;;

  browser-cookies|bcookies)
    check_gateway
    result=$(curl -sf --max-time 10 -X POST "${GATEWAY_URL}/browser" \
      -H "Content-Type: application/json" \
      -d '{"action":"cookies"}' 2>/dev/null) || err "Falha ao obter cookies"
    echo "$result"
    ;;

  browser-tabs|btabs)
    check_gateway
    result=$(curl -sf --max-time 10 -X POST "${GATEWAY_URL}/browser" \
      -H "Content-Type: application/json" \
      -d '{"action":"tabs"}' 2>/dev/null) || err "Falha ao listar abas"
    echo "$result" | python3 -c "
import sys,json
d=json.load(sys.stdin)
for t in d.get('tabs',[]):
    active='*' if t.get('active') else ' '
    print(f'{active} [{t.get(\"index\",\"?\")}] {t.get(\"title\",\"\")} — {t.get(\"url\",\"\")}')
" 2>/dev/null
    ;;

  browser-tab-new|btnew)
    check_gateway
    url="${1:-}"
    body='{"action":"tab.new"}'
    [ -n "$url" ] && body="{\"action\":\"tab.new\",\"url\":$(json_str "$url")}"
    curl -sf --max-time 15 -X POST "${GATEWAY_URL}/browser" \
      -H "Content-Type: application/json" \
      -d "$body" > /dev/null && echo "Nova aba aberta" || err "Falha ao abrir aba"
    ;;

  # ─── Camera ─────────────────────────────────────────────────────────────────

  camera-list|cameras)
    check_gateway
    curl -sf --max-time 10 "${GATEWAY_URL}/camera/list" 2>/dev/null || err "Falha ao listar câmeras"
    ;;

  camera-snap|snap)
    check_gateway
    camera="${1:-}"
    body="{}"
    [ -n "$camera" ] && body="{\"camera\":$(json_str "$camera")}"
    result=$(curl -sf --max-time 30 -X POST "${GATEWAY_URL}/camera/snap" \
      -H "Content-Type: application/json" -d "$body" 2>/dev/null) || err "Falha ao capturar câmera"
    path=$(echo "$result" | python3 -c "import sys,json; print(json.load(sys.stdin).get('path',''))" 2>/dev/null)
    [ -n "$path" ] && echo "$path" || echo "$result"
    ;;

  camera-clip|clip-video)
    check_gateway
    camera="${1:-}"
    duration="${2:-5}"
    body="{\"duration\":${duration}}"
    [ -n "$camera" ] && body="{\"camera\":$(json_str "$camera"),\"duration\":${duration}}"
    result=$(curl -sf --max-time $((duration + 30)) -X POST "${GATEWAY_URL}/camera/clip" \
      -H "Content-Type: application/json" -d "$body" 2>/dev/null) || err "Falha ao gravar câmera"
    path=$(echo "$result" | python3 -c "import sys,json; print(json.load(sys.stdin).get('path',''))" 2>/dev/null)
    [ -n "$path" ] && echo "$path" || echo "$result"
    ;;

  ping)
    check_gateway
    curl -sf --max-time 5 -X POST "${GATEWAY_URL}/ping" 2>/dev/null \
      && echo "pong" || err "Sem resposta do tray"
    ;;

  help|-h|--help)
    cat <<'EOF'
Uso: tray.sh <comando> [args]

CONEXÃO
  status                               verifica conexão com o tray
  ping                                 teste de latência

TELA
  screenshot                           captura tela → path do arquivo
  screen-record [segundos]             grava tela → path do vídeo

NOTIFICAÇÃO
  notify <titulo> <msg>                toast notification no Windows

CLIPBOARD
  clipboard                            lê clipboard do PC
  clipboard-write <texto>              escreve no clipboard

SHELL
  shell <cmd> [timeout_ms]             executa comando no Windows

ARQUIVOS (no PC do Samyr)
  file-read <path>                     lê arquivo
  file-write <path> <conteúdo>         escreve arquivo
  file-list <path>                     lista diretório
  file-exists <path>                   verifica se existe
  file-delete <path>                   deleta arquivo
  file-stat <path>                     info do arquivo

BROWSER (Playwright)
  browser <json>                       ação genérica (raw)
  browser-navigate <url>               navega para URL
  browser-screenshot                   screenshot da página
  browser-snapshot                     árvore de acessibilidade
  browser-content                      HTML da página
  browser-text                         texto da página
  browser-click <selector>             clica em elemento
  browser-type <selector> <texto>      digita em elemento
  browser-evaluate <js>                executa JavaScript
  browser-cookies                      lista cookies
  browser-tabs                         lista abas
  browser-tab-new [url]                abre nova aba

CÂMERA
  camera-list                          lista câmeras
  camera-snap [nome]                   foto da câmera → path
  camera-clip [nome] [segundos]        clipe da câmera → path

Variáveis de ambiente:
  TRAY_GATEWAY=http://127.0.0.1:18792  URL do gateway
  TRAY_TIMEOUT=30                      timeout padrão em segundos
EOF
    ;;

  *)
    echo "Comando desconhecido: $cmd. Use 'tray.sh help' para ver todos os comandos." >&2
    exit 1
    ;;
esac
