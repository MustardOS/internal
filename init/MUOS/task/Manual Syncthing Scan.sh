#!/bin/sh
# HELP: Manual Syncthing Scan
# ICON: backup

LOGFILE="/tmp/tt_manual_sync.log"
exec > >(tee -a "$LOGFILE") 2>&1

. /opt/muos/script/var/func.sh
FRONTEND stop

# START SCRIPT
echo "Starting Manual Syncthing Scan at $(date +"%Y-%m-%d %H:%M:%S")"

# Check if Syncthing is enabled in config
SYNCTHING_ENABLED=$(GET_VAR "config" "web/syncthing")
# Check if network is up
NETWORK_STATE=$(cat "$(GET_VAR "device" "network/state")")
ERROR_FLAG=0

if [ -z "$SYNCTHING_ENABLED" ]; then
    echo "Error: Could not determine if Syncthing is enabled. Skipping scan."
    ERROR_FLAG=1
elif [ -z "$NETWORK_STATE" ]; then
    echo "Error: Could not determine network state. Skipping scan."
    ERROR_FLAG=1
elif [ "$SYNCTHING_ENABLED" -eq 1 ] && [ "$NETWORK_STATE" = "up" ]; then
    SYNCTHING_API=$(sed -n 's:.*<apikey>\([^<]*\)</apikey>.*:\1:p' /run/muos/storage/syncthing/config.xml)
fi

if [ ERROR_FLAG -eq 0 ] && [ -z "$SYNCTHING_API" ]; then 
    echo "Error: Syncthing API key not found or config file is missing/malformed. Skipping scan."
    ERROR_FLAG=1
else
    # Get list of folder IDs from Syncthing API
    FOLDER_IDS=$(curl -s -H "X-API-Key: $SYNCTHING_API" "http://localhost:7070/rest/config" | jq -r '.folders[].id')
    for FOLDER_ID in $FOLDER_IDS; do
        echo "[INFO] Starting scan for folder: $FOLDER_ID"
        # Initiate scan (non-blocking)
        curl -s -X POST -H "X-API-Key: $SYNCTHING_API" "http://localhost:7070/rest/db/scan?folder=$FOLDER_ID" >/dev/null 2>&1 &
        sleep 1
    done
fi

if [ $ERROR_FLAG -eq 1 ]; then
    echo "Error occurred during manual Syncthing scan."
fi

echo "Sync Filesystem"
sync

echo "Manual Syncthing Scan completed at $(date +"%Y-%m-%d %H:%M:%S")"
/opt/muos/bin/toybox sleep 2

FRONTEND start task
exit 0
