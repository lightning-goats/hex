#!/bin/bash
# React to a Nostr note
# Usage: nostr-react.sh <nevent|note|event-id> [emoji]
#
# Default emoji: + (like)
# Common: ⚡ (zap-worthy), 🤙 (shaka), ❤️ (heart)

set -e

source ~/.config/hex/nostr.env
export NOSTR_SECRET_KEY="$NOSTR_SECRET_KEY_HEX"
NAK=/home/sat/.local/bin/nak

TARGET="$1"
EMOJI="${2:-+}"

if [ -z "$TARGET" ]; then
    echo "Usage: nostr-react.sh <nevent|note|event-id> [emoji]" >&2
    exit 1
fi

# Decode target to get event ID and author pubkey
if [[ "$TARGET" == nevent1* ]] || [[ "$TARGET" == note1* ]]; then
    DECODED=$($NAK decode "$TARGET" 2>/dev/null)
    EVENT_ID=$(echo "$DECODED" | grep -oP '(?<="id":")[^"]+' | head -1)
    AUTHOR=$(echo "$DECODED" | grep -oP '(?<="pubkey":")[^"]+' | head -1)
    
    # If no author in decode, try to fetch it
    if [ -z "$AUTHOR" ]; then
        EVENT=$($NAK fetch "$TARGET" -r wss://nos.lol 2>/dev/null | head -1)
        AUTHOR=$(echo "$EVENT" | jq -r '.pubkey' 2>/dev/null)
    fi
else
    EVENT_ID="$TARGET"
    # Need to fetch the event to get author
    EVENT=$($NAK req -i "$TARGET" -l 1 wss://nos.lol < /dev/null 2>/dev/null | head -1)
    AUTHOR=$(echo "$EVENT" | jq -r '.pubkey' 2>/dev/null)
fi

if [ -z "$EVENT_ID" ]; then
    echo "Could not decode event ID" >&2
    exit 1
fi

# Default relay
RELAY="wss://nos.lol"

# Post reaction (kind 7)
if [ -n "$AUTHOR" ]; then
    $NAK event -k 7 -c "$EMOJI" -e "$EVENT_ID" -p "$AUTHOR" $RELAY < /dev/null 2>&1
else
    $NAK event -k 7 -c "$EMOJI" -e "$EVENT_ID" $RELAY < /dev/null 2>&1
fi

echo "Reacted with $EMOJI" >&2
