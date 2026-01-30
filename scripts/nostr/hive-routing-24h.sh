#!/usr/bin/env bash
# hive-routing-24h.sh — Get 24h routing stats from Lightning Hive fleet
# Returns: payment_count volume_sats fee_sats
# Usage: ./hive-routing-24h.sh [--json]
#
# Requires: ~/.config/hex/hive.env with node URLs and runes

set -euo pipefail

# Load credentials from env file
HIVE_ENV="${HIVE_ENV:-$HOME/.config/hex/hive.env}"
if [[ ! -f "$HIVE_ENV" ]]; then
  echo "Error: Missing $HIVE_ENV - create it with HIVE_NEXUS_*_URL and HIVE_NEXUS_*_RUNE" >&2
  exit 1
fi
source "$HIVE_ENV"

JSON_MODE=false
[[ "${1:-}" == "--json" ]] && JSON_MODE=true

# Build nodes array from env
NODES=(
  "hive-nexus-01|${HIVE_NEXUS_01_URL}|${HIVE_NEXUS_01_RUNE}"
  "hive-nexus-02|${HIVE_NEXUS_02_URL}|${HIVE_NEXUS_02_RUNE}"
)

# 24 hours ago in unix timestamp
CUTOFF=$(( $(date +%s) - 86400 ))

TOTAL_COUNT=0
TOTAL_VOLUME_MSAT=0
TOTAL_FEE_MSAT=0

for NODE_CFG in "${NODES[@]}"; do
  IFS='|' read -r NAME URL RUNE <<< "$NODE_CFG"
  
  # Fetch forwards
  RESPONSE=$(curl -sk -X POST -H "Rune: $RUNE" -H "Content-Type: application/json" \
    -d '{"status": "settled"}' \
    "${URL}/v1/listforwards" 2>/dev/null || echo '{"forwards":[]}')
  
  # Filter by 24h and aggregate
  STATS=$(echo "$RESPONSE" | jq -r --argjson cutoff "$CUTOFF" '
    .forwards // [] 
    | map(select(.resolved_time > $cutoff))
    | {
        count: length,
        volume_msat: (map(.in_msat) | add // 0),
        fee_msat: (map(.fee_msat) | add // 0)
      }
    | "\(.count) \(.volume_msat) \(.fee_msat)"
  ')
  
  read -r COUNT VOL FEE <<< "$STATS"
  TOTAL_COUNT=$((TOTAL_COUNT + COUNT))
  TOTAL_VOLUME_MSAT=$((TOTAL_VOLUME_MSAT + VOL))
  TOTAL_FEE_MSAT=$((TOTAL_FEE_MSAT + FEE))
done

# Convert msat to sats
TOTAL_VOLUME_SATS=$((TOTAL_VOLUME_MSAT / 1000))
TOTAL_FEE_SATS=$((TOTAL_FEE_MSAT / 1000))

if [[ "$JSON_MODE" == "true" ]]; then
  echo "{\"payments\":${TOTAL_COUNT},\"volume_sats\":${TOTAL_VOLUME_SATS},\"fee_sats\":${TOTAL_FEE_SATS}}"
else
  echo "$TOTAL_COUNT $TOTAL_VOLUME_SATS $TOTAL_FEE_SATS"
fi
