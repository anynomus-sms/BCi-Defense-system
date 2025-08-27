# 🛡️ BCI NetWatch
*A lightweight suspicious connection detector & defense helper*  
**by anonymous-sms**

---

## 📖 About
**BCI NetWatch** is a simple bash-based monitoring tool designed to help you keep track of active connections on your Linux machine.  
It can detect **unknown or suspicious IPs**, give you options to **allow / block / ignore**, and log everything with a watermark.  

It’s meant for **learning, experimenting, and local defense**.  
Not a replacement for professional IDS/IPS tools like Snort or Suricata.  

---

## 📥 Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/anonymous-sms/bci-netwatch.git
   cd bci-netwatch

    Give execution permission

chmod +x bci_netwatch.sh

(Optional) Check dependencies
This script uses basic Linux commands:

    netstat or ss

    awk

    iptables

On Debian/Ubuntu/Kali, you can install them with:

    sudo apt update
    sudo apt install net-tools iptables

▶️ Usage

Run the tool:

./bci_netwatch.sh

You’ll see the main menu:

===== BCI NetWatch Menu =====
       by anonymous-sms
=============================
1) List active connections
2) Update known hosts
3) Scan suspicious connections
0) Exit
=============================

🛠 Features
1. List Active Connections

Shows all current IP connections on your system (similar to netstat -tunap).
Useful to understand which services are connected right now.
2. Update Known Hosts

Saves the current “safe” connections into known_hosts.txt.

    First time you run the script → do this step.

    Common IPs like Google, GitHub, DNS servers will be saved here.

    Anything in this list won’t be flagged as suspicious later.

3. Scan Suspicious Connections

Checks current connections against your known_hosts.txt.

    If an IP is not in the safe list, you’ll get an alert.

    You can choose:

        (a) Allow → add it permanently to trusted list.

        (b) Block → block the IP using iptables.

        (i) Ignore → skip only for this session.

Example:

Suspicious connection detected: 185.xxx.xxx.xxx
[a] Allow / [b] Block / [i] Ignore ?

4. Exit

Cleanly quit the program.
📂 Files Generated

    known_hosts.txt → your personal whitelist (trusted IPs).

    bci_netwatch.log → log file with all detections & actions.
    (Every log entry includes the watermark by anonymous-sms).

🌟 Example Workflow

    First time setup

./bci_netwatch.sh

→ Choose [2] Update known hosts.
This will mark all normal connections (Google, GitHub, DNS, etc.) as trusted.

Monitoring mode
Run again later and pick [3] Scan suspicious connections.

    If a new IP shows up, you’ll get an alert.

    Decide if you want to allow, block, or ignore.

Blocking suspicious IPs
If you select block, NetWatch will automatically add an iptables rule to drop packets from that IP.
You can review blocked IPs with:

sudo iptables -L -n

Logs
All activity is stored in bci_netwatch.log.
Example log:

    [2025-08-27 20:15] Suspicious IP detected: 185.xxx.xxx.xxx → Action: BLOCKED
    -- by anonymous-sms

⚠️ Notes & Limitations

    This tool only monitors networks you’ve already connected to.

    It doesn’t scan the entire internet (safe for personal use).

    It’s not stealthy; advanced users might notice iptables rules.

    Intended for educational / competition projects (e.g. ICEP/ICEO).

    Do not use it for offensive security or against networks you don’t own.

💡 Ideas for Future Improvements

    Add a simple web dashboard to visualize suspicious IPs.

    Export logs in JSON/CSV for analysis.

    Integrate with email or Telegram bot alerts.

    Auto-remove old allowed hosts after X days.

👤 Credits

Created with ⚡ by anonymous-sms

