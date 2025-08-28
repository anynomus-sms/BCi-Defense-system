#!/usr/bin/env bash
# bci_netwatch_pro.sh
# BCI NetWatch Pro — Safe local audit & monitoring tool for Kali/BlackArch
# by anonymous-sms
#
# PURPOSE:
#  - Local Internet Flow (processes on this machine -> remote IP:port)
#  - Local open/listening ports scan + option to stop process
#  - Non-invasive local network discovery (arp-scan or nmap -sn)
#  - Optional router SNMP read (if you have admin access)
#  - Dependency check & auto bug-detection (self-test)
#  - Auto-update (only works if this directory is a git repo)
#  - Logging with timestamps and watermark
#
# SAFETY:
#  - This tool is intentionally SAFE: no MITM, no ARP spoofing, no sniffing of others' traffic.
#  - Use only on networks and devices you own or have explicit permission to test.
#
# REQUIREMENTS (recommended):
#  - bash, git, ss, ps, awk, sed, grep, sort, uniq, column
#  - Optional but recommended: nmap, arp-scan, snmpwalk, curl
#
# Tested on Kali Linux / BlackArch style environments (Debian/Arch based), run as normal user.
# Some commands require sudo; script will request sudo only when needed.

set -euo pipefail
IFS=$'\n\t'

# -------- CONFIGURATION --------
SCRIPT_NAME="$(basename "$0")"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="$ROOT_DIR/logs"
TMP_DIR="$ROOT_DIR/.tmp_bci"
KNOWN_FILE="$ROOT_DIR/known_hosts.txt"
OUI_CACHE="$ROOT_DIR/oui_cache.txt"    # optional vendor lookup cache
GIT_REMOTE="origin"

mkdir -p "$LOG_DIR" "$TMP_DIR"

# watermark helper
watermark() { printf " (by anonymous-sms)"; }

# log helper
_logfile="$LOG_DIR/netwatch_$(date +%F).log"
log() {
  local ts
  ts="$(date '+%Y-%m-%d %H:%M:%S')"
  echo "[$ts] $*$(watermark)" | tee -a "$_logfile"
}

# -------- PRIVILEGE HELPER --------
need_sudo() {
  if [ "$EUID" -ne 0 ]; then
    echo "This action requires sudo/root. Please enter your password if prompted."
    sudo -v
    if [ $? -ne 0 ]; then
      echo "sudo failed or was cancelled. Some features may not work."
      return 1
    fi
  fi
  return 0
}

