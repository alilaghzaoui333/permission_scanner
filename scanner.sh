#!/bin/bash

POLICY="policy.json"
LOG_DIR="logs"
REPORT_DIR="reports"
LOG_FILE="$LOG_DIR/changes.log"
REPORT_FILE="$REPORT_DIR/report.txt"

mkdir -p "$LOG_DIR" "$REPORT_DIR"

echo "===== Permission Scanner ====="
echo "1) Scan only"
echo "2) Scan and fix"
echo "3) Exit"

read -r -p "Choose option: " choice

case $choice in
    1) MODE="scan" ;;
    2) MODE="fix" ;;
    3) exit 0 ;;
    *) echo "Invalid choice"; exit 1 ;;
esac

read -r -p "Enter directory to scan: " TARGET

if [ ! -d "$TARGET" ]; then
    echo "Invalid directory!"
    exit 1
fi

if [ ! -f "$POLICY" ]; then
    echo "Policy file not found!"
    exit 1
fi


FILE_PERM=$(jq -r '.file_perm' "$POLICY")
DIR_PERM=$(jq -r '.dir_perm' "$POLICY")
REMOVE_WW=$(jq -r '.remove_world_write' "$POLICY")
REMOVE_SUID=$(jq -r '.remove_setuid' "$POLICY")
REMOVE_SGID=$(jq -r '.remove_setgid' "$POLICY")
LOG_ENABLED=$(jq -r '.log_changes' "$POLICY")



is_exception() {
    local path="$1"
    jq -r '.exceptions[]' "$POLICY" | grep -qx "$path"
}

log_change() {
    if [ "$LOG_ENABLED" = "true" ]; then
        echo "$1" >> "$LOG_FILE"
    fi
}


detect_world_writable() {
    local perm="$1"
    local others=$((perm % 10))

    if (( others & 2 )); then
        return 0
    else
        return 1
    fi
}


detect_setuid() {
    local mode="$1"
    [[ $mode == *"s"* && $mode != -*"--"* ]]
}

detect_setgid() {
    local mode="$1"
    [[ $mode == *"s"* ]]
}

apply_fix() {
    local item="$1"
    local perm_before="$2"

    if [ "$MODE" = "fix" ]; then

        if [ -f "$item" ] && [ "$perm_before" != "$FILE_PERM" ]; then
            chmod "$FILE_PERM" "$item"
            log_change "[FIX] File: $item ($perm_before -> $FILE_PERM)"
        fi

        if [ -d "$item" ] && [ "$perm_before" != "$DIR_PERM" ]; then
            chmod "$DIR_PERM" "$item"
            log_change "[FIX] Dir: $item ($perm_before -> $DIR_PERM)"
        fi
    fi
}



echo "===== SCAN START $(date) =====" > "$REPORT_FILE"
echo "===== LOG START $(date) =====" > "$LOG_FILE"

find "$TARGET" 2>/dev/null | while read -r item; do

    if is_exception "$item"; then
        echo "[SKIP] $item" >> "$REPORT_FILE"
        continue
    fi

    PERM_BEFORE=$(stat -c "%a" "$item")
    MODE_STR=$(stat -c "%A" "$item")

    echo "[CHECK] $item ($PERM_BEFORE)" >> "$REPORT_FILE"



    if [ "$REMOVE_WW" = "true" ] && detect_world_writable "$PERM_BEFORE"; then
        echo "[ALERT] World-writable: $item" >> "$REPORT_FILE"
        if [ "$MODE" = "fix" ]; then
            chmod o-w "$item"
            log_change "[FIX] Removed world-write: $item"
        fi
    fi

    if [ "$REMOVE_SUID" = "true" ] && [[ $MODE_STR == *"s"* ]]; then
        echo "[ALERT] SetUID detected: $item" >> "$REPORT_FILE"
        if [ "$MODE" = "fix" ]; then
            chmod u-s "$item"
            log_change "[FIX] Removed setuid: $item"
        fi
    fi

    if [ "$REMOVE_SGID" = "true" ] && [[ $MODE_STR == *"s"* ]]; then
        echo "[ALERT] SetGID detected: $item" >> "$REPORT_FILE"
        if [ "$MODE" = "fix" ]; then
            chmod g-s "$item"
            log_change "[FIX] Removed setgid: $item"
        fi
    fi


    if [ -f "$item" ] && [ "$PERM_BEFORE" != "$FILE_PERM" ]; then
        echo "[MISMATCH FILE] $item ($PERM_BEFORE != $FILE_PERM)" >> "$REPORT_FILE"
    fi

    if [ -d "$item" ] && [ "$PERM_BEFORE" != "$DIR_PERM" ]; then
        echo "[MISMATCH DIR] $item ($PERM_BEFORE != $DIR_PERM)" >> "$REPORT_FILE"
    fi


    apply_fix "$item" "$PERM_BEFORE"

    PERM_AFTER=$(stat -c "%a" "$item")

    echo "[RESULT] $item : $PERM_BEFORE -> $PERM_AFTER" >> "$REPORT_FILE"

done

echo "===== SCAN END $(date) =====" >> "$REPORT_FILE"

echo "Scan complete."
echo "Report: $REPORT_FILE"
echo "Log: $LOG_FILE"