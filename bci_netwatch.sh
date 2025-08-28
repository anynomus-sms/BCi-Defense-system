#!/usr/bin/env bash
# ======================================
#  BCI NetWatch (SAFE) - Audit & Local Monitoring
#  by anonymous-sms
#  NOTE: This script does NOT perform MITM, sniffing, or intercept other users.
#        Use only on networks you own/administrate and for legal/audit purposes.
# ======================================

set -euo pipefail
IFS=$'\n\t'

# Config
REPO_URL="https://github.com/anynomus-sms/BCi-Defense-system.git"
SCRIPT_NAME="$(basename "$0")"
LOGDIR="./logs"
LOGFILE="$LOGDIR/netwatch_$(date +%F).log"
KNOWN_FILE="known_hosts.txt"
TMP_DIR="./.netwatch_tmp"
mkdir -p "$LOGDIR" "$TMP_DIR"

watermark() { echo " (by anonymous-sms)"; }

# --- Logging helper ---
log() {
  local msg="$*"
  local ts
  ts="$(date '+%Y-%m-%d %H:%M:%S')"
  echo "[$ts] $msg$(watermark)" | tee -a "$LOGFILE"
}

# --- Auto-update (works only if repo was cloned via git) ---
check_update() {
  if git rev-parse --is-inside-work-tree &>/dev/null; then
    log "Checking for updates from git..."
    # safe fetch
    if git fetch origin >/dev/null 2>&1; then
      local local_rev remote_rev
      local_rev=$(git rev-parse @)
      remote_rev=$(git rev-parse @{u} 2>/dev/null || echo "")
      if [ -n "$remote_rev" ] && [ "$local_rev" != "$remote_rev" ]; then
        log "Update available: pulling latest changes..."
        if git pull --rebase --autostash; then
          chmod +x "$SCRIPT_NAME" 2>/dev/null || true
          log "Update applied. Please re-run the script."
          exit 0
        else
          log "Auto-update failed: please run 'git pull' manually."
        fi
      else
        log "Already up-to-date."
      fi
    else
      log "Git fetch failed. Skipping update check."
    fi
  else
    log "Not a git repo — skipping auto-update."
  fi
}

