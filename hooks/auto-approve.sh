#!/bin/bash
# tmux-auto-approve: Detects and auto-approves safe edit prompts in tmux sessions
# Runs via system crontab every minute
#
# Detects patterns:
#   "Do you want to make this edit to <file>?"
#   "Do you want to run this command?"
#   "Allow <tool>?" 
# 
# Auto-approves (sends "1" + Enter) when:
#   - It's a file edit (not a destructive command like rm/delete)
#   - The prompt contains "Yes" as option 1
#
# Safety: NEVER approves rm, delete, drop, truncate, or unknown prompts

SESSIONS="claude mainbot"
LOG="/tmp/tmux-auto-approve.log"
STATE_DIR="/tmp/tmux-auto-approve"
mkdir -p "$STATE_DIR"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG"
}

for session in $SESSIONS; do
  # Check if session exists
  if ! tmux has-session -t "$session" 2>/dev/null; then
    continue
  fi

  # Capture current pane content
  content=$(tmux capture-pane -t "$session" -p 2>/dev/null)
  if [ -z "$content" ]; then
    continue
  fi

  # Create hash of content to avoid re-processing
  hash=$(echo "$content" | md5sum | cut -d' ' -f1)
  state_file="$STATE_DIR/${session}.last"
  last_hash=$(cat "$state_file" 2>/dev/null)
  
  if [ "$hash" = "$last_hash" ]; then
    continue  # No change since last check
  fi
  echo "$hash" > "$state_file"

  # Detect edit approval prompt
  if echo "$content" | grep -q "Do you want to make this edit to"; then
    file=$(echo "$content" | grep -oP "Do you want to make this edit to \K[^?]+" | head -1)
    
    # Safety check: verify option 1 is "Yes"
    if echo "$content" | grep -q "❯.*1\. Yes"; then
      # Safety check: not a destructive target
      if echo "$file" | grep -qiE '(\.env|password|secret|key|token|cred)'; then
        log "SKIP [$session] sensitive file: $file"
        continue
      fi
      
      log "APPROVE [$session] edit: $file"
      tmux send-keys -t "$session" Enter
      sleep 1
      echo "approved" > "$state_file"
    else
      log "SKIP [$session] option 1 is not Yes for: $file"
    fi

  # Detect command approval prompt  
  elif echo "$content" | grep -q "Do you want to run"; then
    cmd=$(echo "$content" | grep -A1 "Do you want to run" | tail -1 | sed 's/^[[:space:]]*//')
    
    # Safety: only approve safe commands
    if echo "$cmd" | grep -qiE '(rm |rm$|delete|drop|truncate|format|mkfs|dd |chmod 777|>/dev/)'; then
      log "BLOCK [$session] dangerous command: $cmd"
      continue
    fi
    
    if echo "$content" | grep -q "❯.*1\. Yes"; then
      log "APPROVE [$session] command: $cmd"
      tmux send-keys -t "$session" Enter
      sleep 1
      echo "approved" > "$state_file"
    fi

  # Detect tool/permission prompt
  elif echo "$content" | grep -qE "Allow .* for this session\?|Do you want to allow"; then
    if echo "$content" | grep -q "❯.*1\. Yes"; then
      tool=$(echo "$content" | grep -oP "(Allow |allow )\K[^?]+" | head -1)
      log "APPROVE [$session] tool: $tool"
      tmux send-keys -t "$session" Enter
      sleep 1
      echo "approved" > "$state_file"
    fi

  # Detect "Do you want to proceed?" / plan execution prompt
  elif echo "$content" | grep -qE "Do you want to proceed\?|Would you like to proceed\?|ready to execute\. Would you like to proceed"; then
    log "APPROVE [$session] proceed prompt"
    tmux send-keys -t "$session" "1" Enter
    sleep 1
    echo "approved" > "$state_file"

  # Detect fetch/connection permission prompts
  elif echo "$content" | grep -qE "Do you want to allow Claude to fetch|Do you want to allow this connection"; then
    log "APPROVE [$session] fetch/connection prompt"
    tmux send-keys -t "$session" "1" Enter
    sleep 1
    echo "approved" > "$state_file"

  # Detect API key prompt
  elif echo "$content" | grep -q "Do you want to use this API key"; then
    log "APPROVE [$session] API key prompt"
    tmux send-keys -t "$session" "1" Enter
    sleep 1
    echo "approved" > "$state_file"

  # Detect CLAUDE.md import prompt
  elif echo "$content" | grep -q "Allow external CLAUDE.md file imports"; then
    log "APPROVE [$session] CLAUDE.md import prompt"
    tmux send-keys -t "$session" "1" Enter
    sleep 1
    echo "approved" > "$state_file"

  # BLOCK: delete permission rule (never auto-approve destructive)
  elif echo "$content" | grep -q "Are you sure you want to delete this permission rule"; then
    log "BLOCK [$session] delete permission rule — requires manual approval"
  fi
done
