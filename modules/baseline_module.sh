#!/bin/bash

BASELINE_DIR="baseline"
BASELINE_FILE="$BASELINE_DIR/baseline.json"
SNAPSHOT_DIR="$BASELINE_DIR/snapshots"
CRITICAL_LIST="config/critical_files.txt"

mkdir -p "$BASELINE_DIR"
mkdir -p "$SNAPSHOT_DIR"

generate_baseline() {

    TEMP_JSON=$(mktemp)

    echo "{}" > "$TEMP_JSON"

    while IFS= read -r item
    do

        [ -z "$item" ] && continue
        [ ! -e "$item" ] && continue

        if [ -f "$item" ]; then

            PERM=$(stat -c "%a" "$item" 2>/dev/null)
            OWNER=$(stat -c "%U" "$item" 2>/dev/null)
            GROUP=$(stat -c "%G" "$item" 2>/dev/null)

            [ -z "$PERM" ] && continue

            jq \
            --arg path "$item" \
            --arg perm "$PERM" \
            --arg owner "$OWNER" \
            --arg group "$GROUP" \
            '.[$path] = {
                perm: $perm,
                owner: $owner,
                group: $group
            }' \
            "$TEMP_JSON" > "${TEMP_JSON}.tmp"

            mv "${TEMP_JSON}.tmp" "$TEMP_JSON"

        elif [ -d "$item" ]; then

            while IFS= read -r file
            do

                [ -z "$file" ] && continue
                [ ! -e "$file" ] && continue

                PERM=$(stat -c "%a" "$file" 2>/dev/null)
                OWNER=$(stat -c "%U" "$file" 2>/dev/null)
                GROUP=$(stat -c "%G" "$file" 2>/dev/null)

                [ -z "$PERM" ] && continue

                jq \
                --arg path "$file" \
                --arg perm "$PERM" \
                --arg owner "$OWNER" \
                --arg group "$GROUP" \
                '.[$path] = {
                    perm: $perm,
                    owner: $owner,
                    group: $group
                }' \
                "$TEMP_JSON" > "${TEMP_JSON}.tmp"

                mv "${TEMP_JSON}.tmp" "$TEMP_JSON"

            done < <(sudo find "$item" -type f 2>/dev/null)
        fi

    done < "$CRITICAL_LIST"

    mv "$TEMP_JSON" "$BASELINE_FILE"

    cp "$BASELINE_FILE" \
    "$SNAPSHOT_DIR/snapshot_$(date +%Y%m%d_%H%M%S).json"

    log_change "[BASELINE] Baseline generated"

    write_report "[BASELINE] Baseline generated"
}

compare_with_baseline() {

    local baseline_file="$BASELINE_DIR/baseline.json"

    if [[ ! -f "$baseline_file" ]]; then
        echo "[-] Baseline introuvable."
        return
    fi

    echo "[*] Vérification de l'intégrité..."

    jq -r 'keys[]' "$baseline_file" | while read -r file; do

        expected_perm=$(jq -r --arg f "$file" '.[$f].perm' "$baseline_file")
        expected_owner=$(jq -r --arg f "$file" '.[$f].owner' "$baseline_file")
        expected_group=$(jq -r --arg f "$file" '.[$f].group' "$baseline_file")

        if [[ ! -e "$file" ]]; then
            echo "[ALERTE] Fichier supprimé : $file"
            continue
        fi

        current_perm=$(stat -c "%a" "$file")
        current_owner=$(stat -c "%U" "$file")
        current_group=$(stat -c "%G" "$file")

        if [[ "$expected_perm" != "$current_perm" ]]; then
            echo "[ALERTE] Permission modifiée : $file"
            echo "  Ancien : $expected_perm"
            echo "  Actuel : $current_perm"
        fi

        if [[ "$expected_owner" != "$current_owner" ]]; then
            echo "[ALERTE] Owner modifié : $file"
            echo "  Ancien : $expected_owner"
            echo "  Actuel : $current_owner"
        fi

        if [[ "$expected_group" != "$current_group" ]]; then
            echo "[ALERTE] Groupe modifié : $file"
            echo "  Ancien : $expected_group"
            echo "  Actuel : $current_group"
        fi

    done
}