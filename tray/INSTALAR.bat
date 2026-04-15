@echo off
title ClaudeNode - Instalador

echo.
echo  ==========================================
echo       ClaudeNode - Instalador
echo  ==========================================
echo.

:: Verificar Node.js
node --version >nul 2>&1
if errorlevel 1 (
    echo  [ERRO] Node.js nao encontrado!
    echo.
    echo  Instale o Node.js 18+ em: https://nodejs.org
    echo  Depois execute este instalador novamente.
    echo.
    pause
    exit /b 1
)
for /f "tokens=*" %%v in ('node --version') do echo  [OK] Node.js %%v

:: Instalar dependencias
echo.
echo  [1/3] Instalando dependencias...
call npm install
if errorlevel 1 (
    echo  [ERRO] Falha ao instalar dependencias.
    pause
    exit /b 1
)
echo  [OK] Dependencias instaladas

:: Instalar Chromium
echo.
echo  [2/3] Instalando Chromium (Playwright)...
call npx playwright install chromium
if errorlevel 1 (
    echo  [AVISO] Falha ao instalar Chromium. Browser nao estara disponivel.
) else (
    echo  [OK] Chromium instalado
)

:: Configuracao interativa
echo.
echo  [3/3] Configuracao
echo  ==========================================
echo.

set /p GATEWAY_HOST=  Host do servidor (ex: 100.66.236.96):
set /p GATEWAY_PORT=  Porta (padrao 18791, Enter para manter):
set /p SENHA=         Senha:
set /p NODE_NAME=     Nome deste PC (ex: PC do Samyr):

:: Porta padrao
if "%GATEWAY_PORT%"=="" set GATEWAY_PORT=18791

:: Nome padrao
if "%NODE_NAME%"=="" set NODE_NAME=PC Windows

:: Gerar config.json via node (evita problemas de escape no bat)
node -e "
var fs = require('fs');
var cfg = {
  nodeId: 'windows-pc',
  nodeName: '%NODE_NAME%',
  gatewayUrl: 'ws://%GATEWAY_HOST%:%GATEWAY_PORT%',
  password: '%SENHA%',
  browser: {
    executablePath: 'C:\\\\Program Files\\\\Google\\\\Chrome\\\\Application\\\\chrome.exe',
    headless: false,
    viewport: { width: 1920, height: 1080 }
  },
  reconnectInterval: 5000
};
fs.writeFileSync('config.json', JSON.stringify(cfg, null, 2));
console.log('  [OK] config.json gerado');
"

echo.
echo  ==========================================
echo       Instalacao concluida!
echo  ==========================================
echo.
echo  Configurado:
echo    Host:  %GATEWAY_HOST%:%GATEWAY_PORT%
echo    Node:  %NODE_NAME%
echo.
echo  Para conectar execute: INICIAR.bat
echo.
pause
