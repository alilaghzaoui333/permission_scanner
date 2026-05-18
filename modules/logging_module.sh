#!/bin/bash

LOG_ENABLED=true
init_logging() {

    mkdir -p "$LOG_DIR" "$REPORT_DIR" "$SIGNATURE_DIR"

    TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")

    LOG_FILE="$LOG_DIR/changes_$TIMESTAMP.log"
    REPORT_FILE="$REPORT_DIR/report_$TIMESTAMP.txt"

    touch "$LOG_FILE" "$REPORT_FILE" || {
        echo "Cannot initialize logging system"
        exit 1
    }
}

log_change() {

    local message="$1"

    [ "$LOG_ENABLED" != "true" ] && return

    echo "[$(date +"%H:%M:%S")] $message" >> "$LOG_FILE"
}

write_report() {

    local message="$1"

    echo "$message" >> "$REPORT_FILE"
}

generate_signature() {

    local file="$1"

    [ ! -f "$file" ] && return

    local filename
    filename=$(basename "$file")

    sha256sum "$file" > "$SIGNATURE_DIR/$filename.sha256"
}