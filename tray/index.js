// clawd-tray — agente Windows para o sistema claude-tg-tmux
// Conecta ao gateway WebSocket no clawd e expõe: browser, tela, câmera, clipboard, shell
'use strict';

const childProcess = require('child_process');
const fs = require('fs');
const path = require('path');
const os = require('os');
const crypto = require('crypto');
const http = require('http');
const WebSocket = require('ws');

// Compatibilidade pkg: redirecionar paths de snapshot
if (process.pkg) {
  const orig = childProcess.spawn;
  childProcess.spawn = function(cmd, args, opts) {
    if (cmd && typeof cmd === 'string' && cmd.includes('\\snapshot\\')) {
      const real = cmd.replace(/C:\\snapshot\\clawd-tray\\node_modules/g,
        path.join(path.dirname(process.execPath), 'node_modules'));
      if (fs.existsSync(real)) cmd = real;
    }
    return orig.call(this, cmd, args, opts);
  };
}

const { spawn, exec } = childProcess;
const SysTray = require('systray2').default;
const notifier = require('node-notifier');
const screenshot = require('screenshot-desktop');

// ─── Paths ────────────────────────────────────────────────────────────────────
const CONFIG_PATH = path.join(__dirname, 'config.json');
const LOCK_PATH   = path.join(__dirname, '.lock');
const LOG_PATH    = path.join(__dirname, 'log.txt');
const MAX_LOG     = 500;
const MAX_PAYLOAD = 200 * 1024; // 200KB

// ─── Estado global ────────────────────────────────────────────────────────────
let config        = null;
let ws            = null;
let connected     = false;
let msgId         = 0;
let systray       = null;
let systrayReady  = false;
let lastStatus    = 'Desconectado';
let logs          = [];
let reconnectTimer = null;
let browser       = null;
let browserPage   = null;

// ─── Logging ──────────────────────────────────────────────────────────────────
function log(msg) {
  const line = `[${new Date().toLocaleTimeString('pt-BR')}] ${msg}`;
  console.log(line);
  logs.push(line);
  if (logs.length > MAX_LOG) logs.shift();
}

function notify(title, msg) {
  try {
    notifier.notify({
      title,
      message: msg,
      icon: path.join(__dirname, 'icon.ico'),
      sound: false,
    });
  } catch (_) {}
  log(`NOTIFY: ${title} — ${msg}`);
}

// ─── Config ───────────────────────────────────────────────────────────────────
function loadConfig() {
  try {
    config = JSON.parse(fs.readFileSync(CONFIG_PATH, 'utf8'));
    log(`Config carregada: ${config.nodeName || config.nodeId} → ${config.gatewayUrl}`);
    return config;
  } catch (e) {
    log(`Erro ao ler config: ${e.message}`);
    return null;
  }
}

// ─── Screenshot ───────────────────────────────────────────────────────────────
async function captureScreen() {
  return screenshot({ format: 'jpg' });
}

function readJpegDimensions(buf) {
  try {
    if (buf[0] !== 0xFF || buf[1] !== 0xD8) return { w: 0, h: 0 };
    let i = 2;
    while (i < buf.length - 10) {
      if (buf[i] !== 0xFF) { i++; continue; }
      while (i < buf.length && buf[i] === 0xFF) i++;
      const m = buf[i++];
      if ((m >= 0xC0 && m <= 0xC3) || (m >= 0xC5 && m <= 0xC7) || (m >= 0xC9 && m <= 0xCB)) {
        return { w: (buf[i+5] << 8) | buf[i+6], h: (buf[i+3] << 8) | buf[i+4] };
      }
      if (m >= 0xD0 && m <= 0xD9) continue;
      const len = (buf[i] << 8) | buf[i+1];
      i += len;
    }
  } catch (_) {}
  return { w: 0, h: 0 };
}

// ─── Câmera (FFmpeg) ──────────────────────────────────────────────────────────
function listCameras() {
  return new Promise((resolve) => {
    exec('ffmpeg -list_devices true -f dshow -i dummy 2>&1', { windowsHide: true }, (_, stdout, stderr) => {
      const output = stdout + stderr;
      const cameras = [];
      const re = /\[dshow.*?\] "(.*?)" \(video\)/g;
      let m;
      while ((m = re.exec(output)) !== null) cameras.push(m[1]);
      resolve({ cameras });
    });
  });
}

