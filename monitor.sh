#!/bin/sh
# ---------------------------------------------------------
# Antminer Telegram Control Script (USD Market Data)
# Created by: lakshaydhiman999
# Updated: High Speed Performance (Load on Demand)
# ---------------------------------------------------------

# --- USER CONFIGURATION ---
TOKEN="YOUR_BOT_TOKEN_HERE"  # Replace with your Telegram Bot Token
CHAT_ID="YOUR_CHAT_ID_HERE"  # Replace with your Telegram Chat ID
CONFIG="/etc/bosminer.toml"
CONF_FILE="/etc/monitor.conf" 
OFFSET_FILE="/tmp/tg_offset"
NC_BIN="/etc/nc"
CURL_BIN="/etc/curl"

DROP_COUNT=0

# --- PERSISTENT LOGIC ---
if [ ! -f "$CONF_FILE" ]; then
    echo "HEAL=ON" > "$CONF_FILE"
    echo "BHEAL=ON" >> "$CONF_FILE"
    echo "SCHED=OFF" >> "$CONF_FILE"
fi

SELF_HEAL_STATE=$(grep "HEAL=" "$CONF_FILE" | cut -d= -f2)
BHEAL_STATE=$(grep "BHEAL=" "$CONF_FILE" | cut -d= -f2)
SCHEDULER_STATE=$(grep "SCHED=" "$CONF_FILE" | cut -d= -f2)

save_conf() {
    echo "HEAL=$SELF_HEAL_STATE" > "$CONF_FILE"
    echo "BHEAL=$BHEAL_STATE" >> "$CONF_FILE"
    echo "SCHED=$SCHEDULER_STATE" >> "$CONF_FILE"
}

sleep 50
echo "0" > $OFFSET_FILE

# --- HEAVY DATA FETCH (Runs ONLY on Status Update) ---
get_miner_data() {
    HOUR=$(date "+%H")
    LOGIN_IP=$(ifconfig eth0 | grep 'inet addr' | cut -d: -f2 | awk '{print $1}')
    [ -z "$LOGIN_IP" ] && LOGIN_IP=$(ip addr show eth0 | grep 'inet ' | awk '{print $2}' | cut -d/ -f1 | head -n 1)

    TARGET_W=$(grep "^power_target =" $CONFIG | awk -F'=' '{print $2}' | tr -d ' "')
    SUMMARY=$(echo '{"command":"summary"}' | $NC_BIN 127.0.0.1 4028)
    MHS_RAW=$(echo "$SUMMARY" | grep -o '"MHS 5s":[0-9.]*' | awk -F: '{print $2}')
    SPEED=$(awk "BEGIN {printf \"%.2f\", $MHS_RAW/1000000}")
    REAL_W=$(awk "BEGIN {printf \"%.0f\", $MHS_RAW * 0.00003488}")
    EFFICIENCY="34.88 W/Ths"

    ELAPSED=$(echo "$SUMMARY" | grep -o '"Elapsed":[0-9]*' | awk -F: '{print $2}')
    UP_D=$((ELAPSED/86400)); UP_H=$(((ELAPSED%86400)/3600)); UP_M=$(((ELAPSED%3600)/60))
    UP_STR="${UP_D}d ${UP_H}h ${UP_M}m"
    
    TEMPS_RAW=$(echo '{"command":"temps"}' | $NC_BIN 127.0.0.1 4028)
    T_AVG=$(echo "$TEMPS_RAW" | grep -o '"Chip":[0-9.]*' | head -n 1 | awk -F: '{print $2}' | cut -d. -f1)
    B1=$(echo "$TEMPS_RAW" | grep -o '"Board":[0-9.]*' | sed -n '1p' | cut -d: -f2); B2=$(echo "$TEMPS_RAW" | grep -o '"Board":[0-9.]*' | sed -n '2p' | cut -d: -f2); B3=$(echo "$TEMPS_RAW" | grep -o '"Board":[0-9.]*' | sed -n '3p' | cut -d: -f2)
    C1=$(echo "$TEMPS_RAW" | grep -o '"Chip":[0-9.]*' | sed -n '1p' | cut -d: -f2); C2=$(echo "$TEMPS_RAW" | grep -o '"Chip":[0-9.]*' | sed -n '2p' | cut -d: -f2); C3=$(echo "$TEMPS_RAW" | grep -o '"Chip":[0-9.]*' | sed -n '3p' | cut -d: -f2)

    DEVS_RAW=$(echo '{"command":"devs"}' | $NC_BIN 127.0.0.1 4028)
    B1_TH=$(echo "$DEVS_RAW" | grep -o '"MHS 5s":[0-9.]*' | sed -n '1p' | cut -d: -f2 | awk '{printf "%.2f", $1/1000000}')
    B2_TH=$(echo "$DEVS_RAW" | grep -o '"MHS 5s":[0-9.]*' | sed -n '2p' | cut -d: -f2 | awk '{printf "%.2f", $1/1000000}')
    B3_TH=$(echo "$DEVS_RAW" | grep -o '"MHS 5s":[0-9.]*' | sed -n '3p' | cut -d: -f2 | awk '{printf "%.2f", $1/1000000}')

    TOTAL_CHIPS=$(echo '{"command":"devdetails"}' | $NC_BIN 127.0.0.1 4028 | grep -o '"Chips":[0-9]*' | head -n 1 | cut -d: -f2)
    
    # Market Data in USD
    BTC_PRICE_USD=$($CURL_BIN -k -s "https://api.coingecko.com/api/v3/simple/price?ids=bitcoin&vs_currencies=usd" | grep -o '"usd":[0-9.]*' | awk -F: '{print $2}' | tr -d ' "')
    [ -z "$BTC_PRICE_USD" ] && BTC_PRICE_USD=0
    EARNINGS_USD=$(awk "BEGIN {printf \"%.2f\", $SPEED * $BTC_PRICE_USD * 0.0000000108}")

    P_URL=$(grep "url =" $CONFIG | grep -v "braiins" | head -n 1 | awk -F'=' '{print $2}' | tr -d ' "')
    P_ENABLED=$(grep -B 5 "$P_URL" $CONFIG | grep "enabled =" | head -n 1 | awk -F'=' '{print $2}' | tr -d ' "')

    MSG="<b>Miner Status Update</b> %F0%9F%93%8A%0A--------------------%0A<b>Login:</b> http://${LOGIN_IP}/ %F0%9F%8C%90%0A<b>Speed:</b> ${SPEED} TH/s %F0%9F%9A%80%0A<b>Temp:</b> ${T_AVG:-0} C %F0%9F%8C%A1%0A<b>Power:</b> ${REAL_W}W / ${TARGET_W}W %E2%9A%A1%0A<b>Efficiency:</b> ${EFFICIENCY}%0A<b>Uptime:</b> ${UP_STR} %F0%9F%95%92%0A%0A<b>Market Data:</b> %F0%9F%92%B0%0A<b>BTC Price:</b> $ ${BTC_PRICE_USD}%0A<b>Est. Daily:</b> $ ${EARNINGS_USD} %F0%9F%93%88%0A%0A<b>Board Health (In/Out | TH):</b> %F0%9F%9B%A1%0A- Board 1: ${B1:-0}C / ${C1:-0}C | ${B1_TH:-0} TH/s%0A- Board 2: ${B2:-0}C / ${C2:-0}C | ${B2_TH:-0} TH/s%0A- Board 3: ${B3:-0}C / ${C3:-0}C | ${B3_TH:-0} TH/s%0A<b>Total Chips:</b> ${TOTAL_CHIPS:-0} %E2%9C%85%0A%0A<b>Self-Heal:</b> ${SELF_HEAL_STATE} %F0%9F%94%A7%0A<b>Scheduler:</b> ${SCHEDULER_STATE} %F0%9F%93%85%0A<b>Board-Heal:</b> ${BHEAL_STATE} %F0%9F%94%A7"
}

