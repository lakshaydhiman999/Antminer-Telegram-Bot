#!/bin/sh
# ---------------------------------------------------------
# Antminer Telegram Control Script (v4.0)
# Currency: USD | Compatibility: Braiins OS / BOSminer
# Created by: lakshaydhiman999
# ---------------------------------------------------------

# --- CONFIGURATION ---
# Replace with your actual Bot Token and Chat ID
TOKEN="YOUR_TELEGRAM_BOT_TOKEN"
CHAT_ID="YOUR_TELEGRAM_CHAT_ID"
# ---------------------

CONFIG="/etc/bosminer.toml"
OFFSET_FILE="/tmp/tg_offset"
NC_BIN="/etc/nc"
CURL_BIN="/etc/curl"

# States
SELF_HEAL_STATE="ON"
SCHEDULER_STATE="OFF"

# Boot wait
sleep 1
echo "0" > $OFFSET_FILE

get_miner_data() {
    HOUR=$(date "+%H")
    LOGIN_IP=$(ifconfig eth0 | grep 'inet addr' | cut -d: -f2 | awk '{print $1}')
    [ -z "$LOGIN_IP" ] && LOGIN_IP=$(ip addr show eth0 | grep 'inet ' | awk '{print $2}' | cut -d/ -f1)

    WATTS=$(grep "^power_target =" $CONFIG | awk -F'=' '{print $2}' | tr -d ' "')
    SUMMARY=$(echo '{"command":"summary"}' | $NC_BIN 127.0.0.1 4028)
    SPEED=$(echo "$SUMMARY" | grep -o '"MHS 5s":[0-9.]*' | awk -F: '{printf "%.2f", $2/1000000}')
    ELAPSED=$(echo "$SUMMARY" | grep -o '"Elapsed":[0-9]*' | awk -F: '{print $2}')
    
    UP_D=$((ELAPSED/86400)); UP_H=$(((ELAPSED%86400)/3600)); UP_M=$(((ELAPSED%3600)/60))
    UP_STR="${UP_D}d ${UP_H}h ${UP_M}m"
    
    TEMPS_RAW=$(echo '{"command":"temps"}' | $NC_BIN 127.0.0.1 4028)
    T_AVG=$(echo "$TEMPS_RAW" | grep -o '"Chip":[0-9.]*' | head -n 1 | awk -F: '{print $2}' | cut -d. -f1)

    BTC_PRICE_USD=$($CURL_BIN -k -s "https://api.coingecko.com/api/v3/simple/price?ids=bitcoin&vs_currencies=usd" | grep -o '"usd":[0-9.]*' | awk -F: '{print $2}' | tr -d ' "')
    [ -z "$BTC_PRICE_USD" ] && BTC_PRICE_USD=0
    EARNINGS_USD=$(awk "BEGIN {printf \"%.2f\", $SPEED * $BTC_PRICE_USD * 0.0000009}")

    MSG="<b>Miner Status Update</b> %F0%9F%93%8A%0A--------------------%0A<b>Login:</b> http://${LOGIN_IP}/%0A<b>Speed:</b> ${SPEED} TH/s %F0%9F%9A%80%0A<b>Temp:</b> ${T_AVG:-0} C %F0%9F%8C%A1%0A<b>Power:</b> ${WATTS}W %E2%9A%A1%0A<b>Uptime:</b> ${UP_STR}%0A%0A<b>Market Data:</b> %0A<b>BTC Price:</b> \$${BTC_PRICE_USD}%0A<b>Est. Daily:</b> \$${EARNINGS_USD} %F0%9F%93%88"
}

generate_keyboard() {
    HEAL_BTN="Self-Heal: OFF"; [ "$SELF_HEAL_STATE" = "OFF" ] && HEAL_BTN="Self-Heal: ON"
    SCHED_BTN="Scheduler: OFF"; [ "$SCHEDULER_STATE" = "OFF" ] && SCHED_BTN="Scheduler: ON"
    KEYBOARD="{\"keyboard\": [[{\"text\": \"Status Update\"}], [{\"text\": \"Set 1000W\"}, {\"text\": \"Set 2500W\"}], [{\"text\": \"Set 3000W\"}, {\"text\": \"Set 3200W\"}], [{\"text\": \"Ping Check\"}, {\"text\": \"$HEAL_BTN\"}], [{\"text\": \"$SCHED_BTN\"}, {\"text\": \"Reboot\"}]], \"resize_keyboard\": true}"
}

