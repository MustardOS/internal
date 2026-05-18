#!/bin/sh

. /opt/muos/script/var/func.sh

[ "$(GET_VAR "config" "settings/general/activity")" -eq 0 ] && exit 0

NAME="$1"
CORE="$2"
FILE="$3"
ACTION="$4"

LOG_INFO "$0" 0 "TRACK" "$(printf "Activity tracker '%s' for '%s' (core: %s)" "$ACTION" "$NAME" "$CORE")"

TRACK_JSON="$MUOS_STORE_DIR/info/track/playtime_data.json"
TRACK_LOG="$(GET_VAR "device" "storage/rom/mount")/MUOS/log/playtime_error.log"

if [ "$(GET_VAR "config" "boot/device_mode")" -eq 1 ]; then
	MODE="console"
else
	MODE="handheld"
fi

# Pre-compute values used in multiple jq calls to avoid repeated subshell forks
BOARD_NAME="$(GET_VAR "device" "board/name")"
NOW="$(date +%s)"

# Create directory and data file if they don't exist
mkdir -p "$(dirname "$TRACK_JSON")"
if [ ! -f "$TRACK_JSON" ] || [ ! -s "$TRACK_JSON" ]; then
	printf '{}' >"$TRACK_JSON"
fi

# For debugging - output values to a log file
# printf '%s\n' "$(date): $NAME $CORE $FILE $ACTION" >> "/mnt/mmc/MUOS/info/track/playtime_debug.log"

