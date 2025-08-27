#!/bin/bash
# BCI NetWatch - Suspicious Connection Detector
# by anonymous-sms

KNOWN_FILE="known_hosts.txt"
LOGFILE="bci_netwatch.log"

# bikin file known kalau belum ada
if [ ! -f "$KNOWN_FILE" ]; then
    touch "$KNOWN_FILE"
    echo "127.0.0.1" >> "$KNOWN_FILE"
    echo "localhost" >> "$KNOWN_FILE"
fi

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1 (by anonymous-sms)" | tee -a "$LOGFILE"
}

list_connections() {
    echo "=== ACTIVE CONNECTIONS (by anonymous-sms) ==="
    ss -tunp | awk 'NR>1 {print $5}' | cut -d: -f1 | sort -u
    echo "============================================"
}

update_known() {
    list_connections | grep -v "===" >> "$KNOWN_FILE"
    sort -u "$KNOWN_FILE" -o "$KNOWN_FILE"
    log "Updated known hosts list."
}

scan_suspicious() {
    echo "=== SCANNING SUSPICIOUS CONNECTIONS (by anonymous-sms) ==="
    CURRENT=$(ss -tunp | awk 'NR>1 {print $5}' | cut -d: -f1 | sort -u)
    for IP in $CURRENT; do
        if ! grep -q "$IP" "$KNOWN_FILE"; then
            log "⚠ Suspicious connection detected: $IP"
            echo "Do you want to (a) allow, (b) block (iptables), (i) ignore?"
            read -r ACTION
            case $ACTION in
                a) echo "$IP" >> "$KNOWN_FILE"; sort -u "$KNOWN_FILE" -o "$KNOWN_FILE"; log "Allowed $IP";;
                b) sudo iptables -A OUTPUT -d "$IP" -j DROP; log "Blocked $IP";;
                i) log "Ignored $IP";;
            esac
        fi
    done
    echo "=========================================================="
}

menu() {
    while true; do
        echo ""
        echo "===== BCI NetWatch Menu ====="
        echo "       by anonymous-sms       "
        echo "============================="
        echo "1) List active connections"
        echo "2) Update known hosts"
        echo "3) Scan suspicious connections"
        echo "0) Exit"
        echo "============================="
        echo -n "Choose> "
        read -r CHOICE
        case $CHOICE in
            1) list_connections ;;
            2) update_known ;;
            3) scan_suspicious ;;
            0) exit 0 ;;
            *) echo "Invalid choice" ;;
        esac
    done
}

menu
