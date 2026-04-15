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
echo  Informe os dados do servidor ClaudeNode:
echo.

set /p GATEWAY_HOST=  Host (IP do servidor):
set /p GATEWAY_PORT=  Porta [18791]:
set /p SENHA=         Senha:
set /p NODE_NAME=     Nome deste PC [Meu PC]:

:: Valores padrao
if "%GATEWAY_PORT%"=="" set GATEWAY_PORT=18791
if "%NODE_NAME%"=="" set NODE_NAME=Meu PC

:: Gerar config.json linha a linha (sem depender de escapes complexos)
(
echo {
echo   "nodeId": "windows-pc",
echo   "nodeName": "%NODE_NAME%",
echo   "gatewayUrl": "ws://%GATEWAY_HOST%:%GATEWAY_PORT%",
echo   "password": "%SENHA%",
echo   "browser": {
echo     "executablePath": "C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe",
echo     "headless": false,
echo     "viewport": { "width": 1920, "height": 1080 }
echo   },
echo   "reconnectInterval": 5000
echo }
) > config.json

if exist config.json (
    echo.
    echo  [OK] config.json gerado com sucesso
) else (
    echo  [ERRO] Falha ao gerar config.json
    pause
    exit /b 1
)

echo.
echo  ==========================================
echo       Instalacao concluida!
echo  ==========================================
echo.
echo  Configurado:
echo    Servidor: %GATEWAY_HOST%:%GATEWAY_PORT%
echo    Nome:     %NODE_NAME%
echo.
echo  Execute INICIAR.bat para conectar.
echo.
pause
