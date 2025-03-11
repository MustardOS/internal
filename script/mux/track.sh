#!/bin/sh

. /opt/muos/script/var/func.sh

NAME="$1"
CORE="$2"
FILE="$3"
ACTION="$4"

TRACK_JSON="$(GET_VAR "device" "storage/rom/mount")/MUOS/info/track/playtime_data.json"
TRACK_LOG="$(GET_VAR "device" "storage/rom/mount")/MUOS/log/playtime_error.log"

if [ "$(cat "$(GET_VAR "device" "screen/hdmi")")" -eq 1 ] && [ "$(GET_VAR "device" "board/hdmi")" -eq 1 ]; then
    MODE="console"
else
    MODE="handheld"
fi

# Create directory and data file if they don't exist
mkdir -p "$(dirname "$TRACK_JSON")"
if [ ! -f "$TRACK_JSON" ] || [ ! -s "$TRACK_JSON" ]; then
    echo "{}" > "$TRACK_JSON"
fi

# For debugging - output values to a log file
# echo "$(date): $NAME $CORE $FILE $ACTION" >> "/mnt/mmc/MUOS/info/track/playtime_debug.log"

# Update JSON Data
update_json() {
    if command -v jq >/dev/null 2>&1; then
        # Escape the path for use as a JSON key
        ESCAPED_PATH=$(echo "$FILE" | sed 's/\\/\\\\/g; s/"/\\"/g')
        
        if [ "$ACTION" = "start" ]; then
            # Check if the file is empty or not valid JSON
            if [ ! -s "$TRACK_JSON" ] || ! jq empty "$TRACK_JSON" 2>/dev/null; then
                echo "{}" > "$TRACK_JSON"
            fi
            
            # Check if game exists in data using path (should be good for unique key)
            if jq -e ".\"$ESCAPED_PATH\"" "$TRACK_JSON" >/dev/null 2>&1; then
                # Game exists! Update all the stuff
                jq --arg path "$ESCAPED_PATH" --arg time "$(date +%s)" --arg core "$CORE" --arg device "$(GET_VAR "device" "board/name")" --arg mode $MODE \
                   ".[\$path].last_core = \$core | .[\$path].start_time = (\$time | tonumber) | .[\$path].mode = \$mode | .[\$path].launches += 1 | if .[\$path].core_launches[\$core] then .[\$path].core_launches[\$core] += 1 else .[\$path].core_launches[\$core] = 1 end | if .[\$path].device_launches[\$device] then .[\$path].device_launches[\$device] += 1 else .[\$path].device_launches[\$device] = 1 end | if .[\$path].mode_launches[\$mode] then .[\$path].mode_launches[\$mode] += 1 else .[\$path].mode_launches[\$mode] = 1 end" \
                   "$TRACK_JSON" > "${TRACK_JSON}.tmp"
            else
                # Game doesn't exist. Create entry
                jq --arg path "$ESCAPED_PATH" --arg time "$(date +%s)" --arg name "$NAME" --arg core "$CORE" --arg device "$(GET_VAR "device" "board/name")" --arg mode $MODE \
                   ".[\$path] = {\"name\": \$name, \"last_core\": \$core, \"core_launches\": {}, \"last_device\": \$device, \"device_launches\": {}, \"last_mode\": \$mode, \"mode_launches\": {}, \"launches\": 1, \"start_time\": (\$time | tonumber), \"total_time\": 0, \"avg_time\": 0, \"last_session\": 0} | .[\$path].core_launches[\$core] = 1 | .[\$path].device_launches[\$device] = 1 | .[\$path].mode_launches[\$mode] = 1" \
                   "$TRACK_JSON" > "${TRACK_JSON}.tmp"
            fi
            
            # Replace the original file if tmp file has content
            if [ -s "${TRACK_JSON}.tmp" ]; then
                mv "${TRACK_JSON}.tmp" "$TRACK_JSON"
            else
                echo "Error: Failed to create tmp file" >> "$TRACK_LOG"
            fi
            
        elif [ "$ACTION" = "stop" ]; then
            # Check if the game exists.
            if jq -e ".\"$ESCAPED_PATH\"" "$TRACK_JSON" >/dev/null 2>&1; then
                current_time=$(date +%s)
                start_time=$(jq -r ".\"$ESCAPED_PATH\".start_time // 0" "$TRACK_JSON")
                
                # Only calculate if start_time is valid
                if [ "$start_time" != "null" ] && [ "$start_time" -gt 0 ]; then
                    session_time=$((current_time - start_time))
                    
                    # Update the data
                    jq --arg path "$ESCAPED_PATH" --arg session "$session_time" \
                       ".[\$path].last_session = (\$session | tonumber) | .[\$path].total_time += (\$session | tonumber) | .[\$path].avg_time = (.[\$path].total_time / .[\$path].launches)" \
                       "$TRACK_JSON" > "${TRACK_JSON}.tmp"
                    
                    # Replace the original file if tmp file has content
                    if [ -s "${TRACK_JSON}.tmp" ]; then
                        mv "${TRACK_JSON}.tmp" "$TRACK_JSON"
                    else
                        echo "Error: Failed to create tmp file on stop" >> "$TRACK_LOG"
                    fi
                else
                    echo "Error: Invalid start_time for $ESCAPED_PATH: $start_time" >> "$TRACK_LOG"
                fi
            else
                echo "Error: Game $ESCAPED_PATH not found in data file on stop" >> "$TRACK_LOG"
            fi
        fi
    else
        echo "Error: jq is required for JSON processing." >&2
        exit 1
    fi
}

case "$ACTION" in
    start|stop)
        update_json
        ;;
    *)
        echo "Usage: $0 <name> <core> <file> <start|stop>" >&2
        exit 1
        ;;
esac

exit 0