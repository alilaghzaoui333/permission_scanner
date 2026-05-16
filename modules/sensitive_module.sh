#!/bin/bash

scan_sensitive_files() {

    SENSITIVE_FILES=(
        "/etc/passwd:644:root"
        "/etc/shadow:640:root"
        "/etc/group:644:root"
        "/etc/gshadow:640:root"
        "/etc/sudoers:440:root"
    )

    write_report "===== SENSITIVE FILES ANALYSIS ====="

    for entry in "${SENSITIVE_FILES[@]}"; do

        FILE_PATH=$(echo "$entry" | cut -d ":" -f1)
        EXPECTED_PERM=$(echo "$entry" | cut -d ":" -f2)
        EXPECTED_OWNER=$(echo "$entry" | cut -d ":" -f3)

        if [ ! -e "$FILE_PATH" ]; then

            write_report "[WARNING] Sensitive file not found : $FILE_PATH"
            continue
        fi

        stat "$FILE_PATH" >/dev/null 2>&1 || continue

        ACTUAL_PERM=$(stat -c "%a" "$FILE_PATH" 2>/dev/null)
        ACTUAL_OWNER=$(stat -c "%U" "$FILE_PATH" 2>/dev/null)

        write_report "[CHECK] $FILE_PATH"

        write_report "Expected Permission : $EXPECTED_PERM"
        write_report "Actual Permission   : $ACTUAL_PERM"

        write_report "Expected Owner      : $EXPECTED_OWNER"
        write_report "Actual Owner        : $ACTUAL_OWNER"

        if [ "$ACTUAL_PERM" != "$EXPECTED_PERM" ]; then

            write_report "[CRITICAL ALERT] Invalid permission on $FILE_PATH"

            ((ISSUES++))
            ((FILES_WITH_ISSUES++))

            add_risk "CRITICAL"

            if [ "$MODE" = "fix" ]; then

                chmod "$EXPECTED_PERM" "$FILE_PATH" 2>/dev/null

                if [ $? -eq 0 ]; then

                    ((FIXES++))

                    log_change "[FIX] Sensitive file permission corrected : $FILE_PATH"

                else

                    log_change "[ERROR] Failed to correct permission : $FILE_PATH"

                fi
            fi
        fi

        if [ "$ACTUAL_OWNER" != "$EXPECTED_OWNER" ]; then

            write_report "[CRITICAL ALERT] Invalid owner on $FILE_PATH"

            ((ISSUES++))
            ((FILES_WITH_ISSUES++))

            add_risk "CRITICAL"

            if [ "$MODE" = "fix" ]; then

                chown "$EXPECTED_OWNER":"$EXPECTED_OWNER" "$FILE_PATH" 2>/dev/null

                if [ $? -eq 0 ]; then

                    ((FIXES++))

                    log_change "[FIX] Sensitive file ownership corrected : $FILE_PATH"

                else

                    log_change "[ERROR] Failed to correct ownership : $FILE_PATH"

                fi
            fi
        fi

        write_report "----------------------------------------"

    done
}