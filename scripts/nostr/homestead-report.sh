#!/usr/bin/env bash
# homestead-report.sh — Generate Lightning Goats Homestead Report
# Usage: ./homestead-report.sh [--post]
#   --post: Actually publish to Nostr (default: just print)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Load credentials
source ~/.config/hex/lnbits.env
source ~/.config/hex/openhab.env
source ~/.config/hex/nostr.env
source ~/.config/hex/hive.env

POST_MODE=false
[[ "${1:-}" == "--post" ]] && POST_MODE=true

# --- Fetch Data ---

# Lightning Goats status (feeder sats, btc price, cyberherd)
GOATS_STATUS=$(curl -s -H "X-Api-Key: $LNBITS_ADMIN_KEY" \
  "https://lnb.bolverker.com/lightning_goats/api/v1/status")

FEEDER_SATS=$(echo "$GOATS_STATUS" | jq -r '.balance_sats // 0')
TRIGGER_AMOUNT=$(echo "$GOATS_STATUS" | jq -r '.trigger_amount // 1000')
CYBERHERD_ACTIVE=$(echo "$GOATS_STATUS" | jq -r '.active_members // 0')
BTC_PRICE=$(echo "$GOATS_STATUS" | jq -r '.btc_price_usd // 0 | floor')
BTC_CHANGE=$(echo "$GOATS_STATUS" | jq -r '.btc_24h_change // 0 | . * 100 | round / 100')

# CyberHerd max members (from settings)
CYBERHERD_MAX=$(curl -s "https://lnb.bolverker.com/cyberherd/api/v1/settings" | jq -r '.max_members // 5')

# Blockheight
BLOCKHEIGHT=$(curl -s "https://mempool.space/api/blocks/tip/height" 2>/dev/null || echo "???")

# 24h Hive routing stats
ROUTING_STATS=$("$SCRIPT_DIR/hive-routing-24h.sh" --json 2>/dev/null || echo '{"payments":0,"volume_sats":0}')
ROUTING_PAYMENTS=$(echo "$ROUTING_STATS" | jq -r '.payments // 0')
ROUTING_VOLUME=$(echo "$ROUTING_STATS" | jq -r '.volume_sats // 0')

# Format volume with commas
ROUTING_VOLUME_FMT=$(printf "%'d" "$ROUTING_VOLUME" 2>/dev/null || echo "$ROUTING_VOLUME")

# Hive node count (via direct REST - faster than mcporter)
HIVE_NODES=$(curl -sk --max-time 8 -X POST -H "Rune: $HIVE_NEXUS_02_RUNE" \
  "$HIVE_NEXUS_02_URL/v1/hive-status" 2>/dev/null | jq -r '.members.total // 3')

# OpenHAB items
fetch_oh_item() {
  curl -s -H "Authorization: Bearer $OPENHAB_TOKEN" \
    "http://localhost:8080/rest/items/$1" 2>/dev/null | jq -r '.state // "NULL"'
}

BATTERY_SOC=$(fetch_oh_item "BatterySoC_CoulombCounter")
CHARGER_STATUS=$(fetch_oh_item "ChargerStatus")
SOLAR_WATTS=$(fetch_oh_item "ConextGateway_ACPowerValue" | sed 's/ W//')
MINER_POWER=$(fetch_oh_item "Miner_Power")
FEEDER_POWER=$(fetch_oh_item "Goat_Plugs_Outlet1_Switch")
TEMP_OUTDOOR=$(fetch_oh_item "AmbientWeatherWS2902A_WeatherDataWs2902a_Temperature")
TEMP_INDOOR=$(fetch_oh_item "Shelly_HT1_Indoor_Temperature" | sed 's/ °F//')

# Round outdoor temp
TEMP_OUTDOOR_ROUND=$(printf "%.0f" "$TEMP_OUTDOOR" 2>/dev/null || echo "$TEMP_OUTDOOR")
TEMP_INDOOR_ROUND=$(printf "%.0f" "$TEMP_INDOOR" 2>/dev/null || echo "$TEMP_INDOOR")

# Battery percentage (remove decimals)
BATTERY_PCT=$(printf "%.0f" "$BATTERY_SOC" 2>/dev/null || echo "$BATTERY_SOC")

# Format BTC change with sign
if (( $(echo "$BTC_CHANGE >= 0" | bc -l) )); then
  BTC_CHANGE_FMT="+${BTC_CHANGE}%"
else
  BTC_CHANGE_FMT="${BTC_CHANGE}%"
fi

# --- Generate Flavor Text ---
generate_flavor() {
  local flavor=""
  
  # Battery state
  if [[ "$BATTERY_PCT" == "100" ]]; then
    flavor="Battery full"
  elif (( BATTERY_PCT >= 80 )); then
    flavor="Battery healthy at ${BATTERY_PCT}%"
  elif (( BATTERY_PCT >= 50 )); then
    flavor="Battery at ${BATTERY_PCT}%"
  else
    flavor="Battery low at ${BATTERY_PCT}%"
  fi
  
  # Miner
  if [[ "$MINER_POWER" == "ON" ]]; then
    flavor="$flavor, miner hashing"
  fi
  
  # Weather + solar commentary
  if (( TEMP_OUTDOOR_ROUND <= 40 )); then
    if (( $(echo "$SOLAR_WATTS > 200" | bc -l 2>/dev/null || echo 0) )); then
      flavor="$flavor — chilly morning but the sun's putting in work."
    else
      flavor="$flavor — cold and cloudy."
    fi
  elif (( TEMP_OUTDOOR_ROUND >= 80 )); then
    flavor="$flavor — hot one today."
  else
    if (( $(echo "$SOLAR_WATTS > 500" | bc -l 2>/dev/null || echo 0) )); then
      flavor="$flavor — sun's blazing."
    else
      flavor="$flavor — mild day."
    fi
  fi
  
  echo "$flavor"
}

FLAVOR=$(generate_flavor)

# --- Format Report ---
REPORT="⚡🐐 nostr:nprofile1qqsxd84men85p8hqgearxes2az8azljn08nydeqa0s3klayk8u7rddshkxjm3 Homestead Report
Block ${BLOCKHEIGHT}

${FLAVOR}

⚡ AC: ${SOLAR_WATTS}W Draw
🔋 Battery: ${BATTERY_PCT}% (${CHARGER_STATUS})
⛏️ Miner: ${MINER_POWER}
🐐 Goat Feeder: ${FEEDER_POWER} (${FEEDER_SATS}/${TRIGGER_AMOUNT} sats)
👥 CyberHerd: ${CYBERHERD_ACTIVE}/${CYBERHERD_MAX} members
🌡️ ${TEMP_OUTDOOR_ROUND}°F outside | ${TEMP_INDOOR_ROUND}°F inside

🐝 Hive: ${HIVE_NODES} nodes
⚡ Hive-Nexus Fleet Routed (24h): ${ROUTING_PAYMENTS} payments / ${ROUTING_VOLUME_FMT} sats

₿ \$${BTC_PRICE} (${BTC_CHANGE_FMT})

zap the goats ⚡ https://lightning-goats.com

#LightningGoats #Hive #Bitcoin #OffGrid"

# --- Output ---
if [[ "$POST_MODE" == "true" ]]; then
  echo "Publishing to Nostr..."
  "$SCRIPT_DIR/nostr-post.sh" "$REPORT" 2>&1
else
  echo "=== SAMPLE REPORT (use --post to publish) ==="
  echo ""
  echo "$REPORT"
  echo ""
  echo "=== END REPORT ==="
fi