get_miner_data
generate_keyboard
$CURL_BIN -k -s -X POST "https://api.telegram.org/bot$TOKEN/sendMessage" -d chat_id="$CHAT_ID" -d text="<b>Miner Bot Online</b> %F0%9F%A4%96%0A$MSG" -d parse_mode="HTML" -d reply_markup="$KEYBOARD"

while true; do
  OFFSET=$(cat $OFFSET_FILE)
  UPDATES=$($CURL_BIN -k -s "https://api.telegram.org/bot$TOKEN/getUpdates?offset=$OFFSET&timeout=5")
  get_miner_data

  case "$UPDATES" in
    *"Status Update"*) $CURL_BIN -k -s -X POST "https://api.telegram.org/bot$TOKEN/sendMessage" -d chat_id="$CHAT_ID" -d text="$MSG" -d parse_mode="HTML" ;;
    *"Set 1000W"*) TARGET=1000 ;;
    *"Set 2500W"*) TARGET=2500 ;;
    *"Set 3000W"*) TARGET=3000 ;;
    *"Set 3200W"*) TARGET=3200 ;;
    *"Ping Check"*)
      LAT=$(ping -c 3 google.com | tail -1 | awk -F '/' '{print $5}')
      $CURL_BIN -k -s -X POST "https://api.telegram.org/bot$TOKEN/sendMessage" -d chat_id="$CHAT_ID" -d text="<b>Latency:</b> ${LAT:-0} ms %E2%9C%85" -d parse_mode="HTML" ;;
    *"Self-Heal: ON"*) SELF_HEAL_STATE="ON" && generate_keyboard && $CURL_BIN -k -s -X POST "https://api.telegram.org/bot$TOKEN/sendMessage" -d chat_id="$CHAT_ID" -d text="<b>Heal ON</b>" -d parse_mode="HTML" -d reply_markup="$KEYBOARD" ;;
    *"Self-Heal: OFF"*) SELF_HEAL_STATE="OFF" && generate_keyboard && $CURL_BIN -k -s -X POST "https://api.telegram.org/bot$TOKEN/sendMessage" -d chat_id="$CHAT_ID" -d text="<b>Heal OFF</b>" -d parse_mode="HTML" -d reply_markup="$KEYBOARD" ;;
    *"Scheduler: ON"*) SCHEDULER_STATE="ON" && generate_keyboard && $CURL_BIN -k -s -X POST "https://api.telegram.org/bot$TOKEN/sendMessage" -d chat_id="$CHAT_ID" -d text="<b>Sched ON</b>" -d parse_mode="HTML" -d reply_markup="$KEYBOARD" ;;
    *"Scheduler: OFF"*) SCHEDULER_STATE="OFF" && generate_keyboard && $CURL_BIN -k -s -X POST "https://api.telegram.org/bot$TOKEN/sendMessage" -d chat_id="$CHAT_ID" -d text="<b>Sched OFF</b>" -d parse_mode="HTML" -d reply_markup="$KEYBOARD" ;;
    *"Reboot"*) reboot ;;
  esac

  if [ ! -z "$TARGET" ]; then
    sed -i "s/^power_target =.*/power_target = $TARGET/" $CONFIG
    $CURL_BIN -k -s -X POST "https://api.telegram.org/bot$TOKEN/sendMessage" -d chat_id="$CHAT_ID" -d text="<b>Power set to ${TARGET}W.</b>" -d parse_mode="HTML"
    sleep 2 && reboot
  fi

  if echo "$UPDATES" | grep -q "update_id"; then
    N_ID=$(echo "$UPDATES" | grep -o '"update_id":[0-9]*' | tail -n 1 | cut -d: -f2)
    echo $((N_ID + 1)) > $OFFSET_FILE
  fi
  sleep 5
done
