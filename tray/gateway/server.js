// clawd-tray gateway — servidor WebSocket no clawd
// Recebe conexões do tray (Windows), expõe CLI para os agentes enviarem comandos
// Porta: 18791 (Tailscale)
'use strict';

const WebSocket = require('ws');
const http = require('http');
const fs = require('fs');
const path = require('path');
const readline = require('readline');

const PORT      = parseInt(process.env.TRAY_PORT || '18791');
const PASSWORD  = process.env.TRAY_PASSWORD || '';
const LOG_DIR   = '/tmp/clawd-tray';
const CMD_PIPE  = `${LOG_DIR}/cmd.sock`;     // arquivo de comando (agentes escrevem aqui)
const RESULT_DIR = `${LOG_DIR}/results`;     // agentes leem resultados aqui
const LOG_FILE  = `${LOG_DIR}/gateway.log`;

fs.mkdirSync(LOG_DIR, { recursive: true });
fs.mkdirSync(RESULT_DIR, { recursive: true });

let msgId = 0;
let node = null;        // WebSocket do tray conectado
let nodeInfo = {};
let pendingCmds = {};   // id → { resolve, reject, timer }

// ─── Log ──────────────────────────────────────────────────────────────────────
function log(msg) {
  const line = `[${new Date().toISOString()}] ${msg}`;
  console.log(line);
  try { fs.appendFileSync(LOG_FILE, line + '\n'); } catch (_) {}
}

// ─── Enviar comando ao tray e aguardar resultado ───────────────────────────────
function sendCmd(cmd, params = {}, timeoutMs = 30000) {
  return new Promise((resolve, reject) => {
    if (!node || node.readyState !== WebSocket.OPEN) {
      return reject(new Error('Tray desconectado'));
    }
    const id = String(++msgId);
    const timer = setTimeout(() => {
      delete pendingCmds[id];
      reject(new Error(`Timeout (${timeoutMs}ms) aguardando resposta de: ${cmd}`));
    }, timeoutMs);

    pendingCmds[id] = { resolve, reject, timer };
    node.send(JSON.stringify({ type: 'cmd', id, cmd, params }));
    log(`→ tray: ${cmd} (id=${id})`);
  });
}

// ─── HTTP API para agentes (bash pode usar curl) ───────────────────────────────
function startHttpServer() {
  const server = http.createServer(async (req, res) => {
    const url = new URL(req.url, `http://localhost:${PORT + 1}`);
    const sendJson = (code, obj) => {
      res.writeHead(code, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify(obj));
    };

    // Ler body
    const body = await new Promise((resolve) => {
      let data = '';
      req.on('data', (c) => data += c);
      req.on('end', () => {
        try { resolve(JSON.parse(data || '{}')); }
        catch (_) { resolve({}); }
      });
    });

    const notConnected = () => sendJson(503, { error: 'Tray desconectado' });

    if (!node && url.pathname !== '/status') return notConnected();

    try {
      switch (url.pathname) {
        case '/status':
          sendJson(200, {
            connected: !!node && node.readyState === WebSocket.OPEN,
            node: nodeInfo,
          });
          break;

        case '/screenshot':
        case '/screen/capture': {
          const r = await sendCmd('screen.capture', {}, 15000);
          if (r.base64) {
            // Salvar em arquivo e retornar path
            const p = `/tmp/clawd-tray/screenshot_${Date.now()}.jpg`;
            fs.writeFileSync(p, Buffer.from(r.base64, 'base64'));
            sendJson(200, { path: p, width: r.width, height: r.height });
          } else {
            sendJson(200, r);
          }
          break;
        }

        case '/screen/record': {
          const r = await sendCmd('screen.record', { duration: body.duration || 5 }, 90000);
          sendJson(200, r);
          break;
        }

        case '/camera/list': {
          const r = await sendCmd('camera.list', {}, 10000);
          sendJson(200, r);
          break;
        }

        case '/camera/snap': {
          const r = await sendCmd('camera.snap', body, 15000);
          if (r.base64) {
            const p = `/tmp/clawd-tray/camera_${Date.now()}.jpg`;
            fs.writeFileSync(p, Buffer.from(r.base64, 'base64'));
            sendJson(200, { path: p, width: r.width, height: r.height });
          } else {
            sendJson(200, r);
          }
          break;
        }

        case '/camera/clip': {
          const r = await sendCmd('camera.clip', body, 60000);
          sendJson(200, r);
          break;
        }

        case '/clipboard':
          if (req.method === 'GET') {
            sendJson(200, await sendCmd('clipboard.read', {}, 5000));
          } else {
            sendJson(200, await sendCmd('clipboard.write', { text: body.text || '' }, 5000));
          }
          break;

        case '/shell': {
          const r = await sendCmd('shell.run', { command: body.command, timeout: body.timeout }, body.timeout || 60000);
          sendJson(200, r);
          break;
        }

        case '/notify': {
          const r = await sendCmd('notify', { title: body.title || 'Clawd', message: body.message || '' }, 5000);
          sendJson(200, r);
          break;
        }

        case '/browser': {
          const timeout = body.action === 'snapshot' ? 15000 : 30000;
          const r = await sendCmd('browser', body, timeout);
          // se snapshot retornou screenshot embutido e é grande, salvar em arquivo
          if (r.base64) {
            const p = `/tmp/clawd-tray/browser_${Date.now()}.jpg`;
            fs.writeFileSync(p, Buffer.from(r.base64, 'base64'));
            const { base64: _, ...rest } = r;
            sendJson(200, { ...rest, path: p });
          } else {
            sendJson(200, r);
          }
          break;
        }

        // ─── File operations ────────────────────────────────────────────
        case '/file/read': {
          const r = await sendCmd('file.read', body, 15000);
          sendJson(200, r);
          break;
        }

        case '/file/write': {
          const r = await sendCmd('file.write', body, 15000);
          sendJson(200, r);
          break;
        }

        case '/file/list': {
          const dirPath = url.searchParams.get('path') || body.path;
          const r = await sendCmd('file.list', { path: dirPath }, 10000);
          sendJson(200, r);
          break;
        }

        case '/file/exists': {
          const filePath = url.searchParams.get('path') || body.path;
          const r = await sendCmd('file.exists', { path: filePath }, 5000);
          sendJson(200, r);
          break;
        }

        case '/file/delete': {
          const r = await sendCmd('file.delete', body, 10000);
          sendJson(200, r);
          break;
        }

        case '/file/stat': {
          const statPath = url.searchParams.get('path') || body.path;
          const r = await sendCmd('file.stat', { path: statPath }, 5000);
          sendJson(200, r);
          break;
        }

        case '/ping': {
          sendJson(200, await sendCmd('ping', {}, 5000));
          break;
        }

        default:
          sendJson(404, { error: 'Endpoint não encontrado' });
      }
    } catch (e) {
      log(`HTTP erro: ${e.message}`);
      sendJson(500, { error: e.message });
    }
  });

  const httpPort = PORT + 1; // 18792
  server.listen(httpPort, '127.0.0.1', () => {
    log(`HTTP API na porta ${httpPort} (localhost apenas)`);
  });
}

