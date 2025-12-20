# Antminer-Telegram-Bot
Remote control and monitor Antminers (Braiins OS) directly via Telegram Bot without any external server or PC."

🛠️ Installation Guide
1. API Preparation
Initialize your teligram messaging bot interface to receive data.

Secure your unique API Tokens and access credentials.

2. Dependency Setup (Curl)
Download: Obtain the AARCH64 static binary for Curl.
Rename: Change the filename to curl.
Upload: Use WinSCP to transfer the file to the /etc/ directory on your miner.
Apply Permissions: SSH into your miner (ssh root@yourminerIP) and run:

chmod +x /etc/curl

4. API Connector (Netcat)
Install the network utility to interface with the BOSminer API. Execute this in your terminal:

/etc/curl -k -L -o /etc/nc https://busybox.net/downloads/binaries/1.31.0-defconfig-multiarch-musl/busybox-armv8l
chmod +x /etc/nc

4. Deploy Management Script
Create monitor.sh in the /etc/ directory.

Paste the code from this repository into the file.
Configuration: Insert your specific TOKEN and CHAT_ID in the script's header.
Final Permission: Enable execution:

chmod +x /etc/monitor.sh

5. Persistent Execution
To ensure the service resumes after a power cycle, edit /etc/rc.local (or /etc/rcS) and append this line at the bottom:

/etc/monitor.sh &
