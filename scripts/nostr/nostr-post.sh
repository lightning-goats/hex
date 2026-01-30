#!/bin/bash
# Post a note to Nostr
# Usage: nostr-post.sh "message" [hashtag1 hashtag2 ...]

set -e

source ~/.config/hex/nostr.env
export NOSTR_SECRET_KEY="$NOSTR_SECRET_KEY_HEX"
NAK=/home/sat/.local/bin/nak

MESSAGE="$1"
shift || true

if [ -z "$MESSAGE" ]; then
    echo "Usage: nostr-post.sh \"message\" [hashtag1 hashtag2 ...]" >&2
    exit 1
fi

# Build tag arguments for hashtags
TAGS=""
for tag in "$@"; do
    TAGS="$TAGS -t t=$tag"
done

# Default relays
RELAYS="wss://nos.lol wss://relay.damus.io"

# Post
$NAK event -c "$MESSAGE" $TAGS $RELAYS < /dev/null 2>&1

echo "Posted successfully" >&2
