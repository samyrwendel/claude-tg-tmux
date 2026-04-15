// claude-node — agente Windows para o sistema claude-tg-tmux
// Protocolo simples: WS → auth {password} → auth.ok → cmd/res
'use strict';

const childProcess = require('child_process');
const fs   = require('fs');
const path = require('path');
const os   = require('os');
const http = require('http');
const WebSocket = require('ws');

// Patch spawn para pkg
if (process.pkg) {
  const orig = childProcess.spawn;
  childProcess.spawn = function(cmd, args, opts) {
    if (cmd && typeof cmd === 'string' && cmd.includes('\\snapshot\\')) {
      const real = cmd.replace(/C:\\snapshot\\claude-node\\node_modules/g,
        path.join(path.dirname(process.execPath), 'node_modules'));
      if (fs.existsSync(real)) cmd = real;
    }
    return orig.call(this, cmd, args, opts);
  };
}

const { spawn, exec } = childProcess;
const SysTray  = require('systray2').default;
const notifier = require('node-notifier');
const screenshot = require('screenshot-desktop');

// ─── Paths ────────────────────────────────────────────────────────────────────
const BASE_DIR    = process.pkg ? path.dirname(process.execPath) : __dirname;
const CONFIG_PATH = path.join(BASE_DIR, 'config.json');
const LOCK_PATH   = path.join(BASE_DIR, '.lock');
const LOG_PATH    = path.join(BASE_DIR, 'log.txt');
const STATUS_PATH = path.join(BASE_DIR, 'status.txt');
const PROFILES_DIR = path.join(os.homedir(), '.claude-node', 'browser');
const MAX_LOG     = 500;
const MAX_PAYLOAD = 256 * 1024; // 256KB

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
let browserCtx    = null;
let browserPage   = null;
let currentProfile = null;

// ─── Logging ──────────────────────────────────────────────────────────────────
function log(msg) {
  const line = `[${new Date().toLocaleTimeString('pt-BR')}] ${msg}`;
  console.log(line);
  logs.push(line);
  if (logs.length > MAX_LOG) logs.shift();
}

function writeStatus(status, details = '') {
  try { fs.writeFileSync(STATUS_PATH, JSON.stringify({ status, details, connected, ts: new Date().toISOString() })); } catch (_) {}
}

// ─── Config ───────────────────────────────────────────────────────────────────
function loadConfig() {
  try {
    let raw = fs.readFileSync(CONFIG_PATH, 'utf8');
    if (raw.charCodeAt(0) === 0xFEFF) raw = raw.slice(1); // Remove BOM (PowerShell)
    config = JSON.parse(raw);
    log(`Config: ${config.nodeName || config.nodeId} → ${config.gatewayUrl}`);
    return config;
  } catch (e) { log(`Erro config: ${e.message}`); return null; }
}

// ─── FFmpeg path ──────────────────────────────────────────────────────────────
function ffmpeg() {
  return config?.ffmpegPath || 'ffmpeg';
}

// ─── JPEG dimensions ──────────────────────────────────────────────────────────
function jpegDims(buf) {
  try {
    if (buf[0] !== 0xFF || buf[1] !== 0xD8) return { width: 0, height: 0 };
    let i = 2;
    while (i < buf.length - 10) {
      if (buf[i] !== 0xFF) { i++; continue; }
      while (i < buf.length && buf[i] === 0xFF) i++;
      const m = buf[i++];
      if ((m >= 0xC0 && m <= 0xC3) || (m >= 0xC5 && m <= 0xC7) || (m >= 0xC9 && m <= 0xCB) || (m >= 0xCD && m <= 0xCF)) {
        return { width: (buf[i+5] << 8) | buf[i+6], height: (buf[i+3] << 8) | buf[i+4] };
      }
      if (m >= 0xD0 && m <= 0xD9) continue;
      const len = (buf[i] << 8) | buf[i+1];
      i += len;
    }
  } catch (_) {}
  return { width: 0, height: 0 };
}

// ─── Screenshot ───────────────────────────────────────────────────────────────
async function captureScreen(format = 'jpg') {
  return screenshot({ format });
}

// ─── Câmera ───────────────────────────────────────────────────────────────────
function listCameras() {
  return new Promise((resolve) => {
    exec(`"${ffmpeg()}" -list_devices true -f dshow -i dummy 2>&1`, { encoding: 'utf8' }, (_, stdout, stderr) => {
      const out = stdout + stderr;
      const cameras = [];
      const re = /\[dshow[^\]]*\]\s*"([^"]+)"\s*\(video\)/g;
      let m;
      while ((m = re.exec(out)) !== null) cameras.push({ name: m[1], index: cameras.length });
      resolve({ cameras });
    });
  });
}

