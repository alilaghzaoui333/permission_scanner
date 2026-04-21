#!/bin/bash

POLICY="policy.json"
LOG_DIR="logs"
REPORT_DIR="reports"
LOG_FILE="$LOG_DIR/changes.log"
REPORT_FILE="$REPORT_DIR/report.txt"

mkdir -p "$LOG_DIR" "$REPORT_DIR"

command -v jq >/dev/null 2>&1 || { whiptail --msgbox "jq not installed" 10 40; exit 1; }
command -v whiptail >/dev/null 2>&1 || { echo "whiptail not installed"; exit 1; }

CHOICE=$(whiptail --title "Permission Scanner" \
--menu "Choose an option" 15 60 4 \
"1" "Scan only" \
"2" "Scan and fix" \
"3" "View report" \
"4" "Exit" 3>&1 1>&2 2>&3)

[ $? -ne 0 ] && exit

case $CHOICE in
    1) MODE="scan" ;;
    2) MODE="fix" ;;
    3) [ -f "$REPORT_FILE" ] && whiptail --textbox "$REPORT_FILE" 20 80 || whiptail --msgbox "No report found" 10 40; exit ;;
    4) exit ;;
esac

TARGET=$(whiptail --inputbox "Enter directory to scan" 10 60 "." 3>&1 1>&2 2>&3)
[ $? -ne 0 ] && exit

[ ! -d "$TARGET" ] && { whiptail --msgbox "Invalid directory" 10 40; exit 1; }
[ ! -f "$POLICY" ] && { whiptail --msgbox "Policy file not found" 10 40; exit 1; }

FILE_PERM=$(jq -r '.file_perm' "$POLICY")
DIR_PERM=$(jq -r '.dir_perm' "$POLICY")
REMOVE_WW=$(jq -r '.remove_world_write' "$POLICY")
REMOVE_SUID=$(jq -r '.remove_setuid' "$POLICY")
REMOVE_SGID=$(jq -r '.remove_setgid' "$POLICY")
LOG_ENABLED=$(jq -r '.log_changes' "$POLICY")

TOTAL=0
ISSUES=0
FIXES=0

is_exception() {
    local item="$1"
    while read -r ex; do
        [[ "$item" == "$ex"* ]] && return 0
    done < <(jq -r '.exceptions[]' "$POLICY")
    return 1
}

log_change() {
    if [ "$LOG_ENABLED" = "true" ]; then
        echo "$1" >> "$LOG_FILE"
    fi
}

detect_world_writable() {
    local perm="$1"
    local others=$((perm % 10))
    (( others & 2 ))
}

apply_fix() {
    local item="$1"
    local perm="$2"

    if [ "$MODE" = "fix" ]; then
        if [ -f "$item" ] && [ "$perm" != "$FILE_PERM" ]; then
            chmod "$FILE_PERM" "$item" 2>/dev/null && ((FIXES++))
            log_change "[FIX] File: $item ($perm -> $FILE_PERM)"
        fi

        if [ -d "$item" ] && [ "$perm" != "$DIR_PERM" ]; then
            chmod "$DIR_PERM" "$item" 2>/dev/null && ((FIXES++))
            log_change "[FIX] Dir: $item ($perm -> $DIR_PERM)"
        fi
    fi
}

echo "===== SCAN START $(date) =====" > "$REPORT_FILE"
echo "===== LOG START $(date) =====" > "$LOG_FILE"

{
for i in {1..100}; do
    echo $i
    sleep 0.01
done
} | whiptail --gauge "Scanning..." 6 60 0

while IFS= read -r item; do

    ((TOTAL++))

    is_exception "$item" && echo "[SKIP] $item" >> "$REPORT_FILE" && continue

    stat "$item" >/dev/null 2>&1 || continue

    PERM_BEFORE=$(stat -c "%a" "$item")
    MODE_STR=$(stat -c "%A" "$item")

    echo "[BEFORE] $item : $PERM_BEFORE" >> "$REPORT_FILE"

    if [ "$REMOVE_WW" = "true" ] && detect_world_writable "$PERM_BEFORE"; then
        echo "[ALERT] World-writable: $item" >> "$REPORT_FILE"
        ((ISSUES++))
        if [ "$MODE" = "fix" ]; then
            chmod o-w "$item" 2>/dev/null && ((FIXES++))
            log_change "[FIX] Removed world-write: $item"
        fi
    fi

    if [ "$REMOVE_SUID" = "true" ] && [[ $MODE_STR == *"s"* ]]; then
        echo "[ALERT] SetUID: $item" >> "$REPORT_FILE"
        ((ISSUES++))
        if [ "$MODE" = "fix" ]; then
            chmod u-s "$item" 2>/dev/null && ((FIXES++))
            log_change "[FIX] Removed setuid: $item"
        fi
    fi

    if [ "$REMOVE_SGID" = "true" ] && [[ $MODE_STR == *"s"* ]]; then
        echo "[ALERT] SetGID: $item" >> "$REPORT_FILE"
        ((ISSUES++))
        if [ "$MODE" = "fix" ]; then
            chmod g-s "$item" 2>/dev/null && ((FIXES++))
            log_change "[FIX] Removed setgid: $item"
        fi
    fi

    if [ -f "$item" ] && [ "$PERM_BEFORE" != "$FILE_PERM" ]; then
        echo "[MISMATCH FILE] $item ($PERM_BEFORE != $FILE_PERM)" >> "$REPORT_FILE"
        ((ISSUES++))
    fi

    if [ -d "$item" ] && [ "$PERM_BEFORE" != "$DIR_PERM" ]; then
        echo "[MISMATCH DIR] $item ($PERM_BEFORE != $DIR_PERM)" >> "$REPORT_FILE"
        ((ISSUES++))
    fi

    apply_fix "$item" "$PERM_BEFORE"

    PERM_AFTER=$(stat -c "%a" "$item")

    echo "[AFTER]  $item : $PERM_AFTER" >> "$REPORT_FILE"
    echo "-----------------------------" >> "$REPORT_FILE"

done < <(find "$TARGET" 2>/dev/null)

echo "===== SUMMARY =====" >> "$REPORT_FILE"
echo "Total scanned: $TOTAL" >> "$REPORT_FILE"
echo "Issues found: $ISSUES" >> "$REPORT_FILE"
echo "Fixes applied: $FIXES" >> "$REPORT_FILE"
echo "===== SCAN END $(date) =====" >> "$REPORT_FILE"

whiptail --title "Scan Complete" \
--msgbox "Scan finished\n\nTotal: $TOTAL\nIssues: $ISSUES\nFixes: $FIXES\n\nReport: $REPORT_FILE\nLog: $LOG_FILE" 15 60