generate_keyboard() {
    HEAL_BTN="Self-Heal: OFF"; [ "$SELF_HEAL_STATE" = "OFF" ] && HEAL_BTN="Self-Heal: ON"
    BHEAL_BTN="Board-Heal: OFF"; [ "$BHEAL_STATE" = "OFF" ] && BHEAL_BTN="Board-Heal: ON"
    SCHED_BTN="Scheduler: OFF"; [ "$SCHEDULER_STATE" = "OFF" ] && SCHED_BTN="Scheduler: ON"
    KEYBOARD="{\"keyboard\": [[{\"text\": \"Status Update\"}], [{\"text\": \"Set 1000W\"}, {\"text\": \"Set 2500W\"}], [{\"text\": \"Set 3000W\"}, {\"text\": \"Set 3200W\"}], [{\"text\": \"Ping Check\"}, {\"text\": \"$HEAL_BTN\"}], [{\"text\": \"$BHEAL_BTN\"}, {\"text\": \"$SCHED_BTN\"}], [{\"text\": \"Reboot\"}]], \"resize_keyboard\": true}"
}

generate_keyboard
$CURL_BIN -k -s -X POST "https://api.telegram.org/bot$TOKEN/sendMessage" -d chat_id="$CHAT_ID" -d text="<b>Miner System Online</b> %F0%9F%A4%96" -d parse_mode="HTML" -d reply_markup="$KEYBOARD"

