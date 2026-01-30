#!/bin/bash
# Upload media to nostr.build with NIP-98 auth
# Usage: nostr-upload.sh <file>

set -e

source ~/.config/hex/nostr.env
export NOSTR_SECRET_KEY="$NOSTR_SECRET_KEY_HEX"
NAK=/home/sat/.local/bin/nak

FILE="$1"

if [ -z "$FILE" ] || [ ! -f "$FILE" ]; then
    echo "Usage: nostr-upload.sh <file>" >&2
    exit 1
fi

# Upload with NIP-98 auth
RESPONSE=$($NAK curl -X POST -F "file=@$FILE" https://nostr.build/api/v2/upload/files 2>/dev/null)

# Extract URL from response
URL=$(echo "$RESPONSE" | jq -r '.data[0].url // .url // empty' 2>/dev/null)

if [ -n "$URL" ]; then
    echo "$URL"
else
    echo "Upload failed. Response:" >&2
    echo "$RESPONSE" >&2
    exit 1
fi