MIGRATE_JSON() {
	if ! command -v jq >/dev/null 2>&1; then
		LOG_WARN "$0" 0 "TRACK" "jq is missing - skipping migration"
		return
	fi

	# fast skip
	if ! grep -q '"/mnt/union/' "$TRACK_JSON"; then
		return
	fi

	TMP="${TRACK_JSON}.migrate"

	jq -r 'keys[]' "$TRACK_JSON" | while IFS= read -r key; do
		case "$key" in
			/mnt/union/*)
				REL="${key#/mnt/union/}"

				FOUND=""
				for m in /mnt/usb /mnt/sdcard /mnt/mmc; do
					CAND="$m/$REL"
					if [ -f "$CAND" ] || [ -d "$CAND" ]; then
						FOUND="$CAND"
						break
					fi
				done

				if [ -n "$FOUND" ]; then
					# check if destination already exists
					if jq -e --arg new "$FOUND" '.[$new]' "$TRACK_JSON" >/dev/null 2>&1; then
						# destination exists then purge old
						jq --arg old "$key" 'del(.[$old])' "$TRACK_JSON" >"$TMP" && mv "$TMP" "$TRACK_JSON"
					else
						# safe to migrate
						jq --arg old "$key" --arg new "$FOUND" '.[$new] = .[$old] | del(.[$old])' "$TRACK_JSON" >"$TMP" && mv "$TMP" "$TRACK_JSON"
					fi
				else
					# no valid path? purge away
					jq --arg old "$key" 'del(.[$old])' "$TRACK_JSON" >"$TMP" && mv "$TMP" "$TRACK_JSON"
				fi
				;;
		esac
	done
}

UPDATE_JSON() {
	if ! command -v jq >/dev/null 2>&1; then
		LOG_ERROR "$0" 0 "TRACK" "jq is required for JSON processing"
		printf "Error: jq is required for JSON processing.\n" >&2
		exit 1
	fi

	# Escape the path for use as a JSON key
	ESCAPED_PATH=$(printf '%s' "$FILE" | sed 's/\\/\\\\/g; s/"/\\"/g')

	if [ "$ACTION" = "start" ]; then
		# Ensure the data file contains valid JSON before proceeding
		if [ ! -s "$TRACK_JSON" ] || ! jq empty "$TRACK_JSON" 2>/dev/null; then
			printf '{}' >"$TRACK_JSON"
		fi

		# Check if game exists in data using path as unique key
		if jq -e ".\"$ESCAPED_PATH\"" "$TRACK_JSON" >/dev/null 2>&1; then
			# Game exists -- update launch metadata
			jq --arg path "$ESCAPED_PATH" \
				--arg time "$NOW" \
				--arg core "$CORE" \
				--arg device "$BOARD_NAME" \
				--arg mode "$MODE" \
				'.[$path].last_core = $core
			   | .[$path].start_time = ($time | tonumber)
			   | .[$path].mode = $mode
			   | .[$path].launches += 1
			   | if .[$path].core_launches[$core]     then .[$path].core_launches[$core]     += 1 else .[$path].core_launches[$core]     = 1 end
			   | if .[$path].device_launches[$device] then .[$path].device_launches[$device] += 1 else .[$path].device_launches[$device] = 1 end
			   | if .[$path].mode_launches[$mode]     then .[$path].mode_launches[$mode]     += 1 else .[$path].mode_launches[$mode]     = 1 end' \
				"$TRACK_JSON" >"${TRACK_JSON}.tmp"
		else
			# New game entry
			jq --arg path "$ESCAPED_PATH" \
				--arg time "$NOW" \
				--arg name "$NAME" \
				--arg core "$CORE" \
				--arg device "$BOARD_NAME" \
				--arg mode "$MODE" \
				'.[$path] = {
			       "name": $name,
			       "last_core": $core,
			       "core_launches": {},
			       "last_device": $device,
			       "device_launches": {},
			       "last_mode": $mode,
			       "mode_launches": {},
			       "launches": 1,
			       "start_time": ($time | tonumber),
			       "total_time": 0,
			       "avg_time": 0,
			       "last_session": 0
			   }
			   | .[$path].core_launches[$core]     = 1
			   | .[$path].device_launches[$device] = 1
			   | .[$path].mode_launches[$mode]     = 1' \
				"$TRACK_JSON" >"${TRACK_JSON}.tmp"
		fi

		if [ -s "${TRACK_JSON}.tmp" ]; then
			mv "${TRACK_JSON}.tmp" "$TRACK_JSON"
		else
			printf "Error: Failed to create tmp file\n" >>"$TRACK_LOG"
		fi
	elif [ "$ACTION" = "resume" ]; then
		if jq -e ".\"$ESCAPED_PATH\"" "$TRACK_JSON" >/dev/null 2>&1; then
			# Reset start_time so the next stop calculates only post-resume time,
			# without touching launch count since this is not a new launch
			jq --arg path "$ESCAPED_PATH" \
				--arg time "$NOW" \
				'.[$path].start_time = ($time | tonumber)' \
				"$TRACK_JSON" >"${TRACK_JSON}.tmp"

			if [ -s "${TRACK_JSON}.tmp" ]; then
				mv "${TRACK_JSON}.tmp" "$TRACK_JSON"
			else
				LOG_ERROR "$0" 0 "TRACK" "Failed to create tmp file on resume"
				printf "Error: Failed to create tmp file on resume\n" >>"$TRACK_LOG"
			fi
		else
			LOG_WARN "$0" 0 "TRACK" "$(printf "Game '%s' not found in data file on resume" "$ESCAPED_PATH")"
			printf "Error: Game %s not found in data file on resume\n" "$ESCAPED_PATH" >>"$TRACK_LOG"
		fi
	elif [ "$ACTION" = "stop" ]; then
		if jq -e ".\"$ESCAPED_PATH\"" "$TRACK_JSON" >/dev/null 2>&1; then
			START_TIME=$(jq -r ".\"$ESCAPED_PATH\".start_time // 0" "$TRACK_JSON")

			# Only calculate if start_time is valid
			if [ "$START_TIME" != "null" ] && [ "$START_TIME" -gt 0 ]; then
				SESSION_TIME=$((NOW - START_TIME))
				LOG_DEBUG "$0" 0 "TRACK" "$(printf "Session time for '%s': %s seconds" "$NAME" "$SESSION_TIME")"

				jq --arg path "$ESCAPED_PATH" \
					--arg session "$SESSION_TIME" \
					'.[$path].last_session = ($session | tonumber)
				   | .[$path].total_time  += ($session | tonumber)
				   | .[$path].avg_time     = (.[$path].total_time / .[$path].launches)' \
					"$TRACK_JSON" >"${TRACK_JSON}.tmp"

				if [ -s "${TRACK_JSON}.tmp" ]; then
					mv "${TRACK_JSON}.tmp" "$TRACK_JSON"
				else
					LOG_ERROR "$0" 0 "TRACK" "Failed to create tmp file on stop"
					printf "Error: Failed to create tmp file on stop\n" >>"$TRACK_LOG"
				fi
			else
				LOG_ERROR "$0" 0 "TRACK" "$(printf "Invalid start_time for '%s': %s" "$ESCAPED_PATH" "$START_TIME")"
				printf "Error: Invalid start_time for %s: %s\n" "$ESCAPED_PATH" "$START_TIME" >>"$TRACK_LOG"
			fi
		else
			LOG_WARN "$0" 0 "TRACK" "$(printf "Game '%s' not found in data file on stop" "$ESCAPED_PATH")"
			printf "Error: Game %s not found in data file on stop\n" "$ESCAPED_PATH" >>"$TRACK_LOG"
		fi
	fi
}

case "$ACTION" in
	start | stop | resume)
		MIGRATE_JSON
		UPDATE_JSON
		;;
	*)
		LOG_ERROR "$0" 0 "TRACK" "$(printf "Unknown action: '%s'" "$ACTION")"
		printf "Usage: %s <name> <core> <file> <start|stop>\n" "$0" >&2
		exit 1
		;;
esac

exit 0