function snapCamera(camera, quality = 2) {
  return new Promise((resolve, reject) => {
    const tmp = path.join(os.tmpdir(), `clawd_cam_${Date.now()}.jpg`);
    const args = [
      '-f', 'dshow', '-i', `video=${camera}`,
      '-frames:v', '1', '-q:v', String(quality), '-y', tmp,
    ];
    const proc = spawn('ffmpeg', args, { windowsHide: true });
    const timer = setTimeout(() => { proc.kill(); reject(new Error('Camera timeout')); }, 10000);
    proc.on('close', () => {
      clearTimeout(timer);
      try {
        const buf = fs.readFileSync(tmp);
        fs.unlink(tmp, () => {});
        resolve(buf);
      } catch (e) { reject(e); }
    });
  });
}

function recordCamera(camera, duration = 5) {
  return new Promise((resolve, reject) => {
    const tmp = path.join(os.tmpdir(), `clawd_clip_${Date.now()}.mp4`);
    const args = [
      '-f', 'dshow', '-i', `video=${camera}`,
      '-t', String(Math.min(duration, 30)),
      '-c:v', 'libx264', '-preset', 'ultrafast', '-crf', '28', '-y', tmp,
    ];
    const proc = spawn('ffmpeg', args, { windowsHide: true });
    const timer = setTimeout(() => { proc.kill(); reject(new Error('Camera record timeout')); }, (duration + 10) * 1000);
    proc.on('close', () => {
      clearTimeout(timer);
      try {
        const buf = fs.readFileSync(tmp);
        fs.unlink(tmp, () => {});
        resolve(buf);
      } catch (e) { reject(e); }
    });
  });
}

function recordScreen(duration = 5) {
  return new Promise((resolve, reject) => {
    const tmp = path.join(os.tmpdir(), `clawd_screen_${Date.now()}.mp4`);
    const args = [
      '-f', 'gdigrab', '-framerate', '15', '-i', 'desktop',
      '-t', String(Math.min(duration, 60)),
      '-c:v', 'libx264', '-preset', 'ultrafast', '-crf', '28', '-y', tmp,
    ];
    const proc = spawn('ffmpeg', args, { windowsHide: true });
    const timer = setTimeout(() => { proc.kill(); reject(new Error('Screen record timeout')); }, (duration + 15) * 1000);
    proc.on('close', () => {
      clearTimeout(timer);
      try {
        const buf = fs.readFileSync(tmp);
        fs.unlink(tmp, () => {});
        resolve(buf);
      } catch (e) { reject(e); }
    });
  });
}

// ─── Clipboard (PowerShell) ───────────────────────────────────────────────────
function clipRead() {
  return new Promise((resolve) => {
    exec('powershell -Command "Get-Clipboard"', { windowsHide: true }, (_, out) => {
      resolve((out || '').trimEnd());
    });
  });
}

function clipWrite(text) {
  return new Promise((resolve) => {
    const escaped = text.replace(/'/g, "''").replace(/\$/g, '`$').replace(/`/g, '``');
    exec(`powershell -Command "Set-Clipboard -Value '${escaped}'"`, { windowsHide: true }, () => resolve());
  });
}

// ─── Shell ────────────────────────────────────────────────────────────────────
function runCmd(cmd, timeoutMs = 60000) {
  return new Promise((resolve) => {
    exec(cmd, { windowsHide: true, timeout: timeoutMs }, (err, stdout, stderr) => {
      resolve({ exitCode: err ? (err.code || 1) : 0, stdout: stdout || '', stderr: stderr || '' });
    });
  });
}

// ─── Browser (Playwright) ─────────────────────────────────────────────────────
async function ensureBrowser() {
  if (browser) return browser;
  const { chromium } = require('playwright-core');
  const opts = {
    executablePath: config?.browser?.executablePath || undefined,
    headless: config?.browser?.headless !== false,
    args: config?.browser?.args || [],
  };
  const ctx = await chromium.launchPersistentContext(
    path.join(os.homedir(), '.clawd-tray', 'browser-profile'),
    opts
  );
  browser = ctx;
  browserPage = ctx.pages()[0] || await ctx.newPage();
  log('Browser iniciado');
  return browser;
}

async function closeBrowser() {
  if (browser) { try { await browser.close(); } catch (_) {} browser = null; browserPage = null; }
}

