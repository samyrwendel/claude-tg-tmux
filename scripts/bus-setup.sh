#!/bin/bash
# bus-setup.sh — cria estrutura de diretórios do barramento multi-agent
# Idempotente: pode rodar múltiplas vezes sem problema

BUS_DIR="${HOME}/.claude/bus"

mkdir -p "${BUS_DIR}/tasks"
mkdir -p "${BUS_DIR}/status"
mkdir -p "${BUS_DIR}/promises"

echo "[bus-setup] Estrutura criada em ${BUS_DIR}"
ls -la "${BUS_DIR}"
