#!/bin/sh
# ---------------------------------------------------------
# Antminer Telegram Control Script (Braiins OS)
# Version: v4.0 (Stable - BTC Price & Earnings)
# Created by: lakshaydhiman999
# ---------------------------------------------------------

# --- CONFIGURATION (FILL THIS BEFORE RUNNING) ---
TOKEN="YOUR_TELEGRAM_BOT_TOKEN_HERE"
CHAT_ID="YOUR_TELEGRAM_CHAT_ID_HERE"
# ------------------------------------------------

CONFIG="/etc/bosminer.toml"
OFFSET_FILE="/tmp/tg_offset"
NC_BIN="/etc/nc"
CURL_BIN="/etc/curl"

# States
SELF_HEAL_STATE="ON"
SCHEDULER_STATE="OFF"

# Boot wait
sleep 90
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
    T1=$(echo "$TEMPS_RAW" | grep -o '"Chip":[0-9.]*' | sed -n '1p' | cut -d: -f2 | cut -d. -f1)
    T2=$(echo "$TEMPS_RAW" | grep -o '"Chip":[0-9.]*' | sed -n '2p' | cut -d: -f2 | cut -d. -f1)
    T3=$(echo "$TEMPS_RAW" | grep -o '"Chip":[0-9.]*' | sed -n '3p' | cut -d: -f2 | cut -d. -f1)

    TOTAL_CHIPS=$(echo '{"command":"devdetails"}' | $NC_BIN 127.0.0.1 4028 | grep -o '"Chips":[0-9]*' | head -n 1 | cut -d: -f2)
    
    # --- BTC PRICE & EARNINGS CALCULATION ---
    BTC_PRICE=$($CURL_BIN -k -s "https://api.coingecko.com/api/v3/simple/price?ids=bitcoin&vs_currencies=usd" | grep -o '"usd":[0-9.]*' | awk -F: '{print $2}' | tr -d ' "')
    
    if [ -z "$BTC_PRICE" ] || [ "$BTC_PRICE" = "0" ]; then
        BTC_PRICE=0
        EARNINGS="0.00"
    else
        # Factor based on approx daily BTC revenue per TH/s
        EARNINGS=$(awk "BEGIN {printf \"%.2f\", $SPEED * $BTC_PRICE * 0.0000009}")
    fi

    P_URL=$(grep "url =" $CONFIG | grep -v "braiins" | head -n 1 | awk -F'=' '{print $2}' | tr -d ' "')
    P_ENABLED=$(grep -B 5 "$P_URL" $CONFIG | grep "enabled =" | head -n 1 | awk -F'=' '{print $2}' | tr -d ' "')

    MSG="<b>Miner Status Update</b> %F0%9F%93%8A%0A--------------------%0A<b>Login:</b> http://${LOGIN_IP}/ %F0%9F%8C%90%0A<b>Speed:</b> ${SPEED} TH/s %F0%9F%9A%80%0A<b>Temp:</b> ${T_AVG:-0} C %F0%9F%8C%A1%0A<b>Power:</b> ${WATTS}W %E2%9A%A1%0A<b>Uptime:</b> ${UP_STR} %F0%9F%95%92%0A%0A<b>Market Data:</b> %F0%9F%92%B0%0A<b>BTC Price:</b> \$${BTC_PRICE}%0A<b>Est. Daily:</b> \$${EARNINGS} %F0%9F%93%88%0A%0A<b>Board Health:</b> %F0%9F%9B%A1%0A- Board 1: ${T1:-0}C%0A- Board 2: ${T2:-0}C%0A- Board 3: ${T3:-0}C%0A<b>Total Chips:</b> ${TOTAL_CHIPS:-0} %E2%9C%85%0A%0A<b>Pool Info:</b>%0A<b>Status:</b> ${P_ENABLED} %E2%9C%85%0A<b>URL:</b> ${P_URL} %F0%9F%94%97%0A%0A<b>Self-Heal:</b> ${SELF_HEAL_STATE} %F0%9F%94%A7%0A<b>Scheduler:</b> ${SCHEDULER_STATE} %F0%9F%93%85"
}

generate_keyboard() {
    HEAL_BTN="Self-Heal: OFF"; [ "$SELF_HEAL_STATE" = "OFF" ] && HEAL_BTN="Self-Heal: ON"
    SCHED_BTN="Scheduler: OFF"; [ "$SCHEDULER_STATE" = "OFF" ] && SCHED_BTN="Scheduler: ON"
    KEYBOARD="{\"keyboard\": [[{\"text\": \"Status Update\"}], [{\"text\": \"Set 1000W\"}, {\"text\": \"Set 2500W\"}], [{\"text\": \"Set 3000W\"}, {\"text\": \"Set 3200W\"}], [{\"text\": \"Ping Check\"}, {\"text\": \"$HEAL_BTN\"}], [{\"text\": \"$SCHED_BTN\"}, {\"text\": \"Reboot\"}]], \"resize_keyboard\": true}"
}

