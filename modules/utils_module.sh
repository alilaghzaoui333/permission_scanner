#!/bin/bash

validate_dependencies() {

    command -v jq >/dev/null 2>&1 || {
        whiptail \
        --title "Dependency Error" \
        --msgbox "jq is not installed" 10 50
        exit 1
    }

    command -v whiptail >/dev/null 2>&1 || {
        echo "whiptail is not installed"
        exit 1
    }

    command -v sha256sum >/dev/null 2>&1 || {
        whiptail \
        --title "Dependency Error" \
        --msgbox "sha256sum is not installed" 10 50
        exit 1
    }

    command -v sudo >/dev/null 2>&1 || {
        whiptail \
        --title "Dependency Error" \
        --msgbox "sudo is not installed" 10 50
        exit 1
    }
}

validate_policy() {

    if [ ! -f "$POLICY" ]; then

        whiptail \
        --title "Configuration Error" \
        --msgbox "policy.json not found" 10 50

        exit 1
    fi

    jq empty "$POLICY" >/dev/null 2>&1

    if [ $? -ne 0 ]; then

        whiptail \
        --title "Configuration Error" \
        --msgbox "Invalid JSON format in policy.json" 10 60

        exit 1
    fi
}

validate_target() {

    TARGET=$(echo "$TARGET" | tr -d '[:space:]')

    if [ -z "$TARGET" ]; then

        whiptail \
        --title "Input Error" \
        --msgbox "Target directory is empty" 10 50

        return 1
    fi

    if [ ! -e "$TARGET" ]; then

        whiptail \
        --title "Input Error" \
        --msgbox "Target does not exist" 10 50

        return 1
    fi

    if [ ! -d "$TARGET" ]; then

        whiptail \
        --title "Input Error" \
        --msgbox "Target is not a directory" 10 50

        return 1
    fi

    return 0
}

is_exception() {

    local item="$1"

    while read -r ex; do

        [[ "$item" == "$ex" || "$item" == "$ex/"* ]] && return 0

    done < <(jq -r '.exceptions[]' "$POLICY")

    return 1
}

detect_world_writable() {

    local perm="$1"

    local others=$((perm % 10))

    (( others & 2 ))
}