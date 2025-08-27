#!/bin/bash
# ======================================
#  BCI Defense System - NetWatch
#  by anonymous-sms
# ======================================

REPO_URL="https://github.com/anynomus-sms/BCi-Defense-system.git"

# === Auto update check ===
check_update() {
  if git rev-parse --is-inside-work-tree &>/dev/null; then
    echo "🔄 Checking for updates from GitHub..."
    git fetch origin >/dev/null 2>&1
    LOCAL=$(git rev-parse @)
    REMOTE=$(git rev-parse @{u} 2>/dev/null)
    if [ "$LOCAL" != "$REMOTE" ] && [ -n "$REMOTE" ]; then
      echo "⚠ Update available! Pulling latest changes..."
      git pull --rebase
      chmod +x bci_netwatch.sh
      echo "✅ Updated to the latest version. Please re-run the script."
      exit 0
    else
      echo "✅ Already up-to-date."
    fi
  else
    echo "⚠ Not a git repo, skipping update check."
  fi
}

# === Show connected devices on local WiFi ===
show_connected_devices() {
  echo "📡 Scanning for devices on your WiFi... (by anonymous-sms)"
  if command -v arp-scan &>/dev/null; then
    sudo arp-scan --localnet
  else
    echo "⚠ 'arp-scan' not installed. Installing..."
    sudo apt update && sudo apt install -y arp-scan
    sudo arp-scan --localnet
  fi
}

# === Show processes currently using internet in table ===
show_internet_flow() {
  echo "🌐 Active Internet Flow (Processes using internet) (by anonymous-sms)"
  echo "------------------------------------------------------------"
  printf "%-25s %-8s %-15s\n" "Peer IP" "Port" "Process"
  echo "------------------------------------------------------------"
  sudo ss -tunp | awk 'NR>1 {print $5 "\t" $7}' | \
  while IFS=$'\t' read -r addr proc; do
    ip=$(echo "$addr" | cut -d':' -f1)
    port=$(echo "$addr" | cut -d':' -f2)
    pname=$(echo "$proc" | sed -n 's/.*users:(("\([^"]*\).*/\1/p')
    if [ -z "$pname" ]; then pname="unknown"; fi
    printf "%-25s %-8s %-15s\n" "$ip" "$port" "$pname"
  done
  echo "------------------------------------------------------------"
}

# === Scan open ports on current device (local system) ===
scan_open_ports() {
  echo "🔍 Scanning for open ports on this system... (by anonymous-sms)"
  echo "------------------------------------------------------------"
  if command -v netstat &>/dev/null; then
    sudo netstat -tulnp | grep LISTEN
  elif command -v ss &>/dev/null; then
    sudo ss -tulnp | grep LISTEN
  else
    echo "⚠ Neither 'netstat' nor 'ss' is available. Please install net-tools."
  fi
  echo "------------------------------------------------------------"
  echo "⚠ Reminder: Open ports are potential entry points."
  echo "   Close unused services for better security. (by anonymous-sms)"
}

# === Menu ===
main_menu() {
  clear
  echo "=============================="
  echo "  🔐 BCI NetWatch System"
  echo "  by anonymous-sms"
  echo "=============================="
  echo "1) Check for updates"
  echo "2) Show devices on WiFi"
  echo "3) Show Internet Flow (apps using internet)"
  echo "4) Show Open Ports (local system)"
  echo "5) Exit"
  echo
  read -p "Choose an option [1-5]: " choice
  case $choice in
    1) check_update ;;
    2) show_connected_devices ;;
    3) show_internet_flow ;;
    4) scan_open_ports ;;
    5) echo "👋 Bye! Stay safe online! (by anonymous-sms)"; exit 0 ;;
    *) echo "❌ Invalid option";;
  esac
  echo
  read -p "Press Enter to return to menu..."
  main_menu
}

# === Run ===
check_update
main_menu
