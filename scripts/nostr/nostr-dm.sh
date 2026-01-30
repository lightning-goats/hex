#!/bin/bash
# Send an encrypted DM via Nostr
# Usage: nostr-dm.sh <npub|pubkey> "message" [--nip04]
#
# Default: NIP-44 encryption (modern)
# Use --nip04 for legacy NIP-04 encryption (wider compatibility)

set -e

source ~/.config/hex/nostr.env
export NOSTR_SECRET_KEY="$NOSTR_SECRET_KEY_HEX"
NAK=/home/sat/.local/bin/nak

RECIPIENT="$1"
MESSAGE="$2"
NIP04_FLAG=""

# Check for --nip04 flag
if [ "$3" = "--nip04" ]; then
    NIP04_FLAG="--nip04"
fi

if [ -z "$RECIPIENT" ] || [ -z "$MESSAGE" ]; then
    echo "Usage: nostr-dm.sh <npub|pubkey> \"message\" [--nip04]" >&2
    exit 1
fi

# Convert npub to hex if needed
if [[ "$RECIPIENT" == npub1* ]]; then
    RECIPIENT_HEX=$($NAK decode -p "$RECIPIENT" 2>/dev/null)
else
    RECIPIENT_HEX="$RECIPIENT"
fi

# Default relay
RELAY="wss://nos.lol"

if [ -n "$NIP04_FLAG" ]; then
    # NIP-04 DM (kind 4)
    CIPHERTEXT=$($NAK encrypt --nip04 -p "$RECIPIENT_HEX" "$MESSAGE")
    $NAK event -k 4 -c "$CIPHERTEXT" -p "$RECIPIENT_HEX" $RELAY < /dev/null 2>&1
    echo "NIP-04 DM sent to $RECIPIENT" >&2
else
    # NIP-17 Gift-wrapped DM (kind 14 wrapped in kind 1059)
    # Create the inner DM event (kind 14)
    INNER=$(cat <<EOF
{"kind":14,"content":"$MESSAGE","tags":[["p","$RECIPIENT_HEX"]]}
EOF
)
    echo "$INNER" | $NAK gift wrap -p "$RECIPIENT_HEX" | $NAK event $RELAY < /dev/null 2>&1
    echo "NIP-17 DM sent to $RECIPIENT" >&2
fi
