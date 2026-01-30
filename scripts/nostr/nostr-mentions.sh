#!/bin/bash
# Fetch recent mentions (events tagging my pubkey)
# Usage: nostr-mentions.sh [limit] [--raw]

set -e

source ~/.config/hex/nostr.env
export NOSTR_SECRET_KEY="$NOSTR_SECRET_KEY_HEX"
NAK=/home/sat/.local/bin/nak

LIMIT="${1:-10}"
RAW=""

if [ "$2" = "--raw" ] || [ "$1" = "--raw" ]; then
    RAW="true"
    [ "$1" = "--raw" ] && LIMIT="10"
fi

# Default relay
RELAY="wss://nos.lol"

if [ -n "$RAW" ]; then
    # Raw JSON output
    $NAK req -k 1 -p "$NOSTR_PUBLIC_KEY_HEX" -l "$LIMIT" "$RELAY" < /dev/null 2>/dev/null
else
    # Formatted output
    $NAK req -k 1 -p "$NOSTR_PUBLIC_KEY_HEX" -l "$LIMIT" "$RELAY" < /dev/null 2>/dev/null | \
    jq -r '[.created_at, .pubkey[:16], .content] | @tsv' | \
    while IFS=$'\t' read -r ts author content; do
        date_str=$(date -d "@$ts" "+%Y-%m-%d %H:%M" 2>/dev/null || echo "$ts")
        echo "[$date_str] $author..."
        echo "  $content"
        echo ""
    done
fi
