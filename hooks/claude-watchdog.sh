#!/bin/bash
# Claude tmux watchdog — resolve QUALQUER prompt interativo
# Filosofia: se não é o prompt "❯" do Claude esperando input, é um bloqueio.
# Tenta Enter, Y, Esc — o que for necessário pra destravar.

SESSION_NAME="mainbot"
CLAUDE_CMD="/home/clawd/.npm-global/bin/claude --channels plugin:telegram@claude-plugins-official --permission-mode bypassPermissions --dangerously-skip-permissions"
WORK_DIR="/home/clawd"
LOG="/tmp/claude-watchdog.log"
MAX_LOG_LINES=500

export HOME="/home/clawd"
export PATH="/home/clawd/.npm-global/bin:/home/clawd/.local/bin:/usr/local/bin:/usr/bin:/bin"
[ -s "$HOME/.nvm/nvm.sh" ] && source "$HOME/.nvm/nvm.sh"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG"; }

# Rotaciona log pra não crescer infinito
rotate_log() {
    if [ -f "$LOG" ] && [ "$(wc -l < "$LOG")" -gt "$MAX_LOG_LINES" ]; then
        tail -200 "$LOG" > "$LOG.tmp" && mv "$LOG.tmp" "$LOG"
    fi
}

pane() { /usr/bin/tmux capture-pane -t "$SESSION_NAME" -p 2>/dev/null; }

# Detecta se Claude está no estado normal de operação (pronto ou processando)
is_claude_active() {
    local content="$1"
    local tail5
    tail5=$(echo "$content" | tail -5)

    # FIRST: check for known blocking prompts — these are NOT active
    if echo "$content" | grep -qiE "Enter to confirm.*Esc to cancel|Yes, I trust this folder"; then
        return 1
    fi
    if echo "$content" | grep -qiE "Select login method|Paste code here"; then
        return 1
    fi

    # ❯ followed by bypass permissions = real Claude prompt
    echo "$tail5" | grep -qF "bypass permissions" && return 0

    # Processando (spinner, thinking, tool use)
    echo "$tail5" | grep -qiE "thinking|tokens|✢|⏵|Actualizing|Razzle" && return 0

    # Tool output
    echo "$tail5" | grep -qF "⎿" && return 0

    # ❯ alone on a line (Claude input prompt, but only if no blocking prompt above)
    echo "$tail5" | grep -qE "^❯\s*$" && return 0

    return 1
}

# Detecta se é um prompt interativo bloqueante e resolve
# Retorna: 0 = resolveu algo, 1 = nada pra resolver
resolve_prompt() {
    local content="$1"

    # Se Claude tá ativo/processando, não mexer
    is_claude_active "$content" && return 1

    # --- PATTERNS ESPECÍFICOS (resposta otimizada) ---

    # Claude Code: "1. Yes" prompt (Edit/Write/overwrite/proceed)
    if echo "$content" | grep -qE "^\s*(❯\s*)?1\.\s+Yes|Do you want to (make this edit|proceed|overwrite)|Claude requested permissions to (edit|write|run)|Esc to cancel.*Tab to amend"; then
        /usr/bin/tmux send-keys -t "$SESSION_NAME" "1" Enter
        log "RESOLVED: Claude Code approval prompt (1. Yes)"
        return 0
    fi

    # Seleção com ❯ + confirmação (trust folder, etc) → Enter
    if echo "$content" | grep -qF "❯" && echo "$content" | grep -qiE "enter to confirm|esc to cancel"; then
        /usr/bin/tmux send-keys -t "$SESSION_NAME" Enter
        log "RESOLVED: selection prompt (enter to confirm)"
        return 0
    fi

    # Y/n ou y/N explícito → Y + Enter
    if echo "$content" | grep -qE "\(Y/n\)|\(y/N\)|\[Y/n\]|\[y/N\]|yes/no"; then
        /usr/bin/tmux send-keys -t "$SESSION_NAME" "Y" Enter
        log "RESOLVED: Y/n prompt"
        return 0
    fi

    # "Press enter" / "hit enter" / "continue?" / "proceed?"
    if echo "$content" | grep -qiE "press enter|hit enter|continue\?|proceed\?|press any key|enter to continue"; then
        /usr/bin/tmux send-keys -t "$SESSION_NAME" Enter
        log "RESOLVED: press-enter prompt"
        return 0
    fi

    # Trust / permission / confirm (Claude Code trust folder prompt)
    if echo "$content" | grep -qiE "do you trust|i trust this|trust this folder|allow access|grant perm|Is this a project you created|quick safety check"; then
        /usr/bin/tmux send-keys -t "$SESSION_NAME" "1" Enter
        log "RESOLVED: trust/permission prompt"
        return 0
    fi

    # Update available → Esc (skip)
    if echo "$content" | grep -qiE "update available|upgrade now|new version available"; then
        /usr/bin/tmux send-keys -t "$SESSION_NAME" Escape
        log "RESOLVED: update prompt (skipped)"
        return 0
    fi

    # Migration / conversion
    if echo "$content" | grep -qiE "migrat|convert|upgrade.*config"; then
        /usr/bin/tmux send-keys -t "$SESSION_NAME" Enter
        log "RESOLVED: migration prompt"
        return 0
    fi

    # Error with retry option
    if echo "$content" | grep -qiE "retry\?|try again\?|reconnect\?"; then
        /usr/bin/tmux send-keys -t "$SESSION_NAME" Enter
        log "RESOLVED: retry prompt"
        return 0
    fi

    # OAuth expired — handled by reauth-listener.service, don't interfere
    if echo "$content" | grep -qiE "OAuth.*expired|token.*expired|401.*auth|Please run /login|Select login method|Paste code here"; then
        log "OAuth issue detected — reauth-listener handles this"
        return 1  # report as "active" so watchdog doesn't try to fix it
    fi

    # --- CATCH-ALL: tela parada que não é Claude ativo ---
    # Se chegou aqui, a tela não é Claude ativo E não matchou nenhum pattern.
    # Pode ser um prompt desconhecido. Tenta Enter como fallback.
    # Mas só se a tela ficou igual por 2 checks seguidos (evita falso positivo).
    return 2  # sinaliza "suspeito mas não resolvido"
}

