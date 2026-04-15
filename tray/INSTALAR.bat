@echo off
chcp 65001 >nul
title ClaudeNode — Instalador

echo.
echo  ╔══════════════════════════════════════╗
echo  ║        ClaudeNode — Instalador       ║
echo  ╚══════════════════════════════════════╝
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

:: Criar config.json se nao existir
echo.
echo  [3/3] Configurando...
if not exist config.json (
    copy config.example.json config.json >nul
    echo  [OK] config.json criado a partir do exemplo
) else (
    echo  [OK] config.json ja existe, mantido
)

echo.
echo  ╔══════════════════════════════════════╗
echo  ║         Instalacao concluida!        ║
echo  ╚══════════════════════════════════════╝
echo.
echo  Proximo passo:
echo    1. Abra o arquivo config.json
echo    2. Configure a senha (password)
echo    3. Confirme o gatewayUrl: ws://100.66.236.96:18791
echo    4. Salve e execute: INICIAR.bat
echo.

:: Abrir config.json para editar
echo  Abrindo config.json para configurar...
timeout /t 2 >nul
notepad config.json

pause
