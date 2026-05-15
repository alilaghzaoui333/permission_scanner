#!/bin/bash

POLICY="policy.json"

LOG_DIR="logs"
REPORT_DIR="reports"

TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")

LOG_FILE="$LOG_DIR/changes_$TIMESTAMP.log"
REPORT_FILE="$REPORT_DIR/report_$TIMESTAMP.txt"

mkdir -p "$LOG_DIR" "$REPORT_DIR"

command -v jq >/dev/null 2>&1 || {
    whiptail --title "Error" --msgbox "jq not installed" 10 40
    exit 1
}

command -v whiptail >/dev/null 2>&1 || {
    echo "whiptail not installed"
    exit 1
}

whiptail --title "Permission Scanner" \
--msgbox "Secure Permission Scanner\n\nAudit and automatically fix Linux file permissions" 12 65

while true; do

CHOICE=$(whiptail \
--title "Main Menu" \
--menu "Choose an option" 20 75 6 \
"1" "Scan only (audit mode)" \
"2" "Scan and fix permissions" \
"3" "View latest report" \
"4" "View latest logs" \
"5" "About project" \
"6" "Exit" \
3>&1 1>&2 2>&3)

[ $? -ne 0 ] && exit

case "$CHOICE" in

1)
MODE="scan"
;;

2)
MODE="fix"
;;