function snapCamera(params = {}) {
  return new Promise((resolve, reject) => {
    const cam = params.camera || params.name || params.device || '';
    const q   = Math.round((100 - (params.quality || 85)) / 3.3);
    const args = [
      '-f', 'dshow', '-i', `video=${cam}`,
      '-frames:v', '1', '-f', 'image2', '-c:v', 'mjpeg',
      '-q:v', String(q), '-update', '1', 'pipe:1',
    ];
    const proc = spawn(ffmpeg(), args, { windowsHide: true, stdio: ['pipe', 'pipe', 'pipe'] });
    const chunks = []; let stderr = '';
    proc.stdout.on('data', c => chunks.push(c));
    proc.stderr.on('data', c => { stderr += c; });
    const t = setTimeout(() => { proc.kill(); reject(new Error('Camera timeout')); }, 12000);
    proc.on('close', async () => {
      clearTimeout(t);
      if (!chunks.length) return reject(new Error(`Camera failed: ${stderr.slice(0, 200)}`));
      const buf = Buffer.concat(chunks);
      const dims = jpegDims(buf);
      resolve({ base64: buf.toString('base64'), format: 'jpg', size: buf.length, ...dims });
    });
    proc.on('error', e => { clearTimeout(t); reject(e); });
  });
}

function clipCamera(params = {}) {
  return new Promise((resolve, reject) => {
    const cam = params.camera || params.name || params.device || '';
    const dur = Math.min(params.duration || 5, 30);
    const tmp = path.join(os.tmpdir(), `claude_clip_${Date.now()}.mp4`);
    exec(`"${ffmpeg()}" -f dshow -i video="${cam}" -t ${dur} -c:v libx264 -preset ultrafast -y "${tmp}" 2>&1`,
      { timeout: (dur + 15) * 1000, windowsHide: true }, (err) => {
        if (err && !fs.existsSync(tmp)) return reject(new Error(err.message));
        const buf = fs.readFileSync(tmp); fs.unlink(tmp, () => {});
        resolve({ base64: buf.toString('base64'), format: 'mp4', size: buf.length, duration: dur });
      });
  });
}

function recordScreen(params = {}) {
  return new Promise((resolve, reject) => {
    const dur = Math.min(params.duration || 5, 60);
    const fps = params.fps || 15;
    const tmp = path.join(os.tmpdir(), `claude_screen_${Date.now()}.mp4`);
    exec(`"${ffmpeg()}" -f gdigrab -framerate ${fps} -i desktop -t ${dur} -c:v libx264 -preset ultrafast -pix_fmt yuv420p -y "${tmp}" 2>&1`,
      { timeout: (dur + 20) * 1000, windowsHide: true }, (err) => {
        if (err && !fs.existsSync(tmp)) return reject(new Error(err.message));
        const buf = fs.readFileSync(tmp); fs.unlink(tmp, () => {});
        resolve({ base64: buf.toString('base64'), format: 'mp4', size: buf.length, duration: dur, fps });
      });
  });
}

// ─── Clipboard ────────────────────────────────────────────────────────────────
function clipRead() {
  return new Promise((resolve) => {
    exec('powershell -Command "Get-Clipboard"', { encoding: 'utf8', windowsHide: true }, (_, out) => resolve((out || '').trimEnd()));
  });
}

