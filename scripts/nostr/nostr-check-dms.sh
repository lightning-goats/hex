#!/bin/bash
# Check for new DMs (on-demand, not streaming)
# Usage: nostr-check-dms.sh [limit] [--since <timestamp>]

set -e

source ~/.config/hex/nostr.env
export NOSTR_SECRET_KEY="$NOSTR_SECRET_KEY_HEX"
NAK=/home/sat/.local/bin/nak

LIMIT="${1:-10}"
SINCE=""
RELAY="wss://nos.lol"

# Parse args
while [[ $# -gt 0 ]]; do
    case $1 in
        --since)
            SINCE="-s $2"
            shift 2
            ;;
        *)
            LIMIT="$1"
            shift
            ;;
    esac
done

echo "=== NIP-04 DMs (kind 4) ===" >&2

# Fetch NIP-04 DMs sent TO me
$NAK req -k 4 -p "$NOSTR_PUBLIC_KEY_HEX" -l "$LIMIT" $SINCE "$RELAY" < /dev/null 2>/dev/null | \
while read -r event; do
    event_id=$(echo "$event" | jq -r '.id')
    sender=$(echo "$event" | jq -r '.pubkey')
    created_at=$(echo "$event" | jq -r '.created_at')
    ciphertext=$(echo "$event" | jq -r '.content')
    
    # Decrypt
    plaintext=$($NAK decrypt --nip04 -p "$sender" "$ciphertext" 2>/dev/null || echo "[decrypt failed]")
    
    date_str=$(date -d "@$created_at" "+%Y-%m-%d %H:%M" 2>/dev/null || echo "$created_at")
    
    echo ""
    echo "From: ${sender:0:16}..."
    echo "Date: $date_str"
    echo "ID: ${event_id:0:16}..."
    echo "---"
    echo "$plaintext"
    echo ""
done

echo "=== NIP-17 DMs (kind 1059 gift-wrapped) ===" >&2

# Fetch NIP-17 gift-wrapped DMs
$NAK req -k 1059 -p "$NOSTR_PUBLIC_KEY_HEX" -l "$LIMIT" $SINCE "$RELAY" < /dev/null 2>/dev/null | \
while read -r event; do
    event_id=$(echo "$event" | jq -r '.id')
    created_at=$(echo "$event" | jq -r '.created_at')
    
    # Try to unwrap
    unwrapped=$(echo "$event" | $NAK gift unwrap 2>/dev/null || echo "")
    
    if [ -n "$unwrapped" ]; then
        sender=$(echo "$unwrapped" | jq -r '.pubkey')
        plaintext=$(echo "$unwrapped" | jq -r '.content')
        
        date_str=$(date -d "@$created_at" "+%Y-%m-%d %H:%M" 2>/dev/null || echo "$created_at")
        
        echo ""
        echo "From: ${sender:0:16}..."
        echo "Date: $date_str"
        echo "ID: ${event_id:0:16}..."
        echo "---"
        echo "$plaintext"
        echo ""
    fi
done
