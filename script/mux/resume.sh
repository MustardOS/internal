#!/bin/sh

. /opt/muos/script/var/func.sh

NET_STATE=$(GET_VAR "device" "network/state")
RETROWAIT=$(GET_VAR "config" "settings/advanced/retrowait")

NET_START="$MUOS_RUN_DIR/net_start"
LAST_PLAY_FILE="/opt/muos/config/boot/last_play"

NET_WAIT_MAX=60
PING_WAIT_MAX=6
GO_LAST_BOOT=1

HANDLE_NET_START_CHOICE() {
	[ -r "$NET_START" ] || return 1

	NET_CHOICE=$(READ_FIRST_LINE "$NET_START")

	case "$NET_CHOICE" in
		ignore)
			ENSURE_REMOVED_SYNC "$NET_START"
			LOG_SUCCESS "$0" 0 "FRONTEND" "Ignoring network connection"
			SHOW_MESSAGE 100 "Ignoring network connection... Booting content!"
			GO_LAST_BOOT=1
			return 0
			;;
		menu)
			ENSURE_REMOVED_SYNC "$NET_START"
			LOG_SUCCESS "$0" 0 "FRONTEND" "Booting to main menu"
			SHOW_MESSAGE 100 "Booting to main menu!"
			GO_LAST_BOOT=0
			return 0
			;;
	esac

	return 1
}

WAIT_FOR_NETWORK() {
	SHOW_SPLASH clear
	OIP=0

	while [ "$OIP" -lt "$NET_WAIT_MAX" ]; do
		NW_MSG=$(printf "Waiting for network to connect... (%s/%s)\n\nPress START to continue loading\nPress SELECT to go to main menu" "$OIP" "$NET_WAIT_MAX")
		SHOW_MESSAGE 0 "$NW_MSG"

		if [ -r "$NET_STATE" ] && [ "$(READ_FIRST_LINE "$NET_STATE")" = "up" ]; then
			LOG_SUCCESS "$0" 0 "FRONTEND" "Network connected"
			SHOW_MESSAGE 35 "Network connected"

			PIP=0
			while ! ping -c 1 -W 5 8.8.8.8 >/dev/null 2>&1; do
				PIP=$((PIP + 1))

				LOG_INFO "$0" 0 "FRONTEND" "Verifying connectivity"
				SHOW_MESSAGE 70 "Verifying connectivity... (%s/%s)" "$PIP" "$PING_WAIT_MAX"

				if [ "$PIP" -ge "$PING_WAIT_MAX" ]; then
					LOG_WARN "$0" 0 "FRONTEND" "Connectivity check timed out; continuing"
					SHOW_MESSAGE 100 "Connectivity check timed out... Booting content!"
					GO_LAST_BOOT=1
					return 0
				fi

				HANDLE_NET_START_CHOICE && return 0
				sleep 1
			done

			LOG_SUCCESS "$0" 0 "FRONTEND" "Connectivity verified"
			SHOW_MESSAGE 100 "Connectivity verified! Booting content!"
			GO_LAST_BOOT=1
			return 0
		fi

		HANDLE_NET_START_CHOICE && return 0

		OIP=$((OIP + 1))
		sleep 1
	done

	LOG_WARN "$0" 0 "FRONTEND" "Network wait timed out; continuing"
	SHOW_MESSAGE 100 "Network wait timed out... Booting content!"
	GO_LAST_BOOT=1
	return 0
}

PREPARE_LAST_PLAY() {
	LAST_PLAY=$1

	LOG_INFO "$0" 0 "FRONTEND" "Booting to last launched content"
	SAFE_WRITE "$LAST_PLAY" "$ROM_GO"

	CONTENT_BASE=$(basename "$LAST_PLAY" .cfg)
	CONTENT_DIR=$(dirname "$LAST_PLAY")
	COPY_CONTENT_SETTINGS "$CONTENT_BASE" "$CONTENT_DIR"

	ENSURE_REMOVED_SYNC "/tmp/safe_quit"
	[ ! -e "/tmp/done_reset" ] && printf "1" >"/tmp/done_reset"
	[ ! -e "/tmp/chime_done" ] && printf "1" >"/tmp/chime_done"
	SET_VAR "config" "system/used_reset" 0

	RESET_MIXER
}

LAST_PLAY=$(READ_FIRST_LINE "$LAST_PLAY_FILE" 2>/dev/null)

if [ -n "$LAST_PLAY" ] && [ -r "$LAST_PLAY" ]; then
	LOG_INFO "$0" 0 "FRONTEND" "Checking for network and retrowait"

	if IS_ONE "$RETROWAIT"; then
		WAIT_FOR_NETWORK
	fi

	MESSAGE stop

	if IS_ONE "$GO_LAST_BOOT"; then
		PREPARE_LAST_PLAY "$LAST_PLAY"
	else
		ENSURE_REMOVED_SYNC "$ROM_GO"
	fi
else
	LOG_WARN "$0" 0 "FRONTEND" "No valid last launched content found"
	ENSURE_REMOVED_SYNC "$ROM_GO"
fi

SAFE_WRITE "launcher" "$ACT_GO"