get_miner_data
generate_keyboard
$CURL_BIN -k -s -X POST "https://api.telegram.org/bot$TOKEN/sendMessage" -d chat_id="$CHAT_ID" -d text="<b>Miner System Online</b> %F0%9F%A4%96%0A%0A$MSG" -d parse_mode="HTML" -d reply_markup="$KEYBOARD"

while true; do
  OFFSET=$(cat $OFFSET_FILE)
  UPDATES=$($CURL_BIN -k -s "https://api.telegram.org/bot$TOKEN/getUpdates?offset=$OFFSET&timeout=5")
  get_miner_data

  # --- 80C ALERT ---
  if [ "$T_AVG" -ge 80 ]; then
    $CURL_BIN -k -s -X POST "https://api.telegram.org/bot$TOKEN/sendMessage" -d chat_id="$CHAT_ID" -d text="<b>HIGH TEMP ALERT:</b> ${T_AVG} C! Miner is overheating %E2%9A%A0" -d parse_mode="HTML"
  fi

  # --- SCHEDULER ---
  if [ "$SCHEDULER_STATE" = "ON" ]; then
      if [ "$HOUR" -ge 10 ] && [ "$HOUR" -lt 22 ]; then
          [ "$WATTS" != "2500" ] && TARGET=2500 && S_MSG="<b>Day Mode:</b> 2500W set %E2%98%80"
      else
          [ "$WATTS" != "3200" ] && TARGET=3200 && S_MSG="<b>Night Mode:</b> 3200W set %F0%9F%8C%99"
      fi
      [ ! -z "$S_MSG" ] && $CURL_BIN -k -s -X POST "https://api.telegram.org/bot$TOKEN/sendMessage" -d chat_id="$CHAT_ID" -d text="$S_MSG" -d parse_mode="HTML" && unset S_MSG
  fi

  case "$UPDATES" in
    *"Status Update"*) $CURL_BIN -k -s -X POST "https://api.telegram.org/bot$TOKEN/sendMessage" -d chat_id="$CHAT_ID" -d text="$MSG" -d parse_mode="HTML" ;;
    *"Ping Check"*)
      $CURL_BIN -k -s -X POST "https://api.telegram.org/bot$TOKEN/sendMessage" -d chat_id="$CHAT_ID" -d text="<b>Checking Latency...</b> %F0%9F%94%8D" -d parse_mode="HTML"
      sleep 5
      LAT=$(ping -c 5 google.com | tail -1 | awk -F '/' '{print $5}')
      $CURL_BIN -k -s -X POST "https://api.telegram.org/bot$TOKEN/sendMessage" -d chat_id="$CHAT_ID" -d text="<b>Latency:</b> ${LAT} ms %E2%9C%85" -d parse_mode="HTML" ;;
    *"Self-Heal: ON"*) SELF_HEAL_STATE="ON" && generate_keyboard && $CURL_BIN -k -s -X POST "https://api.telegram.org/bot$TOKEN/sendMessage" -d chat_id="$CHAT_ID" -d text="<b>Heal ENABLED</b> %E2%9C%85" -d parse_mode="HTML" -d reply_markup="$KEYBOARD" ;;
    *"Self-Heal: OFF"*) SELF_HEAL_STATE="OFF" && generate_keyboard && $CURL_BIN -k -s -X POST "https://api.telegram.org/bot$TOKEN/sendMessage" -d chat_id="$CHAT_ID" -d text="<b>Heal DISABLED</b> %E2%9D%8C" -d parse_mode="HTML" -d reply_markup="$KEYBOARD" ;;
    *"Scheduler: ON"*) SCHEDULER_STATE="ON" && generate_keyboard && $CURL_BIN -k -s -X POST "https://api.telegram.org/bot$TOKEN/sendMessage" -d chat_id="$CHAT_ID" -d text="<b>Sched ENABLED</b> %E2%9C%85" -d parse_mode="HTML" -d reply_markup="$KEYBOARD" ;;
    *"Scheduler: OFF"*) SCHEDULER_STATE="OFF" && generate_keyboard && $CURL_BIN -k -s -X POST "https://api.telegram.org/bot$TOKEN/sendMessage" -d chat_id="$CHAT_ID" -d text="<b>Sched DISABLED</b> %E2%9D%8C" -d parse_mode="HTML" -d reply_markup="$KEYBOARD" ;;
    *"Reboot"*) reboot ;;
  esac

  if [ ! -z "$TARGET" ]; then
    sed -i "s/^power_target =.*/power_target = $TARGET/" $CONFIG
    $CURL_BIN -k -s -X POST "https://api.telegram.org/bot$TOKEN/sendMessage" -d chat_id="$CHAT_ID" -d text="<b>Power set to ${TARGET}W.</b> Rebooting... %F0%9F%94%84" -d parse_mode="HTML"
    sleep 2 && reboot
  fi

  if echo "$UPDATES" | grep -q "update_id"; then
    N_ID=$(echo "$UPDATES" | grep -o '"update_id":[0-9]*' | tail -n 1 | cut -d: -f2)
    echo $((N_ID + 1)) > $OFFSET_FILE
  fi
  sleep 5
done