function clipWrite(text) {
  return new Promise((resolve) => {
    const safe = String(text || ' ').replace(/'/g, "''").replace(/`/g, '``').replace(/\$/g, '`$');
    exec(`powershell -Command "Set-Clipboard -Value '${safe}'"`, { windowsHide: true }, () => resolve());
  });
}

// ─── Shell ────────────────────────────────────────────────────────────────────
function runCmd(command, timeoutMs = 60000) {
  return new Promise((resolve) => {
    exec(command, { timeout: timeoutMs, windowsHide: true, shell: true }, (err, stdout, stderr) => {
      resolve({ success: !err, stdout: stdout || '', stderr: stderr || '', exitCode: err?.code || 0 });
    });
  });
}

// ─── Arquivos ─────────────────────────────────────────────────────────────────
function fileRead(p) {
  return new Promise((resolve, reject) => {
    fs.readFile(p, (err, data) => {
      if (err) return reject(err);
      const isText = !data.slice(0, 512).includes(0x00);
      resolve({ path: p, size: data.length, isText, encoding: isText ? 'utf8' : 'base64',
        content: isText ? data.toString('utf8') : data.toString('base64') });
    });
  });
}

function fileWrite(p, content, encoding = 'utf8') {
  return new Promise((resolve, reject) => {
    const data = encoding === 'base64' ? Buffer.from(content, 'base64') : content;
    fs.writeFile(p, data, err => err ? reject(err) : resolve({ path: p, size: Buffer.byteLength(data), ok: true }));
  });
}

function fileList(p) {
  return new Promise((resolve, reject) => {
    fs.readdir(p, { withFileTypes: true }, (err, entries) => {
      if (err) return reject(err);
      resolve({ path: p, files: entries.map(e => ({ name: e.name, isDir: e.isDirectory(), path: path.join(p, e.name) })) });
    });
  });
}

function fileExists(p) {
  return new Promise(resolve => fs.access(p, fs.constants.F_OK, err => resolve({ path: p, exists: !err })));
}

function fileDelete(p) {
  return new Promise((resolve, reject) => fs.unlink(p, err => err ? reject(err) : resolve({ path: p, deleted: true })));
}

function fileStat(p) {
  return new Promise((resolve, reject) => {
    fs.stat(p, (err, s) => err ? reject(err) : resolve({
      path: p, size: s.size, isDir: s.isDirectory(), isFile: s.isFile(),
      created: s.birthtime, modified: s.mtime, accessed: s.atime,
    }));
  });
}

// ─── Notificação nativa Windows (Toast) ───────────────────────────────────────
function notifyWindows(title, message) {
  // Tentar Toast nativo primeiro, fallback para node-notifier
  const ps = `
    [Windows.UI.Notifications.ToastNotificationManager,Windows.UI.Notifications,ContentType=WindowsRuntime]|Out-Null;
    [Windows.Data.Xml.Dom.XmlDocument,Windows.Data.Xml.Dom.XmlDocument,ContentType=WindowsRuntime]|Out-Null;
    $xml=New-Object Windows.Data.Xml.Dom.XmlDocument;
    $xml.LoadXml('<toast><visual><binding template="ToastText02"><text id="1">${title.replace(/['"<>&]/g,'')}</text><text id="2">${message.replace(/['"<>&]/g,'')}</text></binding></visual></toast>');
    $toast=[Windows.UI.Notifications.ToastNotification]::new($xml);
    [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier('ClaudeNode').Show($toast)
  `.replace(/\n\s*/g, '');
  exec(`powershell -Command "${ps}"`, { windowsHide: true }, (err) => {
    if (err) {
      notifier.notify({ title, message, icon: path.join(BASE_DIR, 'icon.ico'), sound: false });
    }
  });
}

// ─── Browser (Playwright) ─────────────────────────────────────────────────────
function formatA11yTree(node, depth = 0) {
  if (!node) return '';
  const indent = '  '.repeat(depth);
  let out = '';
  if (node.role && node.role !== 'none' && node.role !== 'generic') {
    const name    = node.name    ? ` "${node.name}"`               : '';
    const val     = node.value   ? ` value="${node.value}"`         : '';
    const checked = node.checked !== undefined ? ` [${node.checked ? 'x' : ' '}]` : '';
    const focused = node.focused ? ' [focused]'                     : '';
    out += `${indent}- ${node.role}${name}${val}${checked}${focused}\n`;
  }
  for (const child of node.children || []) {
    out += formatA11yTree(child, node.role && node.role !== 'none' ? depth + 1 : depth);
  }
  return out;
}

async function ensureBrowser(params = {}) {
  const profile  = params.profile || 'claude';
  const headless = params.headless ?? config?.browser?.headless ?? false;
  if (browserCtx && currentProfile === profile) return browserCtx;
  if (browserCtx) { await browserCtx.close().catch(() => {}); browserCtx = null; browserPage = null; }
  const { chromium } = require('playwright-core');
  const userDataDir = path.join(PROFILES_DIR, profile, 'user-data');
  fs.mkdirSync(userDataDir, { recursive: true });
  browserCtx = await chromium.launchPersistentContext(userDataDir, {
    headless,
    executablePath: config?.browser?.executablePath || undefined,
    args: ['--disable-blink-features=AutomationControlled', '--no-first-run', '--start-maximized', '--disable-infobars'],
    ignoreDefaultArgs: ['--disable-extensions', '--enable-automation'],
    viewport: null,
  });
  currentProfile = profile;
  browserPage = browserCtx.pages()[0] || await browserCtx.newPage();
  log(`Browser iniciado: profile=${profile}, headless=${headless}`);
  return browserCtx;
}

async function closeBrowser() {
  if (browserCtx) { await browserCtx.close().catch(() => {}); browserCtx = null; browserPage = null; currentProfile = null; }
}

async function browserAction(action, params = {}) {
  switch (action) {
    case 'status':
      return { running: !!browserCtx, profile: currentProfile, url: browserPage?.url() ?? null, title: await browserPage?.title().catch(() => null) ?? null };

    case 'start':
      await ensureBrowser(params);
      return { running: true, profile: currentProfile, url: browserPage?.url() };

    case 'stop': case 'close':
      await closeBrowser();
      return { running: false };

    case 'navigate': case 'open': case 'goto': {
      if (!browserPage) { await ensureBrowser(params); }
      if (!params.url) throw new Error('url obrigatória');
      await browserPage.goto(params.url, { waitUntil: params.waitUntil || 'domcontentloaded', timeout: params.timeout || 30000 });
      return { url: browserPage.url(), title: await browserPage.title().catch(() => null) };
    }

    case 'reload':
      if (!browserPage) throw new Error('Sem sessão ativa');
      await browserPage.reload({ waitUntil: 'domcontentloaded' });
      return { url: browserPage.url() };

    case 'back':
      if (!browserPage) throw new Error('Sem sessão ativa');
      await browserPage.goBack();
      return { url: browserPage.url() };

    case 'forward':
      if (!browserPage) throw new Error('Sem sessão ativa');
      await browserPage.goForward();
      return { url: browserPage.url() };

    case 'snapshot': {
      if (!browserPage) throw new Error('Sem sessão ativa');
      try {
        const tree = await browserPage.accessibility.snapshot();
        return { snapshot: formatA11yTree(tree), url: browserPage.url(), format: 'aria' };
      } catch (_) {
        const dom = await browserPage.evaluate(() => {
          function walk(el) {
            if (!el || el.nodeType !== 1) return null;
            const tag = el.tagName.toLowerCase();
            const obj = { tag };
            if (el.id) obj.id = el.id;
            const text = el.textContent?.slice(0, 80)?.trim();
            if (text) obj.text = text;
            if (el.href) obj.href = el.href;
            if (el.value !== undefined) obj.value = el.value;
            obj.children = Array.from(el.children).map(walk).filter(Boolean);
            return obj;
          }
          return walk(document.body);
        });
        function fmt(n, d = 0) {
          if (!n) return '';
          const ind = '  '.repeat(d);
          let s = `${ind}- ${n.tag}${n.id ? ' #'+n.id : ''}${n.text ? ' "'+n.text+'"' : ''}${n.href ? ' ['+n.href+']' : ''}\n`;
          for (const c of n.children || []) s += fmt(c, d + 1);
          return s;
        }
        return { snapshot: fmt(dom), url: browserPage.url(), format: 'dom' };
      }
    }

    case 'screenshot': {
      if (!browserPage) throw new Error('Sem sessão ativa');
      const buf = await browserPage.screenshot({ type: 'jpeg', quality: params.quality || 75, fullPage: params.fullPage || false });
      return { base64: buf.toString('base64'), format: 'jpg', url: browserPage.url() };
    }

    case 'content': case 'html': {
      if (!browserPage) throw new Error('Sem sessão ativa');
      return { content: await browserPage.content(), url: browserPage.url() };
    }

    case 'text': {
      if (!browserPage) throw new Error('Sem sessão ativa');
      const text = await browserPage.evaluate(() => document.body.innerText);
      return { text, url: browserPage.url() };
    }

    case 'click': {
      if (!browserPage) throw new Error('Sem sessão ativa');
      if (params.selector) await browserPage.click(params.selector, { timeout: params.timeout || 10000 });
      else if (params.x != null) await browserPage.mouse.click(params.x, params.y);
      return { ok: true };
    }

    case 'type': case 'fill': {
      if (!browserPage) throw new Error('Sem sessão ativa');
      if (params.selector) await browserPage.fill(params.selector, params.text || '');
      else await browserPage.keyboard.type(params.text || '');
      return { ok: true };
    }

    case 'press': {
      if (!browserPage) throw new Error('Sem sessão ativa');
      const key = params.key || params.text;
      if (params.selector) await browserPage.press(params.selector, key);
      else await browserPage.keyboard.press(key);
      return { ok: true };
    }

    case 'scroll': {
      if (!browserPage) throw new Error('Sem sessão ativa');
      await browserPage.evaluate(({ x, y }) => window.scrollBy(x, y), { x: params.x || 0, y: params.y || 500 });
      return { ok: true };
    }

    case 'hover': {
      if (!browserPage) throw new Error('Sem sessão ativa');
      await browserPage.hover(params.selector);
      return { ok: true };
    }

    case 'focus': {
      if (!browserPage) throw new Error('Sem sessão ativa');
      await browserPage.focus(params.selector);
      return { ok: true };
    }

    case 'select': {
      if (!browserPage) throw new Error('Sem sessão ativa');
      await browserPage.selectOption(params.selector, params.value || params.option);
      return { ok: true };
    }

    case 'wait': {
      if (!browserPage) throw new Error('Sem sessão ativa');
      if (params.selector) await browserPage.waitForSelector(params.selector, { timeout: params.timeout || 10000 });
      else await browserPage.waitForTimeout(params.ms || 1000);
      return { ok: true };
    }

    case 'evaluate': case 'exec': {
      if (!browserPage) throw new Error('Sem sessão ativa');
      const result = await browserPage.evaluate(params.script || params.code || 'null');
      return { result };
    }

    case 'cookies': {
      if (!browserCtx) return { cookies: [] };
      return { cookies: await browserCtx.cookies() };
    }

    case 'cookies.set': {
      if (!browserCtx) throw new Error('Sem sessão ativa');
      await browserCtx.addCookies([{
        name: params.name, value: params.value,
        url: params.url || browserPage?.url(), domain: params.domain, path: params.path || '/',
      }]);
      return { ok: true };
    }

    case 'cookies.clear': {
      if (!browserCtx) throw new Error('Sem sessão ativa');
      await browserCtx.clearCookies();
      return { ok: true };
    }

    case 'localStorage.get': {
      if (!browserPage) throw new Error('Sem sessão ativa');
      const val = await browserPage.evaluate(k => localStorage.getItem(k), params.key);
      return { value: val };
    }

    case 'localStorage.set': {
      if (!browserPage) throw new Error('Sem sessão ativa');
      await browserPage.evaluate(({ k, v }) => localStorage.setItem(k, v), { k: params.key, v: params.value });
      return { ok: true };
    }

    case 'tabs': {
      if (!browserCtx) return { tabs: [] };
      const pages = browserCtx.pages();
      const tabs = await Promise.all(pages.map(async (p, i) => ({
        index: i, url: p.url(), title: await p.title().catch(() => ''), active: p === browserPage,
      })));
      return { tabs };
    }

    case 'tab.new': {
      await ensureBrowser(params);
      const np = await browserCtx.newPage();
      if (params.url) await np.goto(params.url, { waitUntil: 'domcontentloaded' });
      browserPage = np;
      return { index: browserCtx.pages().indexOf(np), url: np.url() };
    }

    case 'tab.focus': {
      if (!browserCtx) throw new Error('Sem sessão ativa');
      const pages = browserCtx.pages();
      const idx = params.index ?? 0;
      if (idx >= pages.length) throw new Error('Tab não existe');
      browserPage = pages[idx];
      await browserPage.bringToFront();
      return { ok: true, url: browserPage.url() };
    }

    case 'tab.close': {
      if (!browserCtx) throw new Error('Sem sessão ativa');
      const pages = browserCtx.pages();
      const idx = params.index ?? 0;
      if (idx >= pages.length) throw new Error('Tab não existe');
      await pages[idx].close();
      browserPage = browserCtx.pages()[0] || null;
      return { ok: true };
    }

    // Ação genérica
    case 'act': {
      if (!browserPage) throw new Error('Sem sessão ativa');
      const type = params.type || params.kind;
      return browserAction(type, { ...params });
    }

    default:
      throw new Error(`Ação de browser desconhecida: ${action}`);
  }
}

// ─── HTTP local (porta gatewayPort+1) para testes diretos ─────────────────────
function startHttpServer() {
  const port = (config?.gatewayPort || 18791) + 1;
  const srv = http.createServer(async (req, res) => {
    const url = new URL(req.url, `http://localhost:${port}`);
    res.setHeader('Access-Control-Allow-Origin', '*');
    if (req.method === 'OPTIONS') { res.writeHead(204); res.end(); return; }

    let body = {};
    if (req.method === 'POST') {
      const chunks = [];
      for await (const c of req) chunks.push(c);
      try { body = JSON.parse(Buffer.concat(chunks).toString() || '{}'); } catch (_) {}
    }

    const ok  = (d) => { res.writeHead(200, { 'Content-Type': 'application/json' }); res.end(JSON.stringify(d)); };
    const err = (e, code = 500) => { res.writeHead(code, { 'Content-Type': 'application/json' }); res.end(JSON.stringify({ error: String(e) })); };

    try {
      const p = url.pathname;

      if (p === '/status') return ok({ connected, nodeName: config?.nodeName, nodeId: config?.nodeId });

      if (p === '/screen' || p === '/screenshot') {
        const buf = await captureScreen('jpg');
        const dims = jpegDims(buf);
        return ok({ base64: buf.toString('base64'), format: 'jpg', ...dims });
      }
      if (p === '/screen/record') return ok(await recordScreen(body));

      if (p === '/clipboard' && req.method === 'GET') return ok({ text: await clipRead() });
      if (p === '/clipboard' && req.method === 'POST') { await clipWrite(body.text || ''); return ok({ ok: true }); }

      if (p === '/notify') { notifyWindows(body.title || 'ClaudeNode', body.message || ''); return ok({ ok: true }); }

      if (p === '/shell') return ok(await runCmd(body.command || '', body.timeout));

      if (p === '/camera/list') return ok(await listCameras());
      if (p === '/camera/snap') return ok(await snapCamera(body));
      if (p === '/camera/clip') return ok(await clipCamera(body));

      if (p.startsWith('/browser')) {
        const action = body.action || (p === '/browser' ? 'status' : p.replace('/browser/', ''));
        return ok(await browserAction(action, body));
      }

      if (p === '/file/read')   return ok(await fileRead(body.path));
      if (p === '/file/write')  return ok(await fileWrite(body.path, body.content, body.encoding));
      if (p === '/file/list')   return ok(await fileList(body.path));
      if (p === '/file/exists') return ok(await fileExists(body.path));
      if (p === '/file/delete') return ok(await fileDelete(body.path));
      if (p === '/file/stat')   return ok(await fileStat(body.path));

      if (p === '/ping') return ok({ pong: true, ts: Date.now(), connected });

      err('Endpoint não encontrado', 404);
    } catch (e) { log(`HTTP erro: ${e.message}`); err(e.message); }
  });

  srv.listen(port, '0.0.0.0', () => log(`HTTP local: http://0.0.0.0:${port}`));
}