// ─── WebSocket Server (tray conecta aqui) ────────────────────────────────────
function startWsServer() {
  const wss = new WebSocket.Server({ port: PORT }, () => {
    log(`WebSocket gateway na porta ${PORT}`);
  });

  wss.on('connection', (ws, req) => {
    const ip = req.socket.remoteAddress;
    log(`Conexão de ${ip}`);

    // Se já tem um tray conectado, rejeitar (só um por vez)
    if (node && node.readyState === WebSocket.OPEN) {
      ws.send(JSON.stringify({ type: 'auth.fail', reason: 'Já existe um tray conectado' }));
      ws.close();
      return;
    }

    let authed = false;

    ws.on('message', (data) => {
      let msg;
      try { msg = JSON.parse(data.toString()); } catch (_) { return; }

      // Autenticação
      if (msg.type === 'auth') {
        if (!PASSWORD || msg.password === PASSWORD) {
          authed = true;
          node = ws;
          nodeInfo = { nodeId: msg.nodeId, nodeName: msg.nodeName, connectedAt: Date.now() };
          ws.send(JSON.stringify({ type: 'auth.ok' }));
          log(`Tray autenticado: ${msg.nodeName || msg.nodeId} (${ip})`);
        } else {
          ws.send(JSON.stringify({ type: 'auth.fail', reason: 'Senha incorreta' }));
          ws.close();
          log(`Auth rejeitado: ${ip}`);
        }
        return;
      }

      if (!authed) { ws.close(); return; }

      // Resultado de comando
      if (msg.type === 'res') {
        const pending = pendingCmds[msg.id];
        if (pending) {
          clearTimeout(pending.timer);
          delete pendingCmds[msg.id];
          if (msg.ok) {
            pending.resolve(msg.data || {});
          } else {
            pending.reject(new Error(msg.error || 'Erro desconhecido'));
          }
          log(`← tray: res id=${msg.id} ok=${msg.ok}`);
        }
      }
    });

    ws.on('close', (code) => {
      if (authed) {
        log(`Tray desconectado (${code})`);
        // Rejeitar comandos pendentes
        for (const [id, p] of Object.entries(pendingCmds)) {
          clearTimeout(p.timer);
          p.reject(new Error('Tray desconectado'));
          delete pendingCmds[id];
        }
        node = null;
        nodeInfo = {};
      }
    });

    ws.on('error', (e) => log(`WS erro: ${e.message}`));
  });
}

// ─── CLI via stdin (para testes diretos) ─────────────────────────────────────
function startStdinCli() {
  const rl = readline.createInterface({ input: process.stdin, terminal: false });
  rl.on('line', async (line) => {
    const trimmed = line.trim();
    if (!trimmed) return;
    try {
      const parts = trimmed.split(' ');
      const cmd = parts[0];
      const params = parts[1] ? JSON.parse(parts.slice(1).join(' ')) : {};
      const result = await sendCmd(cmd, params);
      console.log('RESULT:', JSON.stringify(result));
    } catch (e) {
      console.error('ERRO:', e.message);
    }
  });
}

// ─── Main ─────────────────────────────────────────────────────────────────────
startWsServer();
startHttpServer();
if (process.stdin.isTTY) startStdinCli();

log(`Clawd Tray Gateway iniciado`);
log(`WS: porta ${PORT} | HTTP: porta ${PORT + 1}`);
log(`Password: ${PASSWORD ? '*** (configurada)' : 'NENHUMA (inseguro!)'}`);

// Status periódico
setInterval(() => {
  const status = node && node.readyState === WebSocket.OPEN ? `conectado (${nodeInfo.nodeName})` : 'aguardando tray';
  log(`Status: ${status} | pendentes: ${Object.keys(pendingCmds).length}`);
}, 60000);

process.on('SIGINT', () => { log('Encerrando...'); process.exit(0); });
process.on('SIGTERM', () => { log('Encerrando...'); process.exit(0); });
