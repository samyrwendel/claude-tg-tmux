#!/bin/bash
# Claude tmux watchdog — resolve QUALQUER prompt interativo
# Filosofia: se não é o prompt "❯" do Claude esperando input, é um bloqueio.
# Tenta Enter, Y, Esc — o que for necessário pra destravar.
#
# Variáveis esperadas (injetadas pelo systemd via EnvironmentFile):
#   CLAUDE_BIN        — caminho do binário claude (ex: ~/.npm-global/bin/claude)
#   CLAUDE_CHANNEL    — canal do plugin (ex: plugin:telegram@claude-plugins-official)
#   AGENTS_DIR        — diretório de agents (ex: ~/.claude/agents/mainbot)
#   HOME              — home do usuário

SESSION_NAME="mainbot"
CLAUDE_BIN="${CLAUDE_BIN:-$(which claude 2>/dev/null || echo "$HOME/.npm-global/bin/claude")}"
CLAUDE_CHANNEL="${CLAUDE_CHANNEL:-plugin:telegram@claude-plugins-official}"
AGENTS_DIR="${AGENTS_DIR:-$HOME/.claude/agents/mainbot}"
CLAUDE_ARGS="--channels $CLAUDE_CHANNEL --permission-mode bypassPermissions --dangerously-skip-permissions --add-dir $AGENTS_DIR"
CLAUDE_CMD="$CLAUDE_BIN $CLAUDE_ARGS"
WORK_DIR="$HOME"
LOG="/tmp/claude-watchdog.log"
MAX_LOG_LINES=500

export HOME="${HOME:-$(eval echo ~$(whoami))}"
export PATH="$HOME/.npm-global/bin:$HOME/.local/bin:/usr/local/bin:/usr/bin:/bin"
[ -s "$HOME/.nvm/nvm.sh" ] && source "$HOME/.nvm/nvm.sh"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG"; }

rotate_log() {
    if [ -f "$LOG" ] && [ "$(wc -l < "$LOG")" -gt "$MAX_LOG_LINES" ]; then
        tail -200 "$LOG" > "$LOG.tmp" && mv "$LOG.tmp" "$LOG"
    fi
}

pane() { /usr/bin/tmux capture-pane -t "$SESSION_NAME" -p 2>/dev/null; }

is_claude_active() {
    local content="$1"
    local tail5
    tail5=$(echo "$content" | tail -5)

    if echo "$content" | grep -qiE "Enter to confirm.*Esc to cancel|Yes, I trust this folder"; then
        return 1
    fi
    if echo "$content" | grep -qiE "Select login method|Paste code here"; then
        return 1
    fi

    echo "$tail5" | grep -qF "bypass permissions" && return 0
    echo "$tail5" | grep -qiE "thinking|tokens|✢|⏵|Actualizing|Razzle" && return 0
    echo "$tail5" | grep -qF "⎿" && return 0
    echo "$tail5" | grep -qE "^❯\s*$" && return 0

    return 1
}

resolve_prompt() {
    local content="$1"

    is_claude_active "$content" && return 1

    if echo "$content" | grep -qE "^\s*(❯\s*)?1\.\s+Yes|Do you want to (make this edit|proceed|overwrite)|Claude requested permissions to (edit|write|run)|Esc to cancel.*Tab to amend"; then
        /usr/bin/tmux send-keys -t "$SESSION_NAME" "1" Enter
        log "RESOLVED: Claude Code approval prompt (1. Yes)"
        return 0
    fi

    if echo "$content" | grep -qF "❯" && echo "$content" | grep -qiE "enter to confirm|esc to cancel"; then
        /usr/bin/tmux send-keys -t "$SESSION_NAME" Enter
        log "RESOLVED: selection prompt (enter to confirm)"
        return 0
    fi

    if echo "$content" | grep -qE "\(Y/n\)|\(y/N\)|\[Y/n\]|\[y/N\]|yes/no"; then
        /usr/bin/tmux send-keys -t "$SESSION_NAME" "Y" Enter
        log "RESOLVED: Y/n prompt"
        return 0
    fi

    if echo "$content" | grep -qiE "press enter|hit enter|continue\?|proceed\?|press any key|enter to continue"; then
        /usr/bin/tmux send-keys -t "$SESSION_NAME" Enter
        log "RESOLVED: press-enter prompt"
        return 0
    fi

    if echo "$content" | grep -qiE "do you trust|i trust this|trust this folder|allow access|grant perm|Is this a project you created|quick safety check"; then
        /usr/bin/tmux send-keys -t "$SESSION_NAME" "1" Enter
        log "RESOLVED: trust/permission prompt"
        return 0
    fi

    if echo "$content" | grep -qiE "update available|upgrade now|new version available"; then
        /usr/bin/tmux send-keys -t "$SESSION_NAME" Escape
        log "RESOLVED: update prompt (skipped)"
        return 0
    fi

    if echo "$content" | grep -qiE "migrat|convert|upgrade.*config"; then
        /usr/bin/tmux send-keys -t "$SESSION_NAME" Enter
        log "RESOLVED: migration prompt"
        return 0
    fi

    if echo "$content" | grep -qiE "retry\?|try again\?|reconnect\?"; then
        /usr/bin/tmux send-keys -t "$SESSION_NAME" Enter
        log "RESOLVED: retry prompt"
        return 0
    fi

    if echo "$content" | grep -qiE "OAuth.*expired|token.*expired|401.*auth|Please run /login|Select login method|Paste code here"; then
        log "OAuth issue detected — reauth-listener handles this"
        return 1
    fi

    return 2
}

