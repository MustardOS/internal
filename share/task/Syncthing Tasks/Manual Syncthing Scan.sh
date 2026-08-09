#!/bin/sh
# HELP: Manual Syncthing Scan
# ICON: backup
# EXECUTION_MODE: progress
# CAN_CANCEL: 0
# PROTOCOL_VERSION: 1

# Diagnostics belong on stderr, which is logged. Stdout carries the task records,
# so redirecting it would put this script's log in the middle of the protocol.
exec 2>>"/tmp/tt_manual_sync.log"

. /opt/muos/script/var/func.sh
. /opt/muos/script/var/ui.sh

TASK_BEGIN "manual_syncthing_scan" "Manual Syncthing Scan"

# START SCRIPT
# Check if Syncthing is enabled in config
SYNCTHING_ENABLED=$(GET_VAR "config" "web/syncthing")
# Check if network is up
NETWORK_STATE=$(cat "$(GET_VAR "device" "network/state")")
ERROR_FLAG=0
SCANNED=0

if [ -z "$SYNCTHING_ENABLED" ]; then
    TASK_ERROR "no_setting" "Could not tell whether Syncthing is enabled"
    ERROR_FLAG=1
elif [ -z "$NETWORK_STATE" ]; then
    TASK_ERROR "no_network" "Could not tell whether the network is up"
    ERROR_FLAG=1
elif [ "$SYNCTHING_ENABLED" -eq 1 ] && [ "$NETWORK_STATE" = "up" ]; then
    SYNCTHING_API=$(sed -n 's:.*<apikey>\([^<]*\)</apikey>.*:\1:p' "$MUOS_STORE_DIR/syncthing/config.xml")
    SYNCTHING_PORT=$(GET_WEB_PORT "syncthing_port" 7070)
fi

if [ "$ERROR_FLAG" -eq 0 ] && [ -z "$SYNCTHING_API" ]; then 
    TASK_ERROR "no_api_key" "The Syncthing API key could not be read"
    ERROR_FLAG=1
else
    # Get list of folder IDs from Syncthing API
    FOLDER_IDS=$(curl -s -H "X-API-Key: $SYNCTHING_API" "http://localhost:$SYNCTHING_PORT/rest/config" | jq -r '.folders[].id')
    for FOLDER_ID in $FOLDER_IDS; do
        TASK_STATUS "$(printf "Scanning folder %s" "$FOLDER_ID")"
        SCANNED=$((SCANNED + 1))
        # Initiate scan (non-blocking)
        curl -s -X POST -H "X-API-Key: $SYNCTHING_API" "http://localhost:$SYNCTHING_PORT/rest/db/scan?folder=$FOLDER_ID" >/dev/null 2>&1 &
        sleep 1
    done
fi

if [ "$ERROR_FLAG" -eq 1 ]; then
    TASK_COMPLETE "Syncthing scan was skipped"
    exit 1
fi

TASK_STATUS "Sync Filesystem"
sync

if [ "$SCANNED" -eq 0 ]; then
    TASK_COMPLETE "Syncthing had no folders to scan"
else
    TASK_COMPLETE "$(printf "Syncthing scan started for %s folder(s)" "$SCANNED")"
fi

exit 0