async function browserAction(action, params = {}) {
  switch (action) {
    case 'status':
      return { running: !!browser, url: browserPage ? browserPage.url() : null };

    case 'start':
      await ensureBrowser();
      return { running: true };

    case 'stop':
      await closeBrowser();
      return { running: false };

    case 'navigate':
    case 'open': {
      await ensureBrowser();
      const url = params.url || params.href || 'about:blank';
      await browserPage.goto(url, { waitUntil: 'domcontentloaded', timeout: 30000 });
      return { url: browserPage.url() };
    }

    case 'screenshot': {
      await ensureBrowser();
      const buf = await browserPage.screenshot({ type: 'jpeg', quality: 75 });
      return { base64: buf.toString('base64'), format: 'jpg' };
    }

    case 'snapshot': {
      await ensureBrowser();
      const snapshot = await browserPage.accessibility.snapshot();
      return { snapshot };
    }

    case 'content': {
      await ensureBrowser();
      const html = await browserPage.content();
      return { html };
    }

    case 'click': {
      await ensureBrowser();
      if (params.selector) await browserPage.click(params.selector);
      else if (params.x != null) await browserPage.mouse.click(params.x, params.y);
      return { ok: true };
    }

    case 'type': {
      await ensureBrowser();
      if (params.selector) await browserPage.type(params.selector, params.text || '');
      else await browserPage.keyboard.type(params.text || '');
      return { ok: true };
    }

    case 'evaluate': {
      await ensureBrowser();
      const result = await browserPage.evaluate(params.script || '');
      return { result };
    }

    case 'cookies': {
      await ensureBrowser();
      const cookies = await browser.cookies();
      return { cookies };
    }

    case 'tabs': {
      await ensureBrowser();
      const pages = browser.pages();
      return { tabs: pages.map((p, i) => ({ index: i, url: p.url(), title: p.title() })) };
    }

    default:
      throw new Error(`Ação de browser desconhecida: ${action}`);
  }
}

// ─── WebSocket Gateway ────────────────────────────────────────────────────────
function send(msg) {
  if (ws && ws.readyState === WebSocket.OPEN) {
    ws.send(JSON.stringify(msg));
  }
}

function sendResult(id, ok, data, error) {
  send({ type: 'res', id, ok, data: ok ? data : undefined, error: ok ? undefined : (error || 'erro') });
}

async function handleCommand(id, cmd, params) {
  log(`CMD: ${cmd}`);
  try {
    let result;

    switch (cmd) {
      // ── Tela ──
      case 'screen.capture': {
        const buf = await captureScreen();
        const { w, h } = readJpegDimensions(buf);
        if (buf.length > MAX_PAYLOAD) {
          const tmp = path.join(os.tmpdir(), `clawd_ss_${Date.now()}.jpg`);
          fs.writeFileSync(tmp, buf);
          result = { path: tmp, width: w, height: h, size: buf.length };
        } else {
          result = { base64: buf.toString('base64'), format: 'jpg', width: w, height: h };
        }
        break;
      }

      case 'screen.record': {
        const buf = await recordScreen(params?.duration || 5);
        const tmp = path.join(os.tmpdir(), `clawd_srec_${Date.now()}.mp4`);
        fs.writeFileSync(tmp, buf);
        result = { path: tmp, size: buf.length };
        break;
      }

      // ── Câmera ──
      case 'camera.list':
        result = await listCameras();
        break;

      case 'camera.snap': {
        const buf = await snapCamera(params?.camera || '', params?.quality);
        const { w, h } = readJpegDimensions(buf);
        result = { base64: buf.toString('base64'), format: 'jpg', width: w, height: h };
        break;
      }

      case 'camera.clip': {
        const buf = await recordCamera(params?.camera || '', params?.duration || 5);
        const tmp = path.join(os.tmpdir(), `clawd_clip_${Date.now()}.mp4`);
        fs.writeFileSync(tmp, buf);
        result = { path: tmp, size: buf.length };
        break;
      }

      // ── Clipboard ──
      case 'clipboard.read':
        result = { text: await clipRead() };
        break;

      case 'clipboard.write':
        await clipWrite(params?.text || '');
        result = { ok: true };
        break;

      // ── Shell ──
      case 'shell.run':
        result = await runCmd(params?.command || '', params?.timeout);
        break;

      // ── Notificação ──
      case 'notify':
        notify(params?.title || 'Clawd', params?.message || '');
        result = { ok: true };
        break;

      // ── Browser ──
      case 'browser':
        result = await browserAction(params?.action || 'status', params);
        break;

      // ── Ping ──
      case 'ping':
        result = { pong: true, ts: Date.now() };
        break;

      default:
        throw new Error(`Comando desconhecido: ${cmd}`);
    }

    sendResult(id, true, result);
  } catch (e) {
    log(`Erro em ${cmd}: ${e.message}`);
    sendResult(id, false, null, e.message);
  }
}