// ─── WebSocket Gateway ────────────────────────────────────────────────────────
function send(msg) {
  if (ws && ws.readyState === WebSocket.OPEN) ws.send(JSON.stringify(msg));
}

function sendResult(id, ok, data, error) {
  send({ type: 'res', id, ok, ...(ok ? { data } : { error: error || 'erro' }) });
}

async function handleCommand(id, cmd, params) {
  log(`CMD: ${cmd}`);
  try {
    let result;
    switch (cmd) {
      // ── Tela ──────────────────────────────────────────────────────────────
      case 'screen.capture': {
        const buf = await captureScreen('jpg');
        const dims = jpegDims(buf);
        if (buf.length > MAX_PAYLOAD) {
          const tmp = path.join(os.tmpdir(), `claude_ss_${Date.now()}.jpg`);
          fs.writeFileSync(tmp, buf);
          result = { path: tmp, ...dims, size: buf.length };
        } else {
          result = { base64: buf.toString('base64'), format: 'jpg', ...dims };
        }
        break;
      }
      case 'screen.record':
        result = await recordScreen(params);
        if (result.base64 && result.base64.length > MAX_PAYLOAD) {
          const tmp = path.join(os.tmpdir(), `claude_srec_${Date.now()}.mp4`);
          fs.writeFileSync(tmp, Buffer.from(result.base64, 'base64'));
          result = { path: tmp, size: result.size, duration: result.duration };
        }
        break;

      // ── Câmera ────────────────────────────────────────────────────────────
      case 'camera.list':    result = await listCameras(); break;
      case 'camera.snap':    result = await snapCamera(params); break;
      case 'camera.clip':
        result = await clipCamera(params);
        if (result.base64?.length > MAX_PAYLOAD) {
          const tmp = path.join(os.tmpdir(), `claude_clip_${Date.now()}.mp4`);
          fs.writeFileSync(tmp, Buffer.from(result.base64, 'base64'));
          result = { path: tmp, size: result.size, duration: result.duration };
        }
        break;

      // ── Clipboard ─────────────────────────────────────────────────────────
      case 'clipboard.read':  result = { text: await clipRead() }; break;
      case 'clipboard.write': await clipWrite(params?.text || ''); result = { ok: true }; break;

      // ── Shell ─────────────────────────────────────────────────────────────
      case 'shell.run': case 'system.run':
        result = await runCmd(params?.command || '', params?.timeout); break;

      // ── Arquivos ──────────────────────────────────────────────────────────
      case 'file.read':   result = await fileRead(params.path); break;
      case 'file.write':  result = await fileWrite(params.path, params.content, params.encoding); break;
      case 'file.list':   result = await fileList(params.path); break;
      case 'file.exists': result = await fileExists(params.path); break;
      case 'file.delete': result = await fileDelete(params.path); break;
      case 'file.stat':   result = await fileStat(params.path); break;

      // ── Notificação ───────────────────────────────────────────────────────
      case 'notify': notifyWindows(params?.title || 'ClaudeNode', params?.message || ''); result = { ok: true }; break;

      // ── Browser ───────────────────────────────────────────────────────────
      case 'browser':
        result = await browserAction(params?.action || 'status', params); break;
      // Atalhos diretos
      case 'browser.start':      result = await browserAction('start', params); break;
      case 'browser.stop':       result = await browserAction('stop', params); break;
      case 'browser.navigate':   result = await browserAction('navigate', params); break;
      case 'browser.screenshot': result = await browserAction('screenshot', params); break;
      case 'browser.snapshot':   result = await browserAction('snapshot', params); break;
      case 'browser.click':      result = await browserAction('click', params); break;
      case 'browser.type':       result = await browserAction('type', params); break;
      case 'browser.evaluate':   result = await browserAction('evaluate', params); break;
      case 'browser.cookies':    result = await browserAction('cookies', params); break;
      case 'browser.tabs':       result = await browserAction('tabs', params); break;

      // ── Sistema ───────────────────────────────────────────────────────────
      case 'ping': result = { pong: true, ts: Date.now(), nodeName: config?.nodeName }; break;

      default: throw new Error(`Comando desconhecido: ${cmd}`);
    }
    sendResult(id, true, result);
  } catch (e) {
    log(`Erro ${cmd}: ${e.message}`);
    sendResult(id, false, null, e.message);
  }
}