# --- Dependency check & basic auto bug detection ---
check_deps() {
  log "Checking required commands..."
  local -a req=( ss ip nmap arp-scan awk sed grep sort uniq column curl sudo )
  local missing=()
  for cmd in "${req[@]}"; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
      missing+=("$cmd")
    fi
  done
  if [ ${#missing[@]} -ne 0 ]; then
    log "Missing dependencies: ${missing[*]}"
    echo "Missing dependencies: ${missing[*]}"
    echo "Install them with: sudo apt update && sudo apt install -y ${missing[*]}"
    return 1
  fi
  log "All required commands available."
  return 0
}

# --- Initialize files ---
ensure_files() {
  [ -f "$KNOWN_FILE" ] || echo "# known hosts - added by netwatch" > "$KNOWN_FILE"
  touch "$LOGFILE"
}

# --- Get default iface and network ---
get_iface_net() {
  local IFACE NET
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

# --- List devices on local network (non-invasive) ---
list_devices() {
  log "Scanning local network for devices (non-invasive ARP discovery)..."
  local info
  if ! info=$(get_iface_net); then
    echo "Could not detect network interface or IPv4 - are you connected?"
    read -p "Press Enter to continue..."
    return 1
  fi
  read -r IFACE NET <<<"$info"
  echo "Interface: $IFACE  Network: $NET"
  # prefer arp-scan for nice output, else use nmap -sn
  if command -v arp-scan >/dev/null 2>&1; then
    sudo arp-scan --interface="$IFACE" --localnet | tee "$TMP_DIR/arp_scan.out"
  else
    sudo nmap -sn "$NET" -oG - | awk '/Up$/{print $2}' | while read -r ip; do
      arp -n "$ip" || true
    done | tee "$TMP_DIR/arp_scan.out"
  fi
  echo
  echo "Summary (IP / MAC if available):"
  # try to parse IP and MAC
  if [ -s "$TMP_DIR/arp_scan.out" ]; then
    awk '/([0-9]{1,3}\.){3}[0-9]{1,3}/ {print}' "$TMP_DIR/arp_scan.out" | sed -n '1,200p'
  else
    echo "(no devices found or scan failed)"
  fi
  log "Device scan complete."
  read -p "Press Enter to return to menu..."
}

# --- Show internet flow for local machine (Process -> remote IP:port) ---
show_internet_flow() {
  log "Collecting Internet Flow for local machine..."
  echo "🌐 Internet Flow (local machine) - Process -> Remote IP:Port"
  printf "%-8s %-25s %-8s %-20s\n" "Proto" "Remote IP" "Port" "Process(PID)"
  echo "--------------------------------------------------------------------------------"
  # Using ss to get established connections and process info
  sudo ss -tunp state established 2>/dev/null | awk 'NR>1 {print $1,$5,$7}' | while read -r proto addr proc; do
    # addr may be [ipv6]:port or ip:port
    ip=$(echo "$addr" | sed -E 's/^\[//; s/\](:|$)/\1/' | sed 's/:.*$//')
    port=$(echo "$addr" | awk -F: '{print $NF}')
    procname="$(echo "$proc" | sed -n 's/.*pid=\([0-9]*\),.*$/\1/p' )"
    if [ -z "$procname" ]; then
      # try alternative extraction
      procname="$(echo "$proc" | sed -n 's/.*\\(\\\"\\([^)]+)\\).*//p' )"
    fi
    # attempt to get process cmdline
    if [[ "$proc" =~ pid=([0-9]+) ]]; then
      pid="${BASH_REMATCH[1]}"
      cmd="$(ps -p "$pid" -o comm= 2>/dev/null || echo "unknown")"
    else
      pid="N/A"
      cmd="unknown"
    fi
    printf "%-8s %-25s %-8s %-20s\n" "$proto" "$ip" "$port" "$cmd($pid)"
  done
  echo "--------------------------------------------------------------------------------"
  log "Internet Flow displayed."
  read -p "Press Enter to return to menu..."
}

# --- Scan open/listening ports on local system, present option to stop service ---
scan_open_ports() {
  log "Scanning local listening ports..."
  echo "🔍 Local LISTEN sockets (protocol, local addr:port, process)"
  if command -v ss >/dev/null 2>&1; then
    sudo ss -tulnp | sed -n '1,200p' | tee "$TMP_DIR/listen.out"
  else
    sudo netstat -tulnp | sed -n '1,200p' | tee "$TMP_DIR/listen.out"
  fi
  echo
  echo "If you want to stop a service safely, identify the SERVICE name and use 'sudo systemctl stop <service>' or 'sudo kill <pid>'."
  echo "Do you want to attempt to stop a process by PID from the above list? (y/N)"
  read -r ans
  if [[ "$ans" =~ ^[Yy]$ ]]; then
    read -p "Enter PID to stop: " stop_pid
    if [[ "$stop_pid" =~ ^[0-9]+$ ]]; then
      if ps -p "$stop_pid" >/dev/null 2>&1; then
        read -p "Confirm kill PID $stop_pid (this may stop a service). Proceed? (y/N) " c2
        if [[ "$c2" =~ ^[Yy]$ ]]; then
          sudo kill "$stop_pid" && log "Killed PID $stop_pid" || log "Failed to kill PID $stop_pid"
        else
          echo "Abort."
        fi
      else
        echo "PID not found."
      fi
    else
      echo "Invalid PID."
    fi
  fi
  read -p "Press Enter to return to menu..."
}

# --- Show known hosts file ---
show_known_hosts() {
  echo "Known Hosts (trusted):"
  if [ -s "$KNOWN_FILE" ]; then
    nl -ba "$KNOWN_FILE"
  else
    echo "(none)"
  fi
  read -p "Press Enter to return..."
}

# --- Update known hosts (add current local connected endpoints) ---
update_known_hosts() {
  log "Updating known hosts based on current established connections (local machine only)..."
  sudo ss -tunp state established 2>/dev/null | awk 'NR>1 {print $5}' | sed -E 's/^\[//; s/\]$//; s/:.*$//' | sort -u >> "$KNOWN_FILE"
  sort -u "$KNOWN_FILE" -o "$KNOWN_FILE"
  log "Known hosts updated."
  read -p "Press Enter to continue..."
}

# --- Self-test auto bug detection: run small tests, record failures ---
auto_bug_detection() {
  log "Running self-test (auto bug detection)..."
  local errors=0
  # dependency quick test
  if ! check_deps >/dev/null; then
    log "Dependency check failed. See earlier message."
    errors=$((errors+1))
  fi
  # test ss usage
  if ! sudo ss -tunp >/dev/null 2>&1; then
    log "Warning: 'ss -tunp' returned non-zero (maybe insufficient privileges)."
    errors=$((errors+1))
  fi
  # test network detection
  if ! get_iface_net >/dev/null 2>&1; then
    log "Warning: could not auto-detect active network interface & network."
    errors=$((errors+1))
  fi
  if [ "$errors" -gt 0 ]; then
    log "Self-test found $errors issue(s). Check log file: $LOGFILE"
    echo "Self-test warnings found. See $LOGFILE"
  else
    log "Self-test passed. No obvious issues detected."
    echo "Self-test passed."
  fi
  read -p "Press Enter to continue..."
}

# --- Simulate a local outgoing connection (for test only) ---
simulate_test() {
  log "Simulating outgoing HTTP connection to example.com (background)..."
  curl -sS https://example.com >/dev/null &
  sleep 1
  log "Simulation done."
  echo "Simulated an outgoing HTTP(S) request. Run 'Show Internet Flow' to observe."
  read -p "Press Enter to continue..."
}

# --- Menu ---
main_menu() {
  while true; do
    clear
    cat <<'EOF'
========================================
   BCI NetWatch (SAFE) - by anonymous-sms
   Local monitoring & audit tools (Kali)
========================================
EOF
    echo "1) Auto-update (git) & quick self-test"
    echo "2) Check dependencies (auto bug detection)"
    echo "3) List devices on local network (ARP discovery)"
    echo "4) Show Internet Flow (local machine processes -> remote)"
    echo "5) Scan local open/listening ports (and option to stop PID)"
    echo "6) Update known hosts (based on local established connections)"
    echo "7) Show known hosts"
    echo "8) Simulate test connection"
    echo "0) Exit"
    read -rp "Choose [0-8]: " opt
    case "$opt" in
      1) check_update; auto_bug_detection ;;
      2) check_deps || true; read -p "Press Enter to continue..." ;;
      3) list_devices ;;
      4) show_internet_flow ;;
      5) scan_open_ports ;;
      6) update_known_hosts ;;
      7) show_known_hosts ;;
      8) simulate_test ;;
      0) log "Exiting."; cleanup; exit 0 ;;
      *) echo "Invalid option"; sleep 1 ;;
    esac
  done
}

cleanup() {
  rm -rf "$TMP_DIR"
}

# === bootstrap ===
ensure_files
main_menu
