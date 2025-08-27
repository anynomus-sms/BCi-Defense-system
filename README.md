# 🛡️ BCI NetWatch  
*A lightweight suspicious connection detector*  
**by anonymous-sms**  

---

## 📥 Installation
1. Open your terminal (Linux recommended: Kali, Ubuntu, Debian).  
2. Create a new file called `bci_netwatch.sh`:  
   ```bash
   nano bci_netwatch.sh

    Copy + paste the script code into it.

    Save and exit (CTRL+O, Enter, CTRL+X).

    Make it executable:

    chmod +x bci_netwatch.sh

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

    [1] List active connections
    Shows all currently active IP connections on your system.

    [2] Update known hosts
    Saves your current “safe” IPs/domains into known_hosts.txt.

        Run this first so common services (Google, GitHub, etc.) are marked as trusted.

    [3] Scan suspicious connections
    Detects new or unknown IPs.
    When something new pops up, you decide:

        (a) → Allow → add it to the trusted list.

        (b) → Block → drop traffic to that IP using iptables.

        (i) → Ignore → skip just this time.

    [0] Exit
    Quit the tool.

📂 Files

    known_hosts.txt → the database of trusted IPs.

    bci_netwatch.log → all activity logs (with watermark by anonymous-sms).

⚠️ Notes

    This tool only monitors networks you’ve actually connected to before.

    It won’t randomly scan the entire internet (safe for personal use).

    If a weird connection shows up, you’ll get an alert and can block it instantly.

    Use this responsibly — it’s meant for learning and local defense.

🌟 Example Workflow

    First run → choose [2] Update known hosts → this marks all your usual connections as safe.

    Later → run [3] Scan suspicious connections → if a new IP appears (like 185.xxx.xxx.xxx), you’ll be alerted.

    Decide whether to allow, block, or ignore.
