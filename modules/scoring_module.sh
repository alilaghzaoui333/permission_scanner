#!/bin/bash

RISK_SCORE=0
CRITICAL_ISSUES=0
HIGH_ISSUES=0
MEDIUM_ISSUES=0
LOW_ISSUES=0

RISK_LEVEL="LOW"

MAX_RISK_SCORE=100

add_risk() {

    local severity="$1"

    case "$severity" in

        LOW)

            ((LOW_ISSUES++))
            ((RISK_SCORE+=2))

        ;;

        MEDIUM)

            ((MEDIUM_ISSUES++))
            ((RISK_SCORE+=5))

        ;;

        HIGH)

            ((HIGH_ISSUES++))
            ((CRITICAL_ISSUES++))
            ((RISK_SCORE+=10))

        ;;

        CRITICAL)

            ((CRITICAL_ISSUES++))
            ((RISK_SCORE+=20))

        ;;

    esac

    if [ "$RISK_SCORE" -gt "$MAX_RISK_SCORE" ]; then
        RISK_SCORE="$MAX_RISK_SCORE"
    fi

    calculate_risk_level
}

calculate_risk_level() {

    if [ "$CRITICAL_ISSUES" -ge 10 ] || [ "$RISK_SCORE" -ge 80 ]; then

        RISK_LEVEL="CRITICAL"

    elif [ "$HIGH_ISSUES" -ge 10 ] || [ "$RISK_SCORE" -ge 60 ]; then

        RISK_LEVEL="HIGH"

    elif [ "$MEDIUM_ISSUES" -ge 10 ] || [ "$RISK_SCORE" -ge 30 ]; then

        RISK_LEVEL="MEDIUM"

    else

        RISK_LEVEL="LOW"

    fi
}

reset_risk_score() {

    RISK_SCORE=0

    CRITICAL_ISSUES=0
    HIGH_ISSUES=0
    MEDIUM_ISSUES=0
    LOW_ISSUES=0

    RISK_LEVEL="LOW"
}