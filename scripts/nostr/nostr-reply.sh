#!/bin/bash
# Reply to a Nostr note
# Usage: nostr-reply.sh <nevent|note|event-id> "message"

set -e

source ~/.config/hex/nostr.env
export NOSTR_SECRET_KEY="$NOSTR_SECRET_KEY_HEX"
NAK=/home/sat/.local/bin/nak

TARGET="$1"
MESSAGE="$2"

if [ -z "$TARGET" ] || [ -z "$MESSAGE" ]; then
    echo "Usage: nostr-reply.sh <nevent|note|event-id> \"message\"" >&2
    exit 1
fi

# Default relays
RELAYS="wss://nos.lol wss://relay.damus.io"

# Use publish command which handles nevent/note decoding
echo "$MESSAGE" | $NAK publish --reply "$TARGET" $RELAYS 2>&1

echo "Reply posted successfully" >&2