function handleMessage(raw) {
  let msg;
  try { msg = JSON.parse(raw); } catch (_) { return; }

  // Autenticação aprovada
  if (msg.type === 'auth.ok') {
    connected = true;
    lastStatus = 'Conectado';
    log(`Autenticado como: ${config.nodeId}`);
    notify('Clawd Tray', 'Conectado ao clawd');
    updateTrayStatus();
    return;
  }

  // Autenticação rejeitada
  if (msg.type === 'auth.fail') {
    log('Autenticação rejeitada — verifique a senha no config.json');
    notify('Clawd Tray', 'Senha incorreta');
    ws.close();
    return;
  }

  // Comando do servidor
  if (msg.type === 'cmd') {
    handleCommand(msg.id, msg.cmd, msg.params || {});
  }
}

function scheduleReconnect() {
  if (reconnectTimer) return;
  const delay = config?.reconnectInterval || 5000;
  reconnectTimer = setTimeout(() => { reconnectTimer = null; connect(); }, delay);
}

function connect() {
  if (!config) { loadConfig(); if (!config) return; }
  if (ws) { try { ws.terminate(); } catch (_) {} ws = null; }

  log(`Conectando a ${config.gatewayUrl}...`);
  lastStatus = 'Conectando...';
  updateTrayStatus();

  try {
    ws = new WebSocket(config.gatewayUrl);

    ws.on('open', () => {
      log('WebSocket conectado — autenticando...');
      // Enviar auth imediatamente ao conectar
      send({ type: 'auth', nodeId: config.nodeId, nodeName: config.nodeName, password: config.password });
    });

    ws.on('message', (data) => handleMessage(data.toString()));

    ws.on('close', (code) => {
      const wasConnected = connected;
      connected = false;
      lastStatus = 'Desconectado';
      updateTrayStatus();
      if (wasConnected) {
        log(`Desconectado (${code})`);
        notify('Clawd Tray', 'Desconectado do clawd');
      }
      scheduleReconnect();
    });

    ws.on('error', (err) => {
      log(`Erro WS: ${err.message}`);
      lastStatus = 'Erro de conexão';
      updateTrayStatus();
    });

  } catch (e) {
    log(`Erro ao conectar: ${e.message}`);
    scheduleReconnect();
  }
}

function disconnect() {
  if (reconnectTimer) { clearTimeout(reconnectTimer); reconnectTimer = null; }
  if (ws) { try { ws.terminate(); } catch (_) {} ws = null; }
  connected = false;
  lastStatus = 'Desconectado';
  updateTrayStatus();
}

// ─── Systray ──────────────────────────────────────────────────────────────────
function updateTrayStatus() {
  if (!systray || !systrayReady) return;
  systray.sendAction({
    type: 'update-item',
    item: { title: connected ? '● Conectado' : `○ ${lastStatus}`, enabled: false },
    seq_id: 1,
  });
  systray.sendAction({
    type: 'update-item',
    item: { title: '▶ Conectar', enabled: !connected },
    seq_id: 2,
  });
  systray.sendAction({
    type: 'update-item',
    item: { title: '■ Desconectar', enabled: connected },
    seq_id: 3,
  });
}

function openLogs() {
  fs.writeFileSync(LOG_PATH, logs.join('\n'));
  spawn('notepad', [LOG_PATH], { detached: true, windowsHide: false });
}

function openConfig() {
  spawn('notepad', [CONFIG_PATH], { detached: true, windowsHide: false });
}

async function isStartupEnabled() {
  return new Promise((resolve) => {
    exec('reg query "HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Run" /v ClawdTray 2>nul',
      { windowsHide: true }, (err) => resolve(!err));
  });
}

async function toggleStartup() {
  const enabled = await isStartupEnabled();
  const exe = process.execPath || process.argv[0];
  const cmd = enabled
    ? 'reg delete "HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Run" /v ClawdTray /f'
    : `reg add "HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Run" /v ClawdTray /t REG_SZ /d "${exe}" /f`;
  return new Promise((resolve) => {
    exec(cmd, { windowsHide: true }, () => resolve(!enabled));
  });
}

