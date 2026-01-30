#!/bin/bash
# Zap a Nostr profile or event (NIP-57)
# Usage: nostr-zap.sh <npub|nevent|note> <amount_sats> [message]
#
# Integrates with Hex's LNbits wallet for payment

set -e

source ~/.config/hex/nostr.env
source ~/.config/hex/lnbits.env
export NOSTR_SECRET_KEY="$NOSTR_SECRET_KEY_HEX"
NAK=/home/sat/.local/bin/nak

TARGET="$1"
AMOUNT="$2"
MESSAGE="${3:-⚡}"

if [ -z "$TARGET" ] || [ -z "$AMOUNT" ]; then
    echo "Usage: nostr-zap.sh <npub|nevent|note> <amount_sats> [message]" >&2
    exit 1
fi

RELAY="wss://nos.lol"

# Decode target to get pubkey (and event_id if applicable)
EVENT_ID=""
if [[ "$TARGET" == npub1* ]]; then
    RECIPIENT=$($NAK decode -p "$TARGET" 2>/dev/null)
elif [[ "$TARGET" == nevent1* ]] || [[ "$TARGET" == note1* ]]; then
    DECODED=$($NAK decode "$TARGET" 2>/dev/null)
    EVENT_ID=$(echo "$DECODED" | jq -r '.id // empty')
    RECIPIENT=$(echo "$DECODED" | jq -r '.pubkey // empty')
    
    # If no pubkey in decode, fetch the event
    if [ -z "$RECIPIENT" ]; then
        EVENT=$($NAK req -i "$EVENT_ID" -l 1 "$RELAY" < /dev/null 2>/dev/null | head -1)
        RECIPIENT=$(echo "$EVENT" | jq -r '.pubkey')
    fi
else
    # Assume it's a hex pubkey
    RECIPIENT="$TARGET"
fi

if [ -z "$RECIPIENT" ]; then
    echo "Could not determine recipient pubkey" >&2
    exit 1
fi

echo "Recipient: $RECIPIENT" >&2

# Fetch recipient profile to get LNURL/lightning address
PROFILE=$($NAK req -k 0 -a "$RECIPIENT" -l 1 "$RELAY" < /dev/null 2>/dev/null | jq -r '.content | fromjson')
LUD16=$(echo "$PROFILE" | jq -r '.lud16 // empty')
LNURL=$(echo "$PROFILE" | jq -r '.lud06 // empty')

if [ -z "$LUD16" ] && [ -z "$LNURL" ]; then
    echo "Recipient has no lightning address (lud16) or LNURL (lud06)" >&2
    exit 1
fi

echo "Lightning address: $LUD16" >&2

# Convert lud16 to LNURL callback
if [ -n "$LUD16" ]; then
    USER="${LUD16%%@*}"
    DOMAIN="${LUD16#*@}"
    CALLBACK_URL="https://${DOMAIN}/.well-known/lnurlp/${USER}"
    
    # Fetch LNURL metadata
    LNURL_RESPONSE=$(curl -s "$CALLBACK_URL")
    MIN_SENDABLE=$(echo "$LNURL_RESPONSE" | jq -r '.minSendable // 1000')
    MAX_SENDABLE=$(echo "$LNURL_RESPONSE" | jq -r '.maxSendable // 100000000000')
    CALLBACK=$(echo "$LNURL_RESPONSE" | jq -r '.callback')
    ALLOWS_NOSTR=$(echo "$LNURL_RESPONSE" | jq -r '.allowsNostr // false')
    NOSTR_PUBKEY=$(echo "$LNURL_RESPONSE" | jq -r '.nostrPubkey // empty')
    
    # Convert sats to msats
    AMOUNT_MSATS=$((AMOUNT * 1000))
    
    if [ "$AMOUNT_MSATS" -lt "$MIN_SENDABLE" ] || [ "$AMOUNT_MSATS" -gt "$MAX_SENDABLE" ]; then
        echo "Amount out of range: $MIN_SENDABLE - $MAX_SENDABLE msats" >&2
        exit 1
    fi
    
    if [ "$ALLOWS_NOSTR" != "true" ]; then
        echo "Recipient does not support Nostr zaps (allowsNostr=false)" >&2
        echo "Proceeding with regular payment..." >&2
    fi
fi

# Create zap request event (kind 9734)
ZAP_TAGS="-p $RECIPIENT -t amount=$AMOUNT_MSATS -t relays=$RELAY"
[ -n "$EVENT_ID" ] && ZAP_TAGS="$ZAP_TAGS -e $EVENT_ID"
[ -n "$NOSTR_PUBKEY" ] && ZAP_TAGS="$ZAP_TAGS -t lnurl=$CALLBACK_URL"

ZAP_REQUEST=$($NAK event -k 9734 -c "$MESSAGE" $ZAP_TAGS < /dev/null 2>/dev/null)
ZAP_REQUEST_ENCODED=$(echo "$ZAP_REQUEST" | jq -c '.' | jq -sRr @uri)

echo "Zap request created" >&2

# Request invoice from LNURL callback
INVOICE_URL="${CALLBACK}?amount=${AMOUNT_MSATS}&nostr=${ZAP_REQUEST_ENCODED}"
INVOICE_RESPONSE=$(curl -s "$INVOICE_URL")
BOLT11=$(echo "$INVOICE_RESPONSE" | jq -r '.pr // empty')

if [ -z "$BOLT11" ]; then
    echo "Failed to get invoice from recipient" >&2
    echo "Response: $INVOICE_RESPONSE" >&2
    exit 1
fi

echo "Invoice received: ${BOLT11:0:50}..." >&2

# Pay using LNbits
echo "Paying invoice via LNbits..." >&2

PAY_RESPONSE=$(curl -s -X POST \
    -H "X-Api-Key: $LNBITS_ADMIN_KEY" \
    -H "Content-Type: application/json" \
    -d "{\"out\": true, \"bolt11\": \"$BOLT11\"}" \
    "$LNBITS_HOST/api/v1/payments")

PAYMENT_HASH=$(echo "$PAY_RESPONSE" | jq -r '.payment_hash // empty')
ERROR=$(echo "$PAY_RESPONSE" | jq -r '.detail // empty')

if [ -n "$PAYMENT_HASH" ]; then
    echo "⚡ Zap sent successfully!" >&2
    echo "Amount: $AMOUNT sats" >&2
    echo "Payment hash: $PAYMENT_HASH" >&2
else
    echo "Payment failed: $ERROR" >&2
    echo "Response: $PAY_RESPONSE" >&2
    exit 1
fi
