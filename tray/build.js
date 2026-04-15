// build.js — gera ClaudeNode.exe para Windows
// Uso: node build.js
'use strict';

const { execSync, spawnSync } = require('child_process');
const fs = require('fs');
const path = require('path');

const DIST = path.join(__dirname, 'dist');
const OUT  = path.join(DIST, 'ClaudeNode.exe');

function run(cmd, opts = {}) {
  console.log('$', cmd);
  execSync(cmd, { stdio: 'inherit', ...opts });
}

function copyDir(src, dst) {
  fs.mkdirSync(dst, { recursive: true });
  for (const f of fs.readdirSync(src)) {
    const s = path.join(src, f), d = path.join(dst, f);
    fs.statSync(s).isDirectory() ? copyDir(s, d) : fs.copyFileSync(s, d);
  }
}

// 1. Limpar dist
fs.rmSync(DIST, { recursive: true, force: true });
fs.mkdirSync(DIST, { recursive: true });

// 2. Compilar com pkg
run(`npx pkg index.js --target node18-win-x64 --output "${OUT}"`, { cwd: __dirname });

// 3. Copiar módulos nativos necessários
for (const mod of ['screenshot-desktop', 'systray2', 'node-notifier']) {
  const src = path.join(__dirname, 'node_modules', mod);
  if (fs.existsSync(src)) {
    copyDir(src, path.join(DIST, 'node_modules', mod));
    console.log(`✓ ${mod}`);
  }
}

// 4. Copiar ícone e config de exemplo
for (const f of ['icon.ico', 'config.example.json']) {
  const src = path.join(__dirname, f);
  if (fs.existsSync(src)) fs.copyFileSync(src, path.join(DIST, f));
}

// 5. Criar launchers
fs.writeFileSync(path.join(DIST, 'ClaudeNode.bat'), `@echo off\nstart "" ClaudeNode.exe\n`);
fs.writeFileSync(path.join(DIST, 'ClaudeNode-debug.bat'),
  `@echo off\ntitle Clawd Tray\nClaudeNode.exe\npause\n`);
fs.writeFileSync(path.join(DIST, 'ClaudeNode.vbs'),
  `Set WshShell = CreateObject("WScript.Shell")\nWshShell.Run """ClaudeNode.exe""", 0, False\n`);

// 6. Criar config.json de exemplo em dist se não existir
const distConfig = path.join(DIST, 'config.json');
if (!fs.existsSync(distConfig)) {
  fs.copyFileSync(path.join(__dirname, 'config.example.json'), distConfig);
}

// 7. Aplicar ícone com rcedit (se disponível)
try {
  const ico = path.join(DIST, 'icon.ico');
  if (fs.existsSync(ico)) {
    run(`npx rcedit "${OUT}" --set-icon "${ico}"`, { cwd: __dirname });
    console.log('✓ ícone aplicado');
  }
} catch (_) {
  console.log('⚠ rcedit não disponível — ícone não aplicado');
}

console.log('\n✅ Build concluído!');
console.log(`   Executável: dist/ClaudeNode.exe`);
console.log(`   Edite dist/config.json antes de distribuir`);