# -------- DEPENDENCY CHECK / AUTO BUG DETECTION --------
check_deps() {
  log "Checking dependencies..."
  local deps=(bash git ss ps awk sed grep sort uniq column)
  local optdeps=(nmap arp-scan snmpwalk curl)
  local missing=()
  for d in "${deps[@]}"; do
    if ! command -v "$d" >/dev/null 2>&1; then
      missing+=("$d")
    fi
  done
  if [ ${#missing[@]} -ne 0 ]; then
    echo "Missing required commands: ${missing[*]}"
    log "Missing required commands: ${missing[*]}"
    return 1
  fi
  # optional deps warning
  local miss_opt=()
  for d in "${optdeps[@]}"; do
    if ! command -v "$d" >/dev/null 2>&1; then
      miss_opt+=("$d")
    fi
  done
  if [ ${#miss_opt[@]} -ne 0 ]; then
    echo "Optional tools not found (features limited): ${miss_opt[*]}"
    log "Optional tools missing: ${miss_opt[*]}"
  fi
  log "Dependency check passed (optional tools may be missing)."
  return 0
}

# -------- AUTO-UPDATE (safe) -----------
check_update() {
  # only if running inside a git repo
  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    log "Checking for updates (git)..."
    # fetch remote quietly
    if git fetch "$GIT_REMOTE" >/dev/null 2>&1; then
      local local_rev remote_rev upstream
      local_rev=$(git rev-parse @)
      upstream="@{u}" 2>/dev/null || true
      if git rev-parse --verify "$upstream" >/dev/null 2>&1; then
        remote_rev=$(git rev-parse "$upstream")
        if [ "$local_rev" != "$remote_rev" ]; then
          echo "Update is available. Pulling latest changes..."
          log "Update available, attempting git pull..."
          if git pull --rebase --autostash; then
            chmod +x "$SCRIPT_NAME" 2>/dev/null || true
            log "Update pulled successfully. Please re-run the script to apply updates."
            echo "Update applied. Please run the script again."
            exit 0
          else
            log "Git pull failed."
            echo "Auto-update failed; please run 'git pull' manually."
          fi
        else
          log "Already up-to-date."
        fi
      else
        log "No upstream branch configured; skipping update check."
      fi
    else
      log "Git fetch failed; skipping auto-update."
    fi
  else
    # not a git repo
    log "Not a git repository; auto-update skipped."
  fi
}

# -------- NETWORK / DEVICE DISCOVERY (non-invasive) ----------
get_default_iface_net() {
  # returns "iface network_cidr" or empty
  local iface net
  iface=$(ip route show default 2>/dev/null | awk '/default/ {print $5; exit}')
  [ -z "$iface" ] && return 1
  net=$(ip -o -f inet addr show "$iface" 2>/dev/null | awk '{print $4; exit}')
  if [ -z "$net" ]; then
    return 1
  fi
  printf "%s %s" "$iface" "$net"
}

list_local_devices() {
  log "Starting non-invasive local network discovery..."
  local info iface net
  if ! info=$(get_default_iface_net); then
    echo "Could not detect default network interface. Are you connected?"
    log "Failed to detect interface/network."
    read -p "Press Enter to continue..."
    return 1
  fi
  iface=$(awk '{print $1}' <<<"$info")
  net=$(awk '{print $2}' <<<"$info")
  echo "Using interface: $iface  network: $net"
  log "Using interface: $iface network: $net"
  # use arp-scan if available (nice vendor output)
  if command -v arp-scan >/dev/null 2>&1; then
    need_sudo || true
    echo "Running arp-scan (may require sudo)..."
    sudo arp-scan --interface="$iface" --localnet --retry=2 --timeout=200 2>/dev/null | tee "$TMP_DIR/arp_scan.out"
    echo
    echo "Parsed results (IP, MAC, Vendor if present):"
    awk '/^[0-9]/ {print $1"\t"$2"\t"$3,$4,$5}' "$TMP_DIR/arp_scan.out" 2>/dev/null || true
  else
    # fallback to nmap ping scan
    if command -v nmap >/dev/null 2>&1; then
      echo "arp-scan not found; using nmap -sn (no vendor info)."
      sudo nmap -sn "$net" -oG - 2>/dev/null | awk '/Up$/{print $2}' | tee "$TMP_DIR/nmap_live.out"
      echo "Found IPs:"
      cat "$TMP_DIR/nmap_live.out" || true
    else
      echo "Neither arp-scan nor nmap available. Install one for network discovery."
      log "No network discovery tool found."
      return 1
    fi
  fi
  log "Network discovery completed."
  read -p "Press Enter to continue..."
}

# -------- INTERNET FLOW (local machine) ----------
show_internet_flow_table() {
  log "Displaying Internet Flow (local machine -> remote endpoints)"
  echo "Proto   RemoteIP:Port           PID/Process"
  echo "--------------------------------------------------------"
  # show established TCP/UDP connections with process info. Requires sudo for process names.
  # we will parse ss output robustly.
  if ! command -v ss >/dev/null 2>&1; then
    echo "ss not found. Please install iproute2 package."
    log "ss missing."
    return 1
  fi
  # Use ss to list established connections; include state etc.
  sudo ss -tunp state established 2>/dev/null | awk 'NR>1 { $1=$1; print }' | while read -r line; do
    # sample line format:
    # tcp    ESTAB      0      0      192.168.1.10:45678   142.250.183.4:443    users:(("firefox",pid=1345,fd=74))
    # We'll extract remote addr/port and process string
    remote=$(awk '{print $(NF-1)}' <<<"$line" | sed -E 's/^\[//; s/\]$//')
    proc_field=$(awk '{print $NF}' <<<"$line")
    # try to extract pid and process name
    if [[ "$proc_field" =~ pid=([0-9]+), ]]; then
      pid="${BASH_REMATCH[1]}"
      cmd="$(ps -p "$pid" -o comm= 2>/dev/null || echo unknown)"
    else
      pid="N/A"
      cmd="unknown"
    fi
    printf "%-6s %-22s %s(%s)\n" "$(awk '{print $1}' <<<"$line")" "$remote" "$cmd" "$pid"
  done
  echo "--------------------------------------------------------"
  log "Internet Flow displayed."
  read -p "Press Enter to continue..."
}

# -------- LOCAL PORTS (LISTEN) + STOP OPTION ----------
scan_listening_ports() {
  log "Scanning local listening ports..."
  echo "Proto   LocalAddr:Port           PID/Process"
  echo "--------------------------------------------------------"
  if command -v ss >/dev/null 2>&1; then
    sudo ss -tulnp 2>/dev/null | sed -n '1,200p' | tee "$TMP_DIR/listen.out"
  else
    sudo netstat -tulnp 2>/dev/null | sed -n '1,200p' | tee "$TMP_DIR/listen.out"
  fi
  echo
  echo "If you want to stop a process listed above, you can provide its PID."
  read -rp "Stop a PID? (enter PID or leave empty to skip): " stop_pid
  if [ -n "$stop_pid" ]; then
    if [[ "$stop_pid" =~ ^[0-9]+$ ]]; then
      if ps -p "$stop_pid" >/dev/null 2>&1; then
        read -rp "Confirm kill PID $stop_pid (this may stop services). Proceed? (y/N): " confirm
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
          sudo kill "$stop_pid" && log "Killed PID $stop_pid" && echo "PID $stop_pid stopped."
        else
          echo "Aborted by user."
        fi
      else
        echo "PID not found."
      fi
    else
      echo "Invalid PID."
    fi
  fi
  log "Local listening ports scan complete."
  read -p "Press Enter to continue..."
}

# -------- KNOWN HOSTS (local snapshot) ----------
ensure_known_file() { [ -f "$KNOWN_FILE" ] || echo "# known hosts (added by bci_netwatch_pro)" > "$KNOWN_FILE"; }

update_known_from_local() {
  ensure_known_file
  log "Updating known hosts from local established connections..."
  sudo ss -tunp state established 2>/dev/null | awk 'NR>1 {print $(NF-1)}' | sed -E 's/.*:([0-9]+)$//; s/:.*$//' | sed '/^$/d' | sort -u >> "$KNOWN_FILE"
  sort -u "$KNOWN_FILE" -o "$KNOWN_FILE"
  log "Known hosts updated."
  echo "Known hosts updated (local machine snapshot)."
  read -p "Press Enter to continue..."
}

show_known_hosts() {
  ensure_known_file
  echo "Known hosts (trusted):"
  nl -ba "$KNOWN_FILE" || true
  read -p "Press Enter to continue..."
}

# -------- SNMP ROUTER READ (optional, safe read-only) ----------
router_snmp_read() {
  # Only perform if snmpwalk present. Require router IP and community.
  if ! command -v snmpwalk >/dev/null 2>&1; then
    echo "snmpwalk not found. Install net-snmp package to use router SNMP read."
    read -p "Press Enter to continue..."
    return 1
  fi
  read -rp "Enter router IP: " r_ip
  read -rp "Enter SNMP community (v2c): " r_comm
  log "Attempting SNMP read from router $r_ip (read-only)..."
  # basic sysDescr test
  if ! snmpwalk -v2c -c "$r_comm" -O qv "$r_ip" 1.3.6.1.2.1.1.1.0 2>/dev/null; then
    echo "SNMP read failed (check IP/community/ACL)."
    log "SNMP read failed for $r_ip"
    read -p "Press Enter to continue..."
    return 1
  fi
  echo "SNMP sysDescr:"
  snmpwalk -v2c -c "$r_comm" -O qv "$r_ip" 1.3.6.1.2.1.1.1.0
  echo
  echo "Attempting to read ARP/IP table (if exposed)..."
  # attempt ipNetToMediaPhysAddress - may vary by vendor
  snmpwalk -v2c -c "$r_comm" -O n "$r_ip" 1.3.6.1.2.1.4.22.1.2 2>/dev/null | tee "$TMP_DIR/snmp_ip2mac_raw.txt" || true
  if [ -s "$TMP_DIR/snmp_ip2mac_raw.txt" ]; then
    echo "Router ARP (raw):"
    sed -n '1,200p' "$TMP_DIR/snmp_ip2mac_raw.txt"
  else
    echo "No ARP entries via SNMP (router may not expose them)."
  fi
  log "SNMP router read completed (read-only)."
  read -p "Press Enter to continue..."
}

# -------- SELF-TEST / AUTO BUG DETECTION ----------
self_test() {
  log "Running self-test (auto bug detection)..."
  local fail_count=0
  if ! check_deps >/dev/null 2>&1; then
    echo "Dependency check failed. See messages above."
    fail_count=$((fail_count+1))
  fi
  # test that ss returns output
  if ! sudo ss -tunp state established >/dev/null 2>&1; then
    echo "Warning: 'ss' returned error (maybe need sudo)."
    log "'ss' test failed or needs sudo."
    fail_count=$((fail_count+1))
  fi
  # test network detection
  if ! get_default_iface_net >/dev/null 2>&1; then
    echo "Warning: could not detect default interface/network."
    log "Network detection test failed."
    fail_count=$((fail_count+1))
  fi
  if [ "$fail_count" -eq 0 ]; then
    echo "Self-test passed: no obvious issues detected."
    log "Self-test passed."
  else
    echo "Self-test found $fail_count issue(s). Check log: $_logfile"
    log "Self-test found $fail_count issue(s)."
  fi
  read -p "Press Enter to continue..."
}

# -------- UTILS: vendor lookup (best-effort) ----------
vendor_lookup_from_arp_scan_out() {
  # If arp-scan produced vendor info, we can parse it. Otherwise, try OUI cache if present.
  if [ -f "$TMP_DIR/arp_scan.out" ]; then
    echo "Parsing vendor info from last arp-scan (if present):"
    awk '/^[0-9]/ { $1=$1; print $1"\t"$2"\t"$3" "$4" "$5 }' "$TMP_DIR/arp_scan.out" | sed 's/ \{2,\}/ /g' | column -t -s $'\t' || true
  elif [ -f "$OUI_CACHE" ]; then
    echo "No recent arp-scan output. You can run device discovery to populate vendor info."
    echo "You can also populate OUI cache (not implemented automatically)."
  else
    echo "No vendor information available."
  fi
  read -p "Press Enter to continue..."
}

# -------- CLEANUP ----------
cleanup() {
  rm -rf "$TMP_DIR"
}

# -------- MAIN MENU ----------
main_menu() {
  ensure_known_file
  while true; do
    clear
    cat <<'EOF'
===========================================
   BCI NetWatch Pro (SAFE)  —  anonymous-sms
   Local auditing tool for Kali / BlackArch
===========================================
1) Auto-update (if git) & Self-test (auto bug detection)
2) Dependency check (non-destructive)
3) Discover local devices (arp-scan or nmap -sn)  [non-invasive]
4) Show Internet Flow (local processes -> remote IP:port)
5) Scan local listening ports (and optionally stop PID)
6) Update known hosts (snapshot from local established connections)
7) Show known hosts
8) Router SNMP read (optional; requires admin access)
9) Vendor lookup (from recent arp-scan)
0) Exit
EOF
    read -rp "Choose [0-9]: " choice
    case "$choice" in
      1) check_update; self_test ;;
      2) check_deps; read -p "Press Enter to continue..." ;;
      3) list_local_devices ;;
      4) show_internet_flow_table ;;
      5) scan_listening_ports ;;
      6) update_known_from_local ;;
      7) show_known_hosts ;;
      8) router_snmp_read ;;
      9) vendor_lookup_from_arp_scan_out ;;
      0) log "Exiting."; cleanup; exit 0 ;;
      *) echo "Invalid option"; sleep 1 ;;
    esac
  done
}

# -------- BOOTSTRAP ----------
trap cleanup EXIT
log "Starting bci_netwatch_pro (safe mode)."
# ensure files
[ -f "$KNOWN_FILE" ] || echo "# known hosts (added by bci_netwatch_pro)" > "$KNOWN_FILE"
main_menu
