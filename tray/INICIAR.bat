@echo off
chcp 65001 >nul
title ClaudeNode

if not exist config.json (
    echo  [ERRO] config.json nao encontrado. Execute INSTALAR.bat primeiro.
    pause
    exit /b 1
)

echo  Iniciando ClaudeNode...
node index.js
pause