function handleMessage(raw) {
  let msg;
  try { msg = JSON.parse(raw); } catch (_) { return; }

  if (msg.type === 'auth.ok') {
    connected = true; lastStatus = 'Conectado';
    log(`Autenticado: ${config.nodeId}`);
    notifyWindows('ClaudeNode', 'Conectado ao servidor');
    writeStatus('connected', config.gatewayUrl);
    updateTrayStatus();
    return;
  }
  if (msg.type === 'auth.fail') {
    log('Auth rejeitada — verifique a senha');
    notifyWindows('ClaudeNode', 'Senha incorreta');
    ws.close(); return;
  }
  if (msg.type === 'cmd') handleCommand(msg.id, msg.cmd, msg.params || {});
}

function scheduleReconnect() {
  if (reconnectTimer) return;
  const delay = config?.reconnectInterval || 5000;
  log(`Reconectando em ${delay / 1000}s...`);
  reconnectTimer = setTimeout(() => { reconnectTimer = null; connect(); }, delay);
}

function connect() {
  if (!config) { loadConfig(); if (!config) return; }
  if (ws) { try { ws.terminate(); } catch (_) {} ws = null; }
  log(`Conectando a ${config.gatewayUrl}...`);
  lastStatus = 'Conectando...'; updateTrayStatus(); writeStatus('connecting', config.gatewayUrl);
  try {
    ws = new WebSocket(config.gatewayUrl);
    ws.on('open', () => {
      log('WS conectado — autenticando...');
      send({ type: 'auth', nodeId: config.nodeId, nodeName: config.nodeName || os.hostname(), password: config.password || '' });
    });
    ws.on('message', d => handleMessage(d.toString()));
    ws.on('close', code => {
      const was = connected; connected = false; lastStatus = 'Desconectado'; updateTrayStatus();
      writeStatus('disconnected', `code ${code}`);
      if (was) { log(`Desconectado (${code})`); notifyWindows('ClaudeNode', 'Conexão perdida'); }
      scheduleReconnect();
    });
    ws.on('error', e => { log(`WS erro: ${e.message}`); lastStatus = 'Erro de conexão'; updateTrayStatus(); });
  } catch (e) { log(`Erro ao conectar: ${e.message}`); scheduleReconnect(); }
}

