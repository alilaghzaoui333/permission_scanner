#!/bin/bash

set -uo pipefail

POLICY="policy.json"

LOG_DIR="logs"
REPORT_DIR="reports"
SIGNATURE_DIR="signatures"

source modules/utils_module.sh
source modules/logging_module.sh
source modules/scoring_module.sh
source modules/dashboard_module.sh
source modules/scanner_module.sh

validate_dependencies
validate_policy

mkdir -p "$LOG_DIR"
mkdir -p "$REPORT_DIR"
mkdir -p "$SIGNATURE_DIR"

init_logging

clear

whiptail \
--title "Linux Permission Scanner" \
--msgbox "Secure Linux Permission Scanner\n\nAdvanced filesystem permission auditing and automatic correction tool" 14 75

while true; do

CHOICE=$(whiptail \
--title "Main Menu" \
--menu "Choose an option" 20 80 5 \
"1" "Scan only (audit mode)" \
"2" "Scan and fix permissions" \
"3" "View latest report" \
"4" "View latest logs" \
"5" "Exit" \
3>&1 1>&2 2>&3)

STATUS=$?

if [ "$STATUS" -ne 0 ]; then
    clear
    exit 0
fi

CHOICE=$(printf "%s" "$CHOICE" | tr -d '\r\n\t ')

case "$CHOICE" in

1)
MODE="scan"
;;

2)
MODE="fix"
;;

3)

LATEST_REPORT=$(find "$REPORT_DIR" -type f -name "*.txt" 2>/dev/null | sort | tail -n 1)

if [ -n "${LATEST_REPORT:-}" ] && [ -f "$LATEST_REPORT" ]; then

    whiptail \
    --title "Latest Report" \
    --textbox "$LATEST_REPORT" 30 110

else

    whiptail \
    --title "Reports" \
    --msgbox "No reports found" 10 40

fi

continue
;;

4)

LATEST_LOG=$(find "$LOG_DIR" -type f -name "*.log" 2>/dev/null | sort | tail -n 1)

if [ -n "${LATEST_LOG:-}" ] && [ -f "$LATEST_LOG" ]; then

    whiptail \
    --title "Latest Logs" \
    --textbox "$LATEST_LOG" 30 110

else

    whiptail \
    --title "Logs" \
    --msgbox "No logs found" 10 40

fi

continue
;;

5)

clear
exit 0
;;

*)

whiptail \
--title "Menu Error" \
--msgbox "Invalid option selected" 10 40

continue
;;

esac

TARGET=$(whiptail \
--title "Target Directory" \
--inputbox "Enter target directory\n\nExamples:\n./test\n/etc" 14 80 "./test" \
3>&1 1>&2 2>&3)

STATUS=$?

if [ "$STATUS" -ne 0 ]; then
    continue
fi

TARGET=$(printf "%s" "$TARGET" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

if [ -z "$TARGET" ]; then

    whiptail \
    --title "Input Error" \
    --msgbox "Target directory cannot be empty" 10 50

    continue
fi

if ! sudo test -e "$TARGET"; then

    whiptail \
    --title "Input Error" \
    --msgbox "Target does not exist" 10 50

    continue
fi

if ! sudo test -d "$TARGET"; then

    whiptail \
    --title "Input Error" \
    --msgbox "Target is not a directory" 10 50

    continue
fi

RESOLVED_TARGET=$(sudo realpath "$TARGET" 2>/dev/null)

if [ -z "${RESOLVED_TARGET:-}" ]; then

    whiptail \
    --title "Path Error" \
    --msgbox "Failed to resolve target directory" 10 50

    continue
fi

TARGET="$RESOLVED_TARGET"

export TARGET
export MODE

RISK_SCORE=0
CRITICAL_ISSUES=0
RISK_LEVEL="LOW"

clear

scan_filesystem

whiptail \
--title "Scan Finished" \
--msgbox "Returning to main menu" 10 40

clear

done