ensure_session() {
    if ! /usr/bin/tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
        log "Creating tmux session..."
        /usr/bin/tmux new-session -d -s "$SESSION_NAME" -c "$WORK_DIR" "$CLAUDE_BIN" $CLAUDE_ARGS
    fi
}

startup_watch() {
    log "Startup watch..."
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
PREV_SCREEN=""
STUCK_COUNT=0
STUCK_THRESHOLD=3

while true; do
    sleep 30
    rotate_log

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

    if echo "$CONTENT" | grep -qE "Do you want to proceed\?|Would you like to proceed\?|ready to execute\. Would you like to proceed|Do you want to allow Claude to fetch|Do you want to allow this connection|Do you want to use this API key|Allow external CLAUDE\.md file imports|requested permissions to edit.*sensitive file"; then
        /usr/bin/tmux send-keys -t "$SESSION_NAME" "1" Enter
        log "RESOLVED (priority): blocking proceed/allow prompt"
        STUCK_COUNT=0
        PREV_SCREEN=""
        continue
    fi

    resolve_prompt "$CONTENT"
    RC=$?

    if [ "$RC" -eq 0 ]; then
        STUCK_COUNT=0
        PREV_SCREEN=""
        continue
    fi

    if [ "$RC" -eq 1 ]; then
        STUCK_COUNT=0
        PREV_SCREEN=""
        continue
    fi

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

    if echo "$CONTENT" | tail -3 | grep -qE "^\$\s*$|^clawd@|^root@|^[a-z].*@.*\$\s*$"; then
        log "Claude process died, restarting inside tmux..."
        /usr/bin/tmux send-keys -t "$SESSION_NAME" "$CLAUDE_CMD" Enter
        startup_watch
        STUCK_COUNT=0
        PREV_SCREEN=""
        continue
    fi

    # Detecta Claude ativo mas sem plugin Telegram no histórico do pane
    # (Node.js sobrescreve /proc/cmdline — não tem como ler args originais)
    if is_claude_active "$CONTENT"; then
        PANE_HISTORY=$(/usr/bin/tmux capture-pane -t "$SESSION_NAME" -p -S -500 2>/dev/null)
        if ! echo "$PANE_HISTORY" | grep -q "plugin:telegram"; then
            log "WARNING: Claude ativo mas sem plugin Telegram no histórico — reiniciando..."
            /usr/bin/tmux send-keys -t "$SESSION_NAME" C-c
            sleep 2
            # Verifica se Claude realmente parou (shell prompt apareceu)
            POST_KILL=$(/usr/bin/tmux capture-pane -t "$SESSION_NAME" -p 2>/dev/null)
            if ! echo "$POST_KILL" | tail -3 | grep -qE "^\$\s*$|^clawd@|^root@|^[a-z][a-z0-9_-]*@"; then
                # C-c não funcionou — força segunda tentativa
                log "C-c não matou Claude — tentando novamente..."
                /usr/bin/tmux send-keys -t "$SESSION_NAME" C-c
                sleep 2
            fi
            /usr/bin/tmux send-keys -t "$SESSION_NAME" "$CLAUDE_CMD" Enter
            startup_watch
            STUCK_COUNT=0
            PREV_SCREEN=""
        fi
    fi
done
