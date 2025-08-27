#!/usr/bin/env bash
# NetWatch v4 - robust WiFi & suspicious-connection watcher
# Watermark: by anonymous-sms
# Use only on networks/machines you own. Responsible use only.

set -euo pipefail
shopt -s nullglob

KNOWN_FILE="known_hosts.txt"
LOGFILE="bci_netwatch.log"
TMP_DIR="./.netwatch_tmp"
mkdir -p "$TMP_DIR"
CURRENT_DEVICES="$TMP_DIR/current_devices.txt"
CURRENT_CONN="$TMP_DIR/current_connections.txt"

log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $* (by anonymous-sms)" | tee -a "$LOGFILE"
}

check_deps() {
  local miss=()
  for c in ss ip nmap awk sed grep sort uniq curl arp; do
    command -v "$c" >/dev/null 2>&1 || miss+=("$c")
  done
  if [ ${#miss[@]} -ne 0 ]; then
    echo "Missing commands: ${miss[*]}"
    echo "Install common deps: sudo apt update && sudo apt install -y iproute2 nmap curl"
    return 1
  fi
  return 0
}

ensure_files() {
  [ -f "$KNOWN_FILE" ] || { echo "# known hosts - added by netwatch" > "$KNOWN_FILE"; }
  touch "$LOGFILE"
}

get_iface_net() {
  IFACE=$(ip route | awk '/default/ {print $5; exit}')
  if [ -z "$IFACE" ]; then
    echo ""
    return 1
  fi
  NET=$(ip -o -f inet addr show "$IFACE" | awk '{print $4; exit}')
  if [ -z "$NET" ]; then
    echo ""
    return 1
  fi
  echo "$IFACE $NET"
}

list_devices() {
  log "Start WiFi device scan..."
  local info
  if ! info=$(get_iface_net); then
    echo "Could not detect default interface or IPv4 address. Are you connected to a network?"
    read -p "Press Enter to continue..."
    return 1
  fi
  read -r IFACE NET <<<"$info"
  log "Interface: $IFACE  Network: $NET"

  if ! command -v nmap >/dev/null 2>&1; then
    echo "nmap not installed. Install: sudo apt install nmap"
    read -p "Press Enter to continue..."
    return 1
  fi

  # do an ARP/host discovery (requires sudo for MAC)
  sudo nmap -sn "$NET" -oG - | awk '/Up$/{print $2}' > "$CURRENT_DEVICES" || true

  # Try to pair IP -> MAC using arp cache (nmap may have populated it)
  > "$TMP_DIR/current_devices_detailed.txt"
  while read -r ip; do
    [ -z "$ip" ] && continue
    mac=$(arp -n "$ip" 2>/dev/null | awk '/ether/ {print $3}')
    [ -z "$mac" ] && mac="N/A"
    echo -e "$ip\t$mac" >> "$TMP_DIR/current_devices_detailed.txt"
  done < "$CURRENT_DEVICES"

  echo "Devices found on network $NET :"
  if [ -s "$TMP_DIR/current_devices_detailed.txt" ]; then
    column -t -s $'\t' "$TMP_DIR/current_devices_detailed.txt"
  else
    echo "(no devices found)"
  fi
  echo "Total devices: $(wc -l < "$CURRENT_DEVICES" 2>/dev/null || echo 0)"
  read -p "Press Enter to return to menu..."
}

scan_suspicious() {
  log "Scanning active remote connections..."
  # collect remote endpoints: remove port, handle [IPv6]:port and IPv4:port
  ss -tunp | tail -n +2 | awk '{print $5}' | sed -E 's/^\[//; s/\]$//; s/:([0-9]+)$//' | sed '/^$/d' | sort -u > "$CURRENT_CONN"

  found=false
  while read -r ip; do
    [ -z "$ip" ] && continue
    # skip local loopback
    if [[ "$ip" == "0.0.0.0" || "$ip" == "127."* || "$ip" == "::1" ]]; then
      continue
    fi
    if ! grep -Fxq "$ip" "$KNOWN_FILE"; then
      found=true
      mac=$(arp -n "$ip" 2>/dev/null | awk '/ether/ {print $3}')
      log "Suspicious connection: $ip mac:${mac:-N/A}"
      echo "⚠ Suspicious connection detected: $ip  MAC:${mac:-N/A}"
      echo "[a] Allow  [b] Block (iptables)  [i] Ignore"
      read -rp "Choose: " choice
      case "$choice" in
        a|A)
          echo "$ip" >> "$KNOWN_FILE"
          sort -u "$KNOWN_FILE" -o "$KNOWN_FILE"
          log "Allowed $ip"
          ;;
        b|B)
          log "Blocking $ip"
          sudo iptables -I OUTPUT -d "$ip" -j REJECT
          sudo iptables -I INPUT -s "$ip" -j DROP
          log "Blocked $ip via iptables"
          ;;
        i|I)
          log "Ignored $ip"
          ;;
        *)
          echo "Unknown choice, ignoring."
          log "Ignored $ip (invalid choice)"
          ;;
      esac
    fi
  done < "$CURRENT_CONN"

  if ! $found; then
    echo "✅ No suspicious remote connections found."
  fi
  read -p "Press Enter to return to menu..."
}

show_known() {
  echo "Known hosts (trusted):"
  nl -ba "$KNOWN_FILE" 2>/dev/null || echo "(none)"
  read -p "Press Enter to continue..."
}

simulate_test() {
  echo "Simulating outgoing connection to example.com (quick test)..."
  # run in background to create an outgoing TCP connection
  curl -sS https://example.com >/dev/null &
  sleep 1
  echo "Done. Now run 'Scan suspicious connections' to see the new remote IP."
  read -p "Press Enter to continue..."
}

view_iptables() {
  sudo iptables -L -n --line-numbers
  read -p "Press Enter to continue..."
}

cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

# ==== main ====
if ! check_deps; then
  echo "Please install missing dependencies and run again."
fi
ensure_files

while true; do
  clear
  cat <<'EOF'
==============================
   NetWatch v4  —  by anonymous-sms
==============================
EOF
  echo "1) Show devices on WiFi"
  echo "2) Scan suspicious remote connections"
  echo "3) Show known hosts"
  echo "4) Simulate outgoing connection (test)"
  echo "5) View iptables blocked rules"
  echo "0) Exit"
  read -rp "Choose: " opt
  case "$opt" in
    1) list_devices ;;
    2) scan_suspicious ;;
    3) show_known ;;
    4) simulate_test ;;
    5) view_iptables ;;
    0) exit 0 ;;
    *) echo "Invalid option"; sleep 1 ;;
  esac
done
REPO_URL="https://github.com/anonymous-sms/netwatch.git"
LOCAL_DIR="$(pwd)"

check_update() {
  if [ -d "$LOCAL_DIR/.git" ]; then
    echo "🔄 Checking for updates..."
    git fetch origin main >/dev/null 2>&1
    LOCAL=$(git rev-parse @)
    REMOTE=$(git rev-parse @{u})
    if [ "$LOCAL" != "$REMOTE" ]; then
      echo "⚠ Update available! Updating now..."
      git pull origin main
      chmod +x netwatch_v4.sh
      echo "✅ Updated. Please re-run the script."
      exit 0
    else
      echo "✅ Already up-to-date."
    fi
  fi
}