3)
LATEST_REPORT=$(ls -t "$REPORT_DIR"/*.txt 2>/dev/null | head -n 1)

if [ -n "$LATEST_REPORT" ]; then
    whiptail --title "Latest Report" --textbox "$LATEST_REPORT" 30 100
else
    whiptail --msgbox "No reports found" 10 40
fi

continue
;;

4)
LATEST_LOG=$(ls -t "$LOG_DIR"/*.log 2>/dev/null | head -n 1)

if [ -n "$LATEST_LOG" ]; then
    whiptail --title "Latest Logs" --textbox "$LATEST_LOG" 30 100
else
    whiptail --msgbox "No logs found" 10 40
fi

continue
;;

5)
whiptail --title "About Project" \
--msgbox "Linux Permission Scanner\n\nFeatures:\n- Recursive scan\n- Permission auditing\n- Automatic correction\n- JSON security policy\n- Logging system\n- Interactive interface" 18 70
continue
;;

6)
clear
exit
;;

esac

TARGET=$(whiptail \
--title "Target Directory" \
--inputbox "Enter directory to scan" 10 70 "." \
3>&1 1>&2 2>&3)

[ $? -ne 0 ] && continue

if [ ! -d "$TARGET" ]; then
    whiptail --msgbox "Invalid directory" 10 40
    continue
fi

if [ ! -f "$POLICY" ]; then
    whiptail --msgbox "policy.json not found" 10 40
    continue
fi

FILE_PERM=$(jq -r '.file_perm' "$POLICY")
DIR_PERM=$(jq -r '.dir_perm' "$POLICY")

REMOVE_WW=$(jq -r '.remove_world_write' "$POLICY")
REMOVE_SUID=$(jq -r '.remove_setuid' "$POLICY")
REMOVE_SGID=$(jq -r '.remove_setgid' "$POLICY")

LOG_ENABLED=$(jq -r '.log_changes' "$POLICY")

TOTAL=0
ISSUES=0
FIXES=0
FILES_WITH_ISSUES=0

is_exception() {

    local item="$1"

    while read -r ex; do
        [[ "$item" == "$ex" || "$item" == "$ex/"* ]] && return 0
    done < <(jq -r '.exceptions[]' "$POLICY")

    return 1
}

log_change() {

    [ "$LOG_ENABLED" = "true" ] && echo "[$(date +"%H:%M:%S")] $1" >> "$LOG_FILE"
}

detect_world_writable() {

    local perm="$1"
    local others=$((perm % 10))

    (( others & 2 ))
}

fix_permissions() {

    local item="$1"

    if [ -d "$item" ]; then
        chmod "$DIR_PERM" "$item" 2>/dev/null && ((FIXES++))
        log_change "[FIX] Directory permission fixed: $item"
    else

        if [ -x "$item" ]; then
            chmod 755 "$item" 2>/dev/null && ((FIXES++))
            log_change "[FIX] Executable permission fixed: $item"
        else
            chmod "$FILE_PERM" "$item" 2>/dev/null && ((FIXES++))
            log_change "[FIX] File permission fixed: $item"
        fi
    fi
}

echo "===== SCAN START $(date) =====" > "$REPORT_FILE"
echo "===== LOG START $(date) =====" > "$LOG_FILE"

TOTAL_FILES=$(find "$TARGET" \( -type f -o -type d \) 2>/dev/null | wc -l)

[ "$TOTAL_FILES" -eq 0 ] && TOTAL_FILES=1

COUNT=0

exec 3> >(whiptail --gauge "Scanning filesystem..." 8 70 0)

while read -r item; do

    ((COUNT++))
    ((TOTAL++))

    PERCENT=$((COUNT * 100 / TOTAL_FILES))

    echo "$PERCENT" >&3

    is_exception "$item" && {
        echo "[SKIP] $item" >> "$REPORT_FILE"
        continue
    }

    stat "$item" >/dev/null 2>&1 || continue

    FILE_ISSUE=0

    PERM_BEFORE=$(stat -c "%a" "$item")
    MODE_STR=$(stat -c "%A" "$item")

    echo "[BEFORE] $item : $PERM_BEFORE" >> "$REPORT_FILE"

    if [ "$REMOVE_WW" = "true" ] && detect_world_writable "$PERM_BEFORE"; then

        echo "[ALERT] World-writable detected: $item" >> "$REPORT_FILE"

        ((ISSUES++))
        FILE_ISSUE=1

        if [ "$MODE" = "fix" ]; then
            chmod o-w "$item" 2>/dev/null && ((FIXES++))
            log_change "[FIX] Removed world-write: $item"
        fi
    fi

    if [ "$REMOVE_SUID" = "true" ]; then

        if [[ ${MODE_STR:3:1} == "s" || ${MODE_STR:3:1} == "S" ]]; then

            echo "[ALERT] SetUID detected: $item" >> "$REPORT_FILE"

            ((ISSUES++))
            FILE_ISSUE=1

            if [ "$MODE" = "fix" ]; then
                chmod u-s "$item" 2>/dev/null && ((FIXES++))
                log_change "[FIX] Removed SetUID: $item"
            fi
        fi
    fi

    if [ "$REMOVE_SGID" = "true" ]; then

        if [[ ${MODE_STR:6:1} == "s" || ${MODE_STR:6:1} == "S" ]]; then

            echo "[ALERT] SetGID detected: $item" >> "$REPORT_FILE"

            ((ISSUES++))
            FILE_ISSUE=1

            if [ "$MODE" = "fix" ]; then
                chmod g-s "$item" 2>/dev/null && ((FIXES++))
                log_change "[FIX] Removed SetGID: $item"
            fi
        fi
    fi

    if [ -f "$item" ] && [ "$PERM_BEFORE" != "$FILE_PERM" ]; then

        echo "[MISMATCH FILE] $item ($PERM_BEFORE != $FILE_PERM)" >> "$REPORT_FILE"

        ((ISSUES++))
        FILE_ISSUE=1
    fi

    if [ -d "$item" ] && [ "$PERM_BEFORE" != "$DIR_PERM" ]; then

        echo "[MISMATCH DIR] $item ($PERM_BEFORE != $DIR_PERM)" >> "$REPORT_FILE"

        ((ISSUES++))
        FILE_ISSUE=1
    fi

    if [ "$MODE" = "fix" ] && [ "$FILE_ISSUE" -eq 1 ]; then
        fix_permissions "$item"
    fi

    [ "$FILE_ISSUE" -eq 1 ] && ((FILES_WITH_ISSUES++))

    PERM_AFTER=$(stat -c "%a" "$item")

    echo "[AFTER]  $item : $PERM_AFTER" >> "$REPORT_FILE"
    echo "----------------------------------------" >> "$REPORT_FILE"

done < <(find "$TARGET" \( -type f -o -type d \) 2>/dev/null)

exec 3>&-

echo "===== SUMMARY =====" >> "$REPORT_FILE"
echo "Total scanned: $TOTAL" >> "$REPORT_FILE"
echo "Files with issues: $FILES_WITH_ISSUES" >> "$REPORT_FILE"
echo "Total issues found: $ISSUES" >> "$REPORT_FILE"
echo "Fixes applied: $FIXES" >> "$REPORT_FILE"
echo "===== SCAN END $(date) =====" >> "$REPORT_FILE"

whiptail \
--title "Scan Complete" \
--msgbox "Scan completed successfully\n\nTotal scanned: $TOTAL\nFiles with issues: $FILES_WITH_ISSUES\nIssues found: $ISSUES\nFixes applied: $FIXES\n\nReport:\n$REPORT_FILE\n\nLogs:\n$LOG_FILE" 20 75

done