ensure_session() {
    if ! /usr/bin/tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
        log "Creating tmux session..."
        /usr/bin/tmux new-session -d -s "$SESSION_NAME" -c "$WORK_DIR" "$CLAUDE_CMD"
    fi
}

startup_watch() {
    log "Startup watch..."
    # Wait minimum 8s for UI to fully render before declaring ready
    local MIN_READY_ITER=4
    for i in $(seq 1 30); do
        sleep 2
        /usr/bin/tmux has-session -t "$SESSION_NAME" 2>/dev/null || { ensure_session; continue; }
        local content=$(pane)
        resolve_prompt "$content"
        local rc=$?
        [ "$rc" -eq 0 ] && continue
        if [ "$i" -ge "$MIN_READY_ITER" ] && is_claude_active "$content"; then
            log "Claude ready after $((i*2))s"
            return 0
        fi
    done
    log "WARNING: startup watch ended without ready state"
}

###############################################################################
# MAIN LOOP
###############################################################################
log "=== WATCHDOG STARTED (PID $$) ==="

ensure_session
startup_watch

CONSECUTIVE_DEAD=0
PREV_SCREEN=""        # pra detectar tela travada
STUCK_COUNT=0         # quantas vezes a tela ficou idêntica
STUCK_THRESHOLD=3     # após 3 checks iguais (~90s), força Enter

while true; do
    sleep 30
    rotate_log

    # Sessão tmux existe?
    if ! /usr/bin/tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
        CONSECUTIVE_DEAD=$((CONSECUTIVE_DEAD + 1))
        log "Session not found (count: $CONSECUTIVE_DEAD)"
        if [ "$CONSECUTIVE_DEAD" -ge 2 ]; then
            log "Restarting session..."
            ensure_session
            startup_watch
            CONSECUTIVE_DEAD=0
            STUCK_COUNT=0
            PREV_SCREEN=""
        fi
        continue
    fi

    CONSECUTIVE_DEAD=0
    CONTENT=$(pane)

    # Prompts críticos: resolver IMEDIATAMENTE, independente de estar "ativo"
    if echo "$CONTENT" | grep -qE "Do you want to proceed\?|Would you like to proceed\?|ready to execute\. Would you like to proceed|Do you want to allow Claude to fetch|Do you want to allow this connection|Do you want to use this API key|Allow external CLAUDE\.md file imports|requested permissions to edit.*sensitive file"; then
        /usr/bin/tmux send-keys -t "$SESSION_NAME" "1" Enter
        log "RESOLVED (priority): blocking proceed/allow prompt"
        STUCK_COUNT=0
        PREV_SCREEN=""
        continue
    fi

    # Tenta resolver prompt conhecido
    resolve_prompt "$CONTENT"
    RC=$?

    if [ "$RC" -eq 0 ]; then
        # Resolveu — reset stuck counter
        STUCK_COUNT=0
        PREV_SCREEN=""
        continue
    fi

    if [ "$RC" -eq 1 ]; then
        # Claude ativo, tudo ok
        STUCK_COUNT=0
        PREV_SCREEN=""
        continue
    fi

    # RC=2: suspeito. Verifica se tá travado (tela idêntica por múltiplos checks)
    # Normalizar: remover escape ANSI e chars de controle antes do hash
    # Evita falso negativo quando cursor piscando muda o hash
    CURRENT_HASH=$(echo "$CONTENT" | sed 's/\x1b\[[0-9;]*[mGKHF]//g' | tr -d '\r' | md5sum | cut -d' ' -f1)
    if [ "$CURRENT_HASH" = "$PREV_SCREEN" ]; then
        STUCK_COUNT=$((STUCK_COUNT + 1))
        log "Screen unchanged (stuck count: $STUCK_COUNT/$STUCK_THRESHOLD)"

        if [ "$STUCK_COUNT" -ge "$STUCK_THRESHOLD" ]; then
            log "STUCK DETECTED — forcing Enter as fallback"
            /usr/bin/tmux send-keys -t "$SESSION_NAME" Enter
            STUCK_COUNT=0
            PREV_SCREEN=""
        fi
    else
        STUCK_COUNT=0
        PREV_SCREEN="$CURRENT_HASH"
    fi

    # Detecta processo Claude morto dentro do tmux (shell prompt visível)
    if echo "$CONTENT" | tail -3 | grep -qE "^\\\$\s*$|^clawd@|^root@"; then
        log "Claude process died, restarting inside tmux..."
        /usr/bin/tmux send-keys -t "$SESSION_NAME" "$CLAUDE_CMD" Enter
        startup_watch
        STUCK_COUNT=0
        PREV_SCREEN=""
    fi
done
