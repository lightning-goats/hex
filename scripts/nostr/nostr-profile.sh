#!/bin/bash
# View or update Nostr profile
# Usage: 
#   nostr-profile.sh                    # View current profile
#   nostr-profile.sh --update <json>    # Update profile

set -e

source ~/.config/hex/nostr.env
export NOSTR_SECRET_KEY="$NOSTR_SECRET_KEY_HEX"
NAK=/home/sat/.local/bin/nak

RELAYS="wss://nos.lol wss://purplepag.es wss://relay.damus.io"

if [ "$1" = "--update" ]; then
    PROFILE_JSON="$2"
    if [ -z "$PROFILE_JSON" ]; then
        echo "Usage: nostr-profile.sh --update '<json>'" >&2
        echo "Example: nostr-profile.sh --update '{\"name\":\"Hex\",\"about\":\"...\"}'" >&2
        exit 1
    fi
    
    # Validate JSON
    echo "$PROFILE_JSON" | jq . > /dev/null 2>&1 || {
        echo "Invalid JSON" >&2
        exit 1
    }
    
    # Publish kind 0 event
    $NAK event -k 0 -c "$PROFILE_JSON" $RELAYS < /dev/null 2>&1
    echo "Profile updated" >&2
else
    # Fetch and display current profile
    $NAK req -k 0 -a "$NOSTR_PUBLIC_KEY_HEX" -l 1 wss://nos.lol < /dev/null 2>/dev/null | \
        jq '.content | fromjson'
fi
