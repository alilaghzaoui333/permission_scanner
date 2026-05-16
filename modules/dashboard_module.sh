#!/bin/bash

show_dashboard() {

    clear

    echo "================================================="
    echo "            LINUX SECURITY DASHBOARD"
    echo "================================================="
    echo
    echo "Target Directory : $TARGET"
    echo
    echo "Files Scanned    : $TOTAL"
    echo "Issues Found     : $ISSUES"
    echo "Fixes Applied    : $FIXES"
    echo
    echo "Risk Score       : $RISK_SCORE"
    echo "Risk Level       : $RISK_LEVEL"
    echo "Critical Issues  : $CRITICAL_ISSUES"
    echo
    echo "Current File     : $CURRENT_FILE"
    echo
    echo "Scanner Mode     : ${MODE^^}"
    echo
    echo "================================================="
}