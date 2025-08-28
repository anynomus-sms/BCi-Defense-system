# 🛡️ BCI NetWatch (SAFE)
_A Local Network & System Audit Tool_  
by **anonymous-sms**

---

## 📖 About

**BCI NetWatch (SAFE)** is a simple Bash-based tool for **local network & system monitoring** on Linux (tested on Kali Linux).  
This script does **not perform packet sniffing or MITM attacks** against other users.  
All features are focused on **auditing your own device**, **detecting devices connected to your Wi-Fi**,  
and **checking open ports & connections from your local machine**.

Purpose: education, self-learning in cybersecurity, and safe network auditing ⚡

---

## ✨ Features
- 🔄 **Auto-update** (if cloned via `git clone`)
- ✅ **Dependency check & auto bug detection**
- 🌐 **Device discovery** in local network (ARP / nmap ping scan)
- 📡 **Internet Flow monitor** (see your processes → remote IP/ports)
- 🔍 **Scan open/listening ports** on your machine (with option to stop PID/service)
- 📝 **Known Hosts** list (save hosts/IPs that connected before)
- 🧪 **Simulated test** (make a dummy connection to example.com)
- 📂 **Auto logging** into `./logs/`

---

## ⚙️ Requirements
- Linux (Kali/Ubuntu/Debian recommended)
- `bash`, `git`, `ss`, `nmap`, `arp-scan`, `curl`
- Root privileges (`sudo`)

Install dependencies on Kali/Ubuntu:
```bash
sudo apt update
sudo apt install -y git nmap arp-scan curl net-tools

🚀 Installation

Clone the repository:

git clone https://github.com/anynomus-sms/BCi-Defense-system.git
cd BCi-Defense-system

Make the script executable:

chmod +x bci_netwatch_safe.sh

Run it:

./bci_netwatch.sh

🕹️ Usage

When you run the script, you’ll see an interactive menu:

========================================
   BCI NetWatch (SAFE) - by anonymous-sms
   Local monitoring & audit tools (Kali)
========================================
1) Auto-update (git) & quick self-test
2) Check dependencies (auto bug detection)
3) List devices on local network (ARP discovery)
4) Show Internet Flow (local machine processes -> remote)
5) Scan local open/listening ports (and option to stop PID)
6) Update known hosts (based on local established connections)
7) Show known hosts
8) Simulate test connection
0) Exit

Examples:

    Choose [3] → to see all devices currently connected to your Wi-Fi.

    Choose [4] → to see which apps/processes on your laptop are connecting to the internet.

    Choose [5] → to scan for open ports on your machine and stop unnecessary services.

📒 Notes

    This tool does not intercept or spy on other users’ traffic.
    For deeper audits, use router/AP logs or enterprise solutions.

    Some features require sudo (you’ll be asked for your password).

    Logs are saved inside logs/ with filenames like netwatch_YYYY-MM-DD.log.

🛡️ Disclaimer

Use this tool only on networks you own or have permission to audit.
The author is not responsible for any misuse.
BCI NetWatch (SAFE) is built for educational and ethical cybersecurity learning.

✨ Stay safe, hack ethically — by anonymous-sms
