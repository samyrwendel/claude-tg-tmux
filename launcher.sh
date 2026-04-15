#!/bin/bash
# claude-tg-tmux launcher — inicia Claude CLI em sessão tmux persistente
# Gerenciado pelo systemd (mainbot.service)

set -a
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -f "$SCRIPT_DIR/.env" ] && source "$SCRIPT_DIR/.env"
set +a

SESSION_NAME="${SESSION_NAME:-mainbot}"
CLAUDE_BIN="${CLAUDE_BIN:-$(which claude)}"
HEALTH_INTERVAL=60

export HOME="${HOME:-/home/$USER}"
export PATH="$HOME/.npm-global/bin:$HOME/.local/bin:/usr/local/bin:/usr/bin:/bin"
[ -s "$HOME/.nvm/nvm.sh" ] && source "$HOME/.nvm/nvm.sh"

cleanup() {
    /usr/bin/tmux kill-session -t "$SESSION_NAME" 2>/dev/null
}
trap cleanup EXIT TERM INT

/usr/bin/tmux kill-session -t "$SESSION_NAME" 2>/dev/null

/usr/bin/tmux new-session -d -s "$SESSION_NAME" -c "${WORKSPACE:-$HOME}" \
    "$CLAUDE_BIN" --channels "plugin:telegram@claude-plugins-official" \
    --permission-mode bypassPermissions --dangerously-skip-permissions \
    --add-dir /home/clawd/.claude/agents/mainbot

sleep 5
/usr/bin/tmux send-keys -t "$SESSION_NAME" Enter 2>/dev/null

# Health loop — se o processo morrer, sai com erro e systemd reinicia
while true; do
    sleep "$HEALTH_INTERVAL"

    if ! /usr/bin/tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
        echo "tmux session '$SESSION_NAME' died" >&2
        exit 1
    fi

    PANE_PID=$(/usr/bin/tmux list-panes -t "$SESSION_NAME" -F '#{pane_pid}' 2>/dev/null)
    if [ -z "$PANE_PID" ] || ! kill -0 "$PANE_PID" 2>/dev/null; then
        echo "claude process (pane PID $PANE_PID) not found" >&2
        exit 1
    fi
done