while true; do
    OFFSET=$(cat $OFFSET_FILE)
    UPDATES=$($CURL_BIN -k -s "https://api.telegram.org/bot$TOKEN/getUpdates?offset=$OFFSET&timeout=5")

    if [ "$BHEAL_STATE" = "ON" ] || [ "$SELF_HEAL_STATE" = "ON" ]; then
        LITE_DEVS=$(echo '{"command":"devs"}' | $NC_BIN 127.0.0.1 4028)
        L_B1=$(echo "$LITE_DEVS" | grep -o '"MHS 5s":[0-9.]*' | sed -n '1p' | cut -d: -f2 | awk '{print $1/1000000}')
        L_B2=$(echo "$LITE_DEVS" | grep -o '"MHS 5s":[0-9.]*' | sed -n '2p' | cut -d: -f2 | awk '{print $1/1000000}')
        L_B3=$(echo "$LITE_DEVS" | grep -o '"MHS 5s":[0-9.]*' | sed -n '3p' | cut -d: -f2 | awk '{print $1/1000000}')
        
        if [ "$BHEAL_STATE" = "ON" ] && [ "$(awk "BEGIN {print ($L_B1 < 1.0 || $L_B2 < 1.0 || $L_B3 < 1.0)}")" -eq 1 ]; then
            if ping -c 1 google.com > /dev/null; then
                DROP_COUNT=$((DROP_COUNT + 1))
                [ "$DROP_COUNT" -eq 1 ] && $CURL_BIN -k -s -X POST "https://api.telegram.org/bot$TOKEN/sendMessage" -d chat_id="$CHAT_ID" -d text="<b>🚨 BOARD DROP DETECTED</b>%0AWaiting 10 mins..." -d parse_mode="HTML"
                [ "$DROP_COUNT" -ge 120 ] && reboot
            else DROP_COUNT=0; fi
        else DROP_COUNT=0; fi
    fi

    case "$UPDATES" in
        *"Status Update"*) get_miner_data && $CURL_BIN -k -s -X POST "https://api.telegram.org/bot$TOKEN/sendMessage" -d chat_id="$CHAT_ID" -d text="$MSG" -d parse_mode="HTML" ;;
        *"Set 1000W"*) TARGET=1000 ;;
        *"Set 2500W"*) TARGET=2500 ;;
        *"Set 3000W"*) TARGET=3000 ;;
        *"Set 3200W"*) TARGET=3200 ;;
        *"Ping Check"*)
            LAT=$(ping -c 3 google.com | tail -1 | awk -F '/' '{print $5}')
            $CURL_BIN -k -s -X POST "https://api.telegram.org/bot$TOKEN/sendMessage" -d chat_id="$CHAT_ID" -d text="<b>Latency:</b> ${LAT:-0} ms" -d parse_mode="HTML" ;;
        *"Self-Heal: ON"*) SELF_HEAL_STATE="ON" && save_conf && generate_keyboard && $CURL_BIN -k -s -X POST "https://api.telegram.org/bot$TOKEN/sendMessage" -d chat_id="$CHAT_ID" -d text="<b>Heal ON</b>" -d parse_mode="HTML" -d reply_markup="$KEYBOARD" ;;
        *"Self-Heal: OFF"*) SELF_HEAL_STATE="OFF" && save_conf && generate_keyboard && $CURL_BIN -k -s -X POST "https://api.telegram.org/bot$TOKEN/sendMessage" -d chat_id="$CHAT_ID" -d text="<b>Heal OFF</b>" -d parse_mode="HTML" -d reply_markup="$KEYBOARD" ;;
        *"Board-Heal: ON"*) BHEAL_STATE="ON" && save_conf && generate_keyboard && $CURL_BIN -k -s -X POST "https://api.telegram.org/bot$TOKEN/sendMessage" -d chat_id="$CHAT_ID" -d text="<b>Board Heal ON</b>" -d parse_mode="HTML" -d reply_markup="$KEYBOARD" ;;
        *"Board-Heal: OFF"*) BHEAL_STATE="OFF" && save_conf && generate_keyboard && $CURL_BIN -k -s -X POST "https://api.telegram.org/bot$TOKEN/sendMessage" -d chat_id="$CHAT_ID" -d text="<b>Board Heal OFF</b>" -d parse_mode="HTML" -d reply_markup="$KEYBOARD" ;;
        *"Scheduler: ON"*) SCHEDULER_STATE="ON" && save_conf && generate_keyboard && $CURL_BIN -k -s -X POST "https://api.telegram.org/bot$TOKEN/sendMessage" -d chat_id="$CHAT_ID" -d text="<b>Sched ON</b>" -d parse_mode="HTML" -d reply_markup="$KEYBOARD" ;;
        *"Scheduler: OFF"*) SCHEDULER_STATE="OFF" && save_conf && generate_keyboard && $CURL_BIN -k -s -X POST "https://api.telegram.org/bot$TOKEN/sendMessage" -d chat_id="$CHAT_ID" -d text="<b>Sched OFF</b>" -d parse_mode="HTML" -d reply_markup="$KEYBOARD" ;;
        *"Reboot"*) reboot ;;
    esac

    if [ ! -z "$TARGET" ]; then
        sed -i "s/^power_target =.*/power_target = $TARGET/" $CONFIG
        $CURL_BIN -k -s -X POST "https://api.telegram.org/bot$TOKEN/sendMessage" -d chat_id="$CHAT_ID" -d text="<b>Rebooting to ${TARGET}W...</b>" -d parse_mode="HTML"
        sleep 2 && reboot
    fi

    if echo "$UPDATES" | grep -q "update_id"; then
        N_ID=$(echo "$UPDATES" | grep -o '"update_id":[0-9]*' | tail -n 1 | cut -d: -f2)
        echo $((N_ID + 1)) > $OFFSET_FILE
    fi
    sleep 2
done
