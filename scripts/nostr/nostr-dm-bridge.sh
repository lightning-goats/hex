#!/bin/bash
# Nostr DM Bridge - Receives DMs and forwards to Clawdbot webhook
# Usage: nostr-dm-bridge.sh [--nip04|--nip17|--both]
#
# Runs as a daemon, streaming incoming DMs and forwarding to Clawdbot.
# Default: --both (listens for both NIP-04 kind:4 and NIP-17 kind:1059)

set -e

source ~/.config/hex/nostr.env
export NOSTR_SECRET_KEY="$NOSTR_SECRET_KEY_HEX"
NAK=/home/sat/.local/bin/nak

# Clawdbot webhook endpoint
WEBHOOK_URL="${CLAWDBOT_WEBHOOK:-http://127.0.0.1:18789/hooks/nostr}"
WEBHOOK_TOKEN="${CLAWDBOT_HOOK_TOKEN}"

MODE="${1:---both}"
RELAY="${NOSTR_DM_RELAY:-wss://nos.lol}"

# State file to track processed event IDs
STATE_FILE="${HOME}/.cache/nostr-dm-bridge-state.json"
mkdir -p "$(dirname "$STATE_FILE")"
[ -f "$STATE_FILE" ] || echo '{"processed":[]}' > "$STATE_FILE"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >&2
}

is_processed() {
    local event_id="$1"
    jq -e --arg id "$event_id" '.processed | index($id) != null' "$STATE_FILE" > /dev/null 2>&1
}

mark_processed() {
    local event_id="$1"
    # Keep last 1000 event IDs
    jq --arg id "$event_id" '.processed = ([$id] + .processed)[:1000]' "$STATE_FILE" > "${STATE_FILE}.tmp" && \
        mv "${STATE_FILE}.tmp" "$STATE_FILE"
}

decrypt_nip04() {
    local sender_pubkey="$1"
    local ciphertext="$2"
    $NAK decrypt --nip04 -p "$sender_pubkey" "$ciphertext" 2>/dev/null
}

decrypt_nip17() {
    local sender_pubkey="$1"
    local wrapped_event="$2"
    echo "$wrapped_event" | $NAK gift unwrap --from "$sender_pubkey" 2>/dev/null | jq -r '.content'
}

forward_to_clawdbot() {
    local sender="$1"
    local content="$2"
    local event_id="$3"
    local dm_type="$4"
    
    # Build webhook payload
    local payload=$(jq -n \
        --arg sender "$sender" \
        --arg content "$content" \
        --arg event_id "$event_id" \
        --arg dm_type "$dm_type" \
        '{
            type: "nostr_dm",
            sender: $sender,
            content: $content,
            event_id: $event_id,
            dm_type: $dm_type
        }')
    
    # Forward to Clawdbot
    local url="$WEBHOOK_URL"
    [ -n "$WEBHOOK_TOKEN" ] && url="${WEBHOOK_URL}?token=${WEBHOOK_TOKEN}"
    
    curl -s -X POST \
        -H "Content-Type: application/json" \
        -d "$payload" \
        "$url" > /dev/null 2>&1 || log "Failed to forward to Clawdbot"
}

process_nip04_dm() {
    local event="$1"
    local event_id=$(echo "$event" | jq -r '.id')
    local sender=$(echo "$event" | jq -r '.pubkey')
    local ciphertext=$(echo "$event" | jq -r '.content')
    
    # Skip if already processed
    if is_processed "$event_id"; then
        return
    fi
    
    # Decrypt
    local plaintext=$(decrypt_nip04 "$sender" "$ciphertext")
    
    if [ -n "$plaintext" ]; then
        log "NIP-04 DM from ${sender:0:16}...: $plaintext"
        forward_to_clawdbot "$sender" "$plaintext" "$event_id" "nip04"
        mark_processed "$event_id"
    else
        log "Failed to decrypt NIP-04 DM from ${sender:0:16}..."
    fi
}

process_nip17_dm() {
    local event="$1"
    local event_id=$(echo "$event" | jq -r '.id')
    
    # Skip if already processed
    if is_processed "$event_id"; then
        return
    fi
    
    # For NIP-17, we need to try unwrapping to find the sender
    # The outer event is signed by a random key, inner rumor has real sender
    local unwrapped=$(echo "$event" | $NAK gift unwrap 2>/dev/null)
    
    if [ -n "$unwrapped" ]; then
        local sender=$(echo "$unwrapped" | jq -r '.pubkey')
        local plaintext=$(echo "$unwrapped" | jq -r '.content')
        
        log "NIP-17 DM from ${sender:0:16}...: $plaintext"
        forward_to_clawdbot "$sender" "$plaintext" "$event_id" "nip17"
        mark_processed "$event_id"
    else
        log "Failed to unwrap NIP-17 DM"
    fi
}

stream_nip04() {
    log "Streaming NIP-04 DMs (kind 4) from $RELAY..."
    $NAK req --stream -k 4 -p "$NOSTR_PUBLIC_KEY_HEX" "$RELAY" < /dev/null 2>/dev/null | \
    while read -r event; do
        [ -n "$event" ] && process_nip04_dm "$event"
    done
}

stream_nip17() {
    log "Streaming NIP-17 DMs (kind 1059) from $RELAY..."
    $NAK req --stream -k 1059 -p "$NOSTR_PUBLIC_KEY_HEX" "$RELAY" < /dev/null 2>/dev/null | \
    while read -r event; do
        [ -n "$event" ] && process_nip17_dm "$event"
    done
}

# Main
log "Starting Nostr DM Bridge (mode: $MODE)"
log "Webhook: $WEBHOOK_URL"
log "Relay: $RELAY"

case "$MODE" in
    --nip04)
        stream_nip04
        ;;
    --nip17)
        stream_nip17
        ;;
    --both)
        # Run both in background
        stream_nip04 &
        stream_nip17 &
        wait
        ;;
    *)
        echo "Unknown mode: $MODE" >&2
        echo "Usage: nostr-dm-bridge.sh [--nip04|--nip17|--both]" >&2
        exit 1
        ;;
esac
