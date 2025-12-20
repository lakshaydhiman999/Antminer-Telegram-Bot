#!/bin/sh
# ---------------------------------------------------------
# Antminer Telegram Control Script
# Created by: lakshaydhiman999
# GitHub: lakshaydhiman999-dev
# ---------------------------------------------------------

# --- CONFIGURATION ---
TOKEN="YOUR_BOT_TOKEN_HERE"
CHAT_ID="YOUR_CHAT_ID_HERE"

CONFIG="/etc/bosminer.toml"
OFFSET_FILE="/tmp/tg_offset"
NC_BIN="/etc/nc"

# Wait for system and network services to initialize
sleep 30
echo "0" > $OFFSET_FILE

get_miner_data() {
    TIME=$(date "+%H:%M")
    LOGIN_IP=$(ifconfig eth0 | grep 'inet addr' | cut -d: -f2 | awk '{print $1}')
    [ -z "$LOGIN_IP" ] && LOGIN_IP=$(ip addr show eth0 | grep 'inet ' | awk '{print $2}' | cut -d/ -f1)

    WATTS=$(grep "^power_target =" $CONFIG | awk -F'=' '{print $2}' | tr -d ' "')
    SUMMARY=$(echo '{"command":"summary"}' | $NC_BIN 127.0.0.1 4028)
    SPEED=$(echo "$SUMMARY" | grep -o '"MHS 5s":[0-9.]*' | awk -F: '{printf "%.2f", $2/1000000}')
    ELAPSED=$(echo "$SUMMARY" | grep -o '"Elapsed":[0-9]*' | awk -F: '{print $2}')
    
    UP_D=$((ELAPSED/86400)); UP_H=$(((ELAPSED%86400)/3600)); UP_M=$(((ELAPSED%3600)/60))
    UP_STR="${UP_D}d ${UP_H}h ${UP_M}m"
    
    TEMP=$(echo '{"command":"temps"}' | $NC_BIN 127.0.0.1 4028 | grep -o '"Chip":[0-9.]*' | head -n 1 | awk -F: '{print $2}' | cut -d. -f1)
    
    P_URL=$(grep "url =" $CONFIG | grep -v "braiins" | head -n 1 | awk -F'=' '{print $2}' | tr -d ' "')
    P_ENABLED=$(grep -B 5 "$P_URL" $CONFIG | grep "enabled =" | head -n 1 | awk -F'=' '{print $2}' | tr -d ' "')

    MSG="Miner Status Update%0A--------------------%0ALogin: http://${LOGIN_IP}/%0ASpeed: ${SPEED} TH/s%0ATemp: ${TEMP} C%0APower: ${WATTS}W%0AUptime: ${UP_STR}%0A%0APool: ${P_URL}%0A--------------------%0ATime: ${TIME}"
}

KEYBOARD='{"keyboard": [[{"text": "Status"}], [{"text": "Set 1000W"}, {"text": "Set 2500W"}], [{"text": "Set 2900W"}, {"text": "Set 3200W"}], [{"text": "Reboot"}, {"text": "Created by Lakshay"}]], "resize_keyboard": true}'

get_miner_data
/etc/curl -k -s -X POST "https://api.telegram.org/bot$TOKEN/sendMessage" -d chat_id="$CHAT_ID" -d text="Miner System Online" -d reply_markup="$KEYBOARD"

while true; do
  OFFSET=$(cat $OFFSET_FILE)
  UPDATES=$(/etc/curl -k -s "https://api.telegram.org/bot$TOKEN/getUpdates?offset=$OFFSET&timeout=5")
  
  get_miner_data
  [ "$TEMP" -ge 80 ] && /etc/curl -k -s -X POST "https://api.telegram.org/bot$TOKEN/sendMessage" -d chat_id="$CHAT_ID" -d text="🔥 ALERT: High Temp ${TEMP}C!"

  case "$UPDATES" in
    *"Status"*) /etc/curl -k -s -X POST "https://api.telegram.org/bot$TOKEN/sendMessage" -d chat_id="$CHAT_ID" -d text="$MSG" ;;
    *"Created by Lakshay"*) /etc/curl -k -s -X POST "https://api.telegram.org/bot$TOKEN/sendMessage" -d chat_id="$CHAT_ID" -d text="🚀 Script created by lakshaydhiman999%0AGitHub: https://github.com/lakshaydhiman999" ;;
    *"Set 1000W"*) TARGET=1000 ;;
    *"Set 2500W"*) TARGET=2500 ;;
    *"Set 2900W"*) TARGET=2900 ;;
    *"Set 3200W"*) TARGET=3200 ;;
    *"Reboot"*) reboot ;;
  esac

  if [ ! -z "$TARGET" ]; then
    sed -i "s/^power_target =.*/power_target = $TARGET/" $CONFIG
    reboot
  fi

  if echo "$UPDATES" | grep -q "update_id"; then
    NEXT_ID=$(echo "$UPDATES" | grep -o '"update_id":[0-9]*' | tail -n 1 | cut -d: -f2)
    echo $((NEXT_ID + 1)) > $OFFSET_FILE
  fi
  sleep 5
done
