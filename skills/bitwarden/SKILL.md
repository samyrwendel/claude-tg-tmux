---
name: bitwarden
description: Set up and use Bitwarden CLI (bw). Use when signing in, unlocking vault, reading/creating/updating passwords, generating passwords, or managing vault items.
homepage: https://bitwarden.com/help/cli/
metadata: {"clawdbot":{"emoji":"🔒","requires":{"bins":["bw"]}}}
---

# Bitwarden CLI

Manage passwords and secrets using the Bitwarden CLI.

## Quick Reference

### Authentication Flow

1. **Login** (once per device):
   ```bash
   bw login email@example.com
   ```

2. **Unlock** (each session - returns session key):
   ```bash
   export BW_SESSION=$(bw unlock --raw)
   ```

3. **Verify**:
   ```bash
   bw status
   ```

### Common Commands

```bash
# List all items
bw list items

# Search items
bw list items --search "github"

# Get specific item
bw get item "item-name-or-id"

# Get password only
bw get password "item-name-or-id"

# Get username only
bw get username "item-name-or-id"

# Get TOTP code
bw get totp "item-name-or-id"

# Generate password
bw generate -ulns --length 20

# Create new login
bw get template item | jq '.name="New Item" | .login.username="user" | .login.password="pass"' | bw encode | bw create item

# Sync vault
bw sync
```

## Workflow

1. Check if CLI present: `bw --version`
2. Check status: `bw status` (locked/unlocked/unauthenticated)
3. If unauthenticated: `bw login`
4. If locked: unlock and export session
5. Always use `BW_SESSION` env var for commands

## REQUIRED tmux session

The Bitwarden session key must persist. Use tmux:

```bash
SOCKET_DIR="${CLAWDBOT_TMUX_SOCKET_DIR:-${TMPDIR:-/tmp}/clawdbot-tmux-sockets}"
mkdir -p "$SOCKET_DIR"
SOCKET="$SOCKET_DIR/clawdbot-bw.sock"
SESSION="bw-session-$(date +%Y%m%d-%H%M%S)"

tmux -S "$SOCKET" new -d -s "$SESSION" -n shell
tmux -S "$SOCKET" send-keys -t "$SESSION":0.0 -- 'export BW_SESSION=$(bw unlock --raw)' Enter
tmux -S "$SOCKET" send-keys -t "$SESSION":0.0 -- "bw status" Enter
tmux -S "$SOCKET" send-keys -t "$SESSION":0.0 -- "bw list items --search 'github'" Enter
tmux -S "$SOCKET" capture-pane -p -J -t "$SESSION":0.0 -S -200
```

## Guardrails

- Never paste secrets into logs, chat, or code
- Use `bw get password` to retrieve passwords programmatically
- Always sync before reading: `bw sync`
- Session expires after inactivity; re-unlock if needed
- For 2FA accounts, you'll need the master password + 2FA code on login
