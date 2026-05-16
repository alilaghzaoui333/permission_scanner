#!/bin/bash

scan_filesystem() {

    TOTAL=0
    ISSUES=0
    FIXES=0
    FILES_WITH_ISSUES=0

    SUID_COUNT=0
    SGID_COUNT=0

    FILE_PERM=$(jq -r '.file_perm' "$POLICY")
    DIR_PERM=$(jq -r '.dir_perm' "$POLICY")

    REMOVE_WW=$(jq -r '.remove_world_write' "$POLICY")
    REMOVE_SUID=$(jq -r '.remove_setuid' "$POLICY")
    REMOVE_SGID=$(jq -r '.remove_setgid' "$POLICY")

    REPORT_FILE="$REPORT_DIR/report_$(date +%Y%m%d_%H%M%S).txt"

    touch "$REPORT_FILE"

    TEMP_FILE=$(mktemp)
    SUID_TEMP=$(mktemp)
    SGID_TEMP=$(mktemp)

    sudo find "$TARGET" \( -type f -o -type d \) 2>/dev/null > "$TEMP_FILE"

    sudo find "$TARGET" -perm -4000 2>/dev/null > "$SUID_TEMP"
    sudo find "$TARGET" -perm -2000 2>/dev/null > "$SGID_TEMP"

    TOTAL_FILES=$(wc -l < "$TEMP_FILE")

    if [ "$TOTAL_FILES" -eq 0 ]; then

        whiptail \
        --title "Scan Error" \
        --msgbox "No files found in target directory" 10 50

        rm -f "$TEMP_FILE" "$SUID_TEMP" "$SGID_TEMP"

        return 1
    fi

    write_report "===== SCAN START $(date) ====="

    while IFS= read -r item; do

        [ -z "$item" ] && continue
        [ ! -e "$item" ] && continue

        ((TOTAL++))

        if is_exception "$item"; then

            write_report "[SKIP] $item"

            continue
        fi

        FILE_ISSUE=0

        PERM_BEFORE=$(stat -c "%a" "$item" 2>/dev/null)

        [ -z "$PERM_BEFORE" ] && continue

        NORMAL_PERM="${PERM_BEFORE: -3}"

        write_report "[BEFORE] $item : $PERM_BEFORE"

        if [ "$REMOVE_WW" = "true" ]; then

            OTHER_DIGIT=${NORMAL_PERM:2:1}

            if (( (10#$OTHER_DIGIT & 2) != 0 )); then

                write_report "[ALERT] World-writable detected : $item"

                ((ISSUES++))
                FILE_ISSUE=1

                add_risk "HIGH"

                if [ "$MODE" = "fix" ]; then

                    chmod o-w "$item" 2>/dev/null

                    if [ $? -eq 0 ]; then

                        ((FIXES++))

                        log_change "[FIX] Removed world-write : $item"

                    else

                        log_change "[ERROR] Failed to remove world-write : $item"

                    fi
                fi
            fi
        fi

        if [ "$REMOVE_SUID" = "true" ]; then

            if grep -Fxq "$item" "$SUID_TEMP"; then

                write_report "[CRITICAL] SetUID detected : $item"

                ((ISSUES++))
                ((SUID_COUNT++))

                FILE_ISSUE=1

                add_risk "CRITICAL"

                if [ "$MODE" = "fix" ]; then

                    chmod u-s "$item" 2>/dev/null

                    if [ $? -eq 0 ]; then

                        ((FIXES++))

                        log_change "[FIX] Removed SetUID : $item"

                    else

                        log_change "[ERROR] Failed to remove SetUID : $item"

                    fi
                fi
            fi
        fi

        if [ "$REMOVE_SGID" = "true" ]; then

            if grep -Fxq "$item" "$SGID_TEMP"; then

                write_report "[CRITICAL] SetGID detected : $item"

                ((ISSUES++))
                ((SGID_COUNT++))

                FILE_ISSUE=1

                add_risk "CRITICAL"

                if [ "$MODE" = "fix" ]; then

                    chmod g-s "$item" 2>/dev/null

                    if [ $? -eq 0 ]; then

                        ((FIXES++))

                        log_change "[FIX] Removed SetGID : $item"

                    else

                        log_change "[ERROR] Failed to remove SetGID : $item"

                    fi
                fi
            fi
        fi

        if [ -f "$item" ]; then

            if [ "$NORMAL_PERM" != "$FILE_PERM" ]; then

                write_report "[MISMATCH FILE] $item ($NORMAL_PERM != $FILE_PERM)"

                ((ISSUES++))

                FILE_ISSUE=1

                add_risk "LOW"

                if [ "$MODE" = "fix" ]; then

                    chmod "$FILE_PERM" "$item" 2>/dev/null

                    if [ $? -eq 0 ]; then

                        ((FIXES++))

                        log_change "[FIX] File permission fixed : $item"

                    else

                        log_change "[ERROR] Failed to fix file permission : $item"

                    fi
                fi
            fi
        fi

        if [ -d "$item" ]; then

            if [ "$NORMAL_PERM" != "$DIR_PERM" ]; then

                write_report "[MISMATCH DIR] $item ($NORMAL_PERM != $DIR_PERM)"

                ((ISSUES++))

                FILE_ISSUE=1

                add_risk "LOW"

                if [ "$MODE" = "fix" ]; then

                    chmod "$DIR_PERM" "$item" 2>/dev/null

                    if [ $? -eq 0 ]; then

                        ((FIXES++))

                        log_change "[FIX] Directory permission fixed : $item"

                    else

                        log_change "[ERROR] Failed to fix directory permission : $item"

                    fi
                fi
            fi
        fi

        if [ "$FILE_ISSUE" -eq 1 ]; then
            ((FILES_WITH_ISSUES++))
        fi

        PERM_AFTER=$(stat -c "%a" "$item" 2>/dev/null)

        write_report "[AFTER]  $item : $PERM_AFTER"
        write_report "----------------------------------------"

    done < "$TEMP_FILE"

    rm -f "$TEMP_FILE" "$SUID_TEMP" "$SGID_TEMP"

    calculate_risk_level

    generate_signature "$REPORT_FILE"

    write_report "===== SECURITY ANALYSIS ====="
    write_report "Risk Score : $RISK_SCORE"
    write_report "Risk Level : $RISK_LEVEL"
    write_report "Critical Issues : $CRITICAL_ISSUES"
    write_report "SetUID Files : $SUID_COUNT"
    write_report "SetGID Files : $SGID_COUNT"

    write_report "===== SUMMARY ====="
    write_report "Total scanned : $TOTAL"
    write_report "Files with issues : $FILES_WITH_ISSUES"
    write_report "Issues found : $ISSUES"
    write_report "Fixes applied : $FIXES"
    write_report "===== SCAN END $(date) ====="

    whiptail \
    --title "Scan Complete" \
    --msgbox "Scan completed successfully\n\nTotal scanned : $TOTAL\nFiles with issues : $FILES_WITH_ISSUES\nIssues found : $ISSUES\nFixes applied : $FIXES\n\nRisk Score : $RISK_SCORE\nRisk Level : $RISK_LEVEL\nCritical Issues : $CRITICAL_ISSUES\nSetUID Files : $SUID_COUNT\nSetGID Files : $SGID_COUNT\n\nReport : $REPORT_FILE\nLogs : $LOG_FILE" 26 90
}