function disconnect() {
  if (reconnectTimer) { clearTimeout(reconnectTimer); reconnectTimer = null; }
  if (ws) { try { ws.terminate(); } catch (_) {} ws = null; }
  connected = false; lastStatus = 'Desconectado'; updateTrayStatus(); writeStatus('disconnected', 'manual');
}

// ─── Startup Windows ──────────────────────────────────────────────────────────
const REG_KEY = 'HKCU\\Software\\Microsoft\\Windows\\CurrentVersion\\Run';
const REG_VAL = 'ClaudeNode';

function isStartupEnabled() {
  return new Promise(resolve => exec(`reg query "${REG_KEY}" /v "${REG_VAL}" 2>nul`, { windowsHide: true }, err => resolve(!err)));
}

async function toggleStartup() {
  const on = await isStartupEnabled();
  return new Promise((resolve, reject) => {
    const exe = process.execPath;
    const cmd = on
      ? `reg delete "${REG_KEY}" /v "${REG_VAL}" /f`
      : `reg add "${REG_KEY}" /v "${REG_VAL}" /t REG_SZ /d "\\"${exe}\\"" /f`;
    exec(cmd, { windowsHide: true }, err => err ? reject(err) : resolve(!on));
  });
}

// ─── Systray ──────────────────────────────────────────────────────────────────
function updateTrayStatus() {
  if (!systray || !systrayReady) return;
  systray.sendAction({ type: 'update-item', seq_id: 1, item: { title: connected ? '● Conectado' : `○ ${lastStatus}`, enabled: false } });
  systray.sendAction({ type: 'update-item', seq_id: 2, item: { title: '▶ Conectar', enabled: !connected } });
  systray.sendAction({ type: 'update-item', seq_id: 3, item: { title: '■ Desconectar', enabled: connected } });
}

