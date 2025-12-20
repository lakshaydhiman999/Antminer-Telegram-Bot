# Antminer-Telegram-Bot
Remote control and monitor Antminers (Braiins OS) directly via Telegram Bot without any external server or PC."

## ✨ Key Features

### 📊 1. Real-Time Status Dashboard

Get a complete snapshot of your miner's health with a single click. The status update includes:

* **Live Hashrate:** Current mining speed (TH/s).
* **Thermal Stats:** Average chip temperature and individual PCB temperatures.
* **Chip Health:** Displays total active chips count (e.g., 88 Chips).
* **Power Usage:** Current power consumption in Watts.
* **Pool Info:** Active pool URL and connection status.
* **Uptime:** detailed uptime counter (Days, Hours, Minutes).

### 📅 2. Smart Power Scheduler (Day/Night Mode)

Automate your power consumption based on electricity rates or temperature preferences:

* **Day Mode (10 AM - 10 PM):** Automatically drops power to **2500W** to prevent overheating during the day.
* **Night Mode (10 PM - 10 AM):** Automatically boosts power to **3200W** to maximize profits during cooler hours.
* *Toggleable via Telegram Button.*

### 🩹 3. Auto Self-Healing (Watchdog)

Never lose mining time again. The script monitors your hashrate continuously:

* **Zero Hashrate Detection:** If the miner stops hashing (0 TH/s) for **40 minutes**, the script automatically reboots the system to fix software glitches.
* *Toggleable via Telegram Button.*

### 🛡️ 4. Safety & Alerts

* **🔥 High Temp Alert:** Instantly sends a warning notification if the average chip temperature exceeds **80°C**.
* **Emoji Encoding Fix:** Solves the common `??` display bug on miner terminals by placing emojis at the end of text strings.

### 🎮 5. Remote Control Center

Control your hardware from anywhere without logging into the web interface:

* **Power Profiles:** One-tap buttons to set power targets (1000W, 2500W, 3000W, 3200W).
* **Remote Reboot:** Restart the miner remotely if it acts up.

### 📡 6. Network Diagnostics

* **Ping Check:** Checks internet connectivity and latency (ms) to Google servers directly from the miner.
* **IP Display:** Shows the current Local IP address for easy web access.

## 🛠️ Performance

* **Lightweight:** Uses `sleep 5` intervals to ensure <1% CPU usage.
* **Safe:** Writes to config only when necessary, preserving NAND flash life.
* **Reliable:** Built-in loop protection and network timeout handling.

---

🛠️ Installation Guide
1. API Preparation
Initialize your teligram messaging bot interface to receive data.

Secure your unique API Tokens and access credentials.

2. Dependency Setup (Curl)
Download: Obtain the AARCH64 static binary for Curl. https://github.com/moparisthebest/static-curl/releases/tag/v8.11.0

Rename: Change the filename to curl.

Upload: Use WinSCP to transfer the file to the /etc/ directory on your miner.

Apply Permissions: SSH into your miner (ssh root@yourminerIP) and run:
```bash
chmod +x /etc/curl
```
4. API Connector (Netcat)
Install the network utility to interface with the BOSminer API. Execute this in your terminal:
```bash
/etc/curl -k -L -o /etc/nc https://busybox.net/downloads/binaries/1.31.0-defconfig-multiarch-musl/busybox-armv8l

chmod +x /etc/nc
```
4. Deploy Management Script
Create monitor.sh in the /etc/ directory.

Paste the code from this repository into the file.
Configuration: Insert your specific TOKEN and CHAT_ID in the script's header.
Final Permission: Enable execution:
```bash
chmod +x /etc/monitor.sh
```
5. Persistent Execution
To ensure the service resumes after a power cycle, edit /etc/rc.local (or /etc/rcS) and append this line at the bottom:
```bash
/etc/monitor.sh &
```

---

## ❓ Frequently Asked Questions (FAQ)

**Q: Is this script safe for my miner?**
**A:** Yes. It uses the official BOSminer API (read-only for status) and only modifies the power target in the config file when you press a button.

**Q: Does it slow down the hashrate?**
**A:** No. It is a lightweight shell script that consumes less than 1% of the miner's CPU.

**Q: What happens if my internet goes down?**
**A:** The script will wait for connectivity. We have added a `sleep` command and loop checks to ensure it doesn't crash during network loss.

**Q: Can I use this on Stock Firmware?**
**A:** No. This is specifically designed for **Braiins OS** because it relies on the `.toml` config and BOSminer API.

---


## 🔧 Component Troubleshooting (FAQ Style)

**Q: Why do I get a "Permission denied" error when running the script?** **A:** This happens because the binaries are not marked as executable. You must run `chmod +x /etc/curl /etc/nc /etc/monitor.sh` in your terminal to fix this.

**Q: The script says "command not found" for Curl or NC. What should I do?** **A:** Verify that the files are actually inside the `/etc/` directory. Also, ensure you downloaded the **AARCH64** version, as the miner's hardware will not recognize other architectures.

**Q: My bot is online but not sending any messages. How can I test it?** **A:** First, check if your miner has internet by running `ping api.telegram.org`. If it pings, double-check your **API Token** for typos; even one wrong character will break the connection.

**Q: Why are the Status updates showing empty or zero values?** **A:** This usually means the script cannot talk to the miner's internal API. Ensure **BOSminer** is running and that the API port **4028** is not blocked by any local settings.

**Q: Is the connection to Telegram secure?** **A:** Yes, but we use the `-k` flag with Curl to bypass SSL certificate verification. This is necessary because some miner firmware environments have outdated root certificates.

---
