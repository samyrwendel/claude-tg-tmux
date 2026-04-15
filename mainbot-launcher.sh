#!/bin/bash
# mainbot-launcher.sh — inicia sessão tmux mainbot (@dgenmainbot)
# Manages Claude CLI in tmux, monitors health, exits on failure → systemd restarts

SESSION_NAME="mainbot"
CLAUDE_BIN="/home/clawd/.npm-global/bin/claude"
HEALTH_INTERVAL=60

export HOME="/home/clawd"
export PATH="/home/clawd/.npm-global/bin:/home/clawd/.local/bin:/usr/local/bin:/usr/bin:/bin"
[ -s "$HOME/.nvm/nvm.sh" ] && source "$HOME/.nvm/nvm.sh"

cleanup() {
    /usr/bin/tmux kill-session -t "$SESSION_NAME" 2>/dev/null
}
trap cleanup EXIT TERM INT

# Kill any stale session
/usr/bin/tmux kill-session -t "$SESSION_NAME" 2>/dev/null

# Start Claude CLI in tmux (needs PTY)
/usr/bin/tmux new-session -d -s "$SESSION_NAME" -c "$HOME" \
    "$CLAUDE_BIN" --channels "plugin:telegram@claude-plugins-official" \
    --permission-mode bypassPermissions --dangerously-skip-permissions \
    --add-dir /home/clawd/.claude/agents/mainbot

# Auto-accept trust prompt
sleep 5
/usr/bin/tmux send-keys -t "$SESSION_NAME" Enter 2>/dev/null

# Health monitor loop — if Claude dies, this exits → systemd restarts us
while true; do
    sleep "$HEALTH_INTERVAL"

    # Check tmux session exists
    if ! /usr/bin/tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
        echo "tmux session '$SESSION_NAME' died" >&2
        exit 1
    fi

    # Check Claude process alive via tmux pane PID
    PANE_PID=$(/usr/bin/tmux list-panes -t "$SESSION_NAME" -F '#{pane_pid}' 2>/dev/null)
    if [ -z "$PANE_PID" ] || ! kill -0 "$PANE_PID" 2>/dev/null; then
        echo "claude process (pane PID $PANE_PID) not found" >&2
        exit 1
    fi
done
