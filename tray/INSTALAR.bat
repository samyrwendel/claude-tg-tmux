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
echo  ==========================================
echo       Instalacao concluida!
echo  ==========================================
echo.
echo  Proximo passo:
echo    1. O config.json vai abrir no Bloco de Notas
echo    2. Troque COLOQUE_A_SENHA_AQUI pela senha combinada
echo    3. Ajuste o caminho do Chrome se necessario
echo    4. Salve (Ctrl+S) e feche
echo    5. Execute INICIAR.bat para conectar
echo.
echo  SENHA: pergunte ao Samyr qual senha foi configurada no servidor.
echo.

:: Abrir config.json para editar
echo  Abrindo config.json...
timeout /t 2 >nul
notepad config.json

pause
