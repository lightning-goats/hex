#!/usr/bin/env bash
# nostr-mentions-poll.sh — Check for new Nostr mentions and return unseen ones
# Tracks seen IDs in ~/.cache/hex/nostr-seen-mentions.txt
# Usage: ./nostr-mentions-poll.sh [--mark-seen <id>]

set -euo pipefail

source ~/.config/hex/nostr.env

NAK="${NAK:-/home/sat/.local/bin/nak}"
SEEN_FILE="${HOME}/.cache/hex/nostr-seen-mentions.txt"
RELAYS="wss://nos.lol wss://relay.damus.io wss://relay.primal.net"

# Ensure cache dir exists
mkdir -p "$(dirname "$SEEN_FILE")"
touch "$SEEN_FILE"

# Mark an ID as seen
if [[ "${1:-}" == "--mark-seen" && -n "${2:-}" ]]; then
  echo "$2" >> "$SEEN_FILE"
  echo "Marked $2 as seen"
  exit 0
fi

# Fetch recent mentions (last 24h, limit 20)
SINCE=$(( $(date +%s) - 86400 ))

MENTIONS=$($NAK req \
  -k 1 \
  -p "$NOSTR_PUBLIC_KEY_HEX" \
  --since "$SINCE" \
  -l 20 \
  $RELAYS < /dev/null 2>/dev/null | sort -u)

if [[ -z "$MENTIONS" ]]; then
  echo "[]"
  exit 0
fi

# Filter out already-seen IDs and my own posts
UNSEEN="[]"
while IFS= read -r event; do
  [[ -z "$event" ]] && continue
  
  ID=$(echo "$event" | jq -r '.id // empty')
  PUBKEY=$(echo "$event" | jq -r '.pubkey // empty')
  
  [[ -z "$ID" ]] && continue
  
  # Skip my own posts
  [[ "$PUBKEY" == "$NOSTR_PUBLIC_KEY_HEX" ]] && continue
  
  # Skip already seen
  if grep -q "^${ID}$" "$SEEN_FILE" 2>/dev/null; then
    continue
  fi
  
  # Add to unseen list
  UNSEEN=$(echo "$UNSEEN" | jq --argjson evt "$event" '. + [$evt]')
  
done <<< "$MENTIONS"

echo "$UNSEEN"
