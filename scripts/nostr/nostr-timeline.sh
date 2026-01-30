#!/bin/bash
# Fetch recent notes from my timeline (people I follow)
# Usage: nostr-timeline.sh [limit]

set -e

source ~/.config/hex/nostr.env
export NOSTR_SECRET_KEY="$NOSTR_SECRET_KEY_HEX"
NAK=/home/sat/.local/bin/nak

LIMIT="${1:-20}"
RELAY="wss://nos.lol"

# First, get my follow list (kind 3)
FOLLOWS=$($NAK req -k 3 -a "$NOSTR_PUBLIC_KEY_HEX" -l 1 "$RELAY" < /dev/null 2>/dev/null | \
    jq -r '.tags[] | select(.[0]=="p") | .[1]' 2>/dev/null)

if [ -z "$FOLLOWS" ]; then
    echo "No follows found or error fetching follow list" >&2
    exit 1
fi

# Build author filter
AUTHORS=""
for pubkey in $FOLLOWS; do
    AUTHORS="$AUTHORS -a $pubkey"
done

# Fetch recent notes from followed accounts
$NAK req -k 1 $AUTHORS -l "$LIMIT" "$RELAY" < /dev/null 2>/dev/null | \
jq -r '[.created_at, .pubkey[:16], .content] | @tsv' | \
while IFS=$'\t' read -r ts author content; do
    date_str=$(date -d "@$ts" "+%Y-%m-%d %H:%M" 2>/dev/null || echo "$ts")
    echo "[$date_str] $author..."
    echo "  $content"
    echo ""
done