// ─── Single instance ──────────────────────────────────────────────────────────
function checkSingleInstance() {
  if (fs.existsSync(LOCK_PATH)) {
    const pid = parseInt(fs.readFileSync(LOCK_PATH, 'utf8').trim());
    try { process.kill(pid, 0); console.log('Já em execução (PID: ' + pid + ')'); process.exit(0); }
    catch (_) { /* lock órfão */ }
  }
  fs.writeFileSync(LOCK_PATH, String(process.pid));
}

function cleanupLock() {
  try {
    if (fs.existsSync(LOCK_PATH)) {
      const pid = fs.readFileSync(LOCK_PATH, 'utf8').trim();
      if (pid === String(process.pid)) fs.unlinkSync(LOCK_PATH);
    }
  } catch (_) {}
}

// ─── Main ─────────────────────────────────────────────────────────────────────
async function main() {
  checkSingleInstance();

  if (!loadConfig()) {
    notify('Clawd Tray', 'config.json não encontrado — copie config.example.json');
    process.exit(1);
  }

  // Ícone inline base64 (16x16 branco) — substitua por icon.ico real no build
  const icon = fs.existsSync(path.join(__dirname, 'icon.ico'))
    ? fs.readFileSync(path.join(__dirname, 'icon.ico')).toString('base64')
    : 'iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAABHNCSVQICAgIfAhkiAAAAAlwSFlzAAAAdgAAAHYBTnsmCAAAABl0RVh0U29mdHdhcmUAd3d3Lmlua3NjYXBlLm9yZ5vuPBoAAABMSURBVDiNY2AYBfQHAAMAAQACAAEAAQABAAMAAQACAAEAAQABAAMAAQACAAEAAQABAAMAAQACAAEAAQABAAMAAQACAAEAAQABAAMAAf8CBwAWHQAAAABJRU5ErkJggg==';

  const startupEnabled = await isStartupEnabled();

  systray = new SysTray({
    menu: {
      icon,
      title: '',
      tooltip: `Clawd Tray — ${config.nodeName || config.nodeId}`,
      items: [
        { title: `Clawd Tray — ${config.nodeName || config.nodeId}`, enabled: false },
        { title: '○ Desconectado', enabled: false },
        { title: '▶ Conectar', enabled: true },
        { title: '■ Desconectar', enabled: false },
        SysTray.separator,
        { title: 'Configurações', enabled: true },
        { title: 'Logs', enabled: true },
        { title: startupEnabled ? '[x] Iniciar com Windows' : '[ ] Iniciar com Windows', enabled: true },
        SysTray.separator,
        { title: 'Sair', enabled: true },
      ],
    },
  });

  systray.onClick(async (action) => {
    switch (action.seq_id) {
      case 2: connect(); break;
      case 3: disconnect(); break;
      case 5: openConfig(); break;
      case 6: openLogs(); break;
      case 7: {
        const now = await toggleStartup();
        systray.sendAction({
          type: 'update-item',
          item: { title: now ? '[x] Iniciar com Windows' : '[ ] Iniciar com Windows', enabled: true },
          seq_id: 7,
        });
        notify('Clawd Tray', now ? 'Iniciará com o Windows' : 'Não iniciará com o Windows');
        break;
      }
      case 9:
        disconnect();
        await closeBrowser();
        cleanupLock();
        systray.kill();
        process.exit(0);
    }
  });

  log('Clawd Tray iniciado');
  log(`Node: ${config.nodeId} → ${config.gatewayUrl}`);

  // Recarregar config automaticamente ao salvar
  fs.watch(CONFIG_PATH, () => {
    setTimeout(() => {
      log('Config alterada, reconectando...');
      loadConfig();
      disconnect();
      setTimeout(connect, 500);
    }, 300);
  });

  setTimeout(() => {
    systrayReady = true;
    updateTrayStatus();
    connect();
  }, 1000);
}

process.on('SIGINT', async () => { disconnect(); await closeBrowser(); cleanupLock(); process.exit(0); });
process.on('SIGTERM', async () => { disconnect(); await closeBrowser(); cleanupLock(); process.exit(0); });
process.on('exit', () => { cleanupLock(); });

main().catch((e) => { cleanupLock(); console.error('Erro fatal:', e); process.exit(1); });
