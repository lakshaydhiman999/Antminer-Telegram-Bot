# Antminer-Telegram-Bot
Remote control and monitor Antminers (Braiins OS) directly via Telegram Bot without any external server or PC."

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