function openLogs()   { fs.writeFileSync(LOG_PATH, logs.join('\n')); spawn('notepad', [LOG_PATH], { detached: true }); }
function openConfig() { spawn('notepad', [CONFIG_PATH], { detached: true }); }

// ─── Single instance ──────────────────────────────────────────────────────────
function checkSingleInstance() {
  if (fs.existsSync(LOCK_PATH)) {
    const pid = parseInt(fs.readFileSync(LOCK_PATH, 'utf8').trim());
    try { process.kill(pid, 0); console.log('Já rodando (PID: ' + pid + ')'); process.exit(0); }
    catch (_) {}
  }
  fs.writeFileSync(LOCK_PATH, String(process.pid));
}

function cleanupLock() {
  try { if (fs.existsSync(LOCK_PATH) && fs.readFileSync(LOCK_PATH, 'utf8').trim() === String(process.pid)) fs.unlinkSync(LOCK_PATH); } catch (_) {}
}

// ─── Main ─────────────────────────────────────────────────────────────────────
async function main() {
  checkSingleInstance();
  if (!loadConfig()) { console.error('config.json não encontrado — copie config.example.json'); process.exit(1); }

  // Ícone
  const icoPath = path.join(BASE_DIR, 'icon.ico');
  const icon = fs.existsSync(icoPath)
    ? fs.readFileSync(icoPath).toString('base64')
    : 'AAABAAEAEBAAAAEAIABoBAAAFgAAACgAAAAQAAAAIAAAAAEAIAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA==';

  const startupEnabled = await isStartupEnabled();

  systray = new SysTray({
    menu: {
      icon, title: '',
      tooltip: 'ClaudeNode — ${config.nodeName || config.nodeId}`,
      items: [
        { title: 'ClaudeNode — ${config.nodeName || config.nodeId}`, enabled: false },
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

  systray.onClick(async (a) => {
    switch (a.seq_id) {
      case 2: connect(); break;
      case 3: disconnect(); break;
      case 5: openConfig(); break;
      case 6: openLogs(); break;
      case 7: {
        const now = await toggleStartup().catch(() => null);
        if (now !== null) {
          systray.sendAction({ type: 'update-item', seq_id: 7, item: { title: now ? '[x] Iniciar com Windows' : '[ ] Iniciar com Windows', enabled: true } });
          notifyWindows('ClaudeNode', now ? 'Iniciará com o Windows' : 'Removido da inicialização');
        }
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

  startHttpServer();

  log('ClaudeNode iniciado — ${config.nodeId} → ${config.gatewayUrl}`);
  writeStatus('starting', config.gatewayUrl);

  // Recarregar config automaticamente
  let cfgWatcher;
  try { cfgWatcher = fs.watch(CONFIG_PATH, () => setTimeout(() => { loadConfig(); disconnect(); setTimeout(connect, 500); }, 300)); } catch (_) {}

  setTimeout(() => { systrayReady = true; updateTrayStatus(); connect(); }, 1000);
}

process.on('SIGINT', async () => { disconnect(); await closeBrowser(); cleanupLock(); process.exit(0); });
process.on('SIGTERM', async () => { disconnect(); await closeBrowser(); cleanupLock(); process.exit(0); });
process.on('exit', cleanupLock);

main().catch(e => { cleanupLock(); console.error('Erro fatal:', e); process.exit(1); });
