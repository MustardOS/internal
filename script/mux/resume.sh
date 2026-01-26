#!/bin/sh

. /opt/muos/script/var/func.sh

NET_STATE=$(GET_VAR "device" "network/state")
RETROWAIT=$(GET_VAR "config" "settings/advanced/retrowait")

ACT_GO="/tmp/act_go"
GOV_GO="/tmp/gov_go"
CON_GO="/tmp/con_go"
RAC_GO="/tmp/rac_go"
ROM_GO="/tmp/rom_go"

NET_START="/tmp/net_start"

LAST_PLAY=$(cat "/opt/muos/config/boot/last_play")
GO_LAST_BOOT=1

if [ -n "$LAST_PLAY" ]; then
	LOG_INFO "$0" 0 "FRONTEND" "Checking for network and retrowait"

	if [ "$RETROWAIT" -eq 1 ]; then
		OIP=0

		while :; do
			NW_MSG=$(printf "Waiting for network to connect... (%s)\n\nPress START to continue loading\nPress SELECT to go to main menu" "$OIP")
			SHOW_MESSAGE 0 "$NW_MSG"
			OIP=$((OIP + 1))

			if [ "$(cat "$NET_STATE")" = "up" ]; then
				LOG_SUCCESS "$0" 0 "FRONTEND" "Network connected"
				SHOW_MESSAGE 35 "Network connected"

				PIP=0
				while ! ping -c 1 -W 5 8.8.8.8 >/dev/null 2>&1; do
					PIP=$((PIP + 1))
					LOG_INFO "$0" 0 "FRONTEND" "Verifying connectivity..."
					SHOW_MESSAGE 70 "Verifying connectivity... (%s)" "$PIP"
					sleep 1
				done

				LOG_SUCCESS "$0" 0 "FRONTEND" "Connectivity verified! Booting content!"
				SHOW_MESSAGE 100 "Connectivity verified! Booting content!"

				GO_LAST_BOOT=1
				break
			fi

			if [ -f "$NET_START" ] && [ "$(cat "$NET_START")" = "ignore" ]; then
				LOG_SUCCESS "$0" 0 "FRONTEND" "Ignoring network connection"
				SHOW_MESSAGE 100 "Ignoring network connection... Booting content!"

				GO_LAST_BOOT=1
				break
			fi

			if [ -f "$NET_START" ] && [ "$(cat "$NET_START")" = "menu" ]; then
				LOG_SUCCESS "$0" 0 "FRONTEND" "Booting to main menu"
				SHOW_MESSAGE 100 "Booting to main menu!"

				GO_LAST_BOOT=0
				break
			fi

			sleep 1
		done
	fi

	MESSAGE stop

	if [ "$GO_LAST_BOOT" -eq 1 ]; then
		LOG_INFO "$0" 0 "FRONTEND" "Booting to last launched content"
		cat "$LAST_PLAY" >"$ROM_GO"

		BASE="$(basename "$LAST_PLAY" .cfg)"
		DIR="$(dirname "$LAST_PLAY")"

		for TYPE in "governor" "control" "retroarch"; do
			case "$TYPE" in
				"governor")
					CONTENT_FILE="${DIR}/${BASE}.gov"
					FALLBACK_FILE="${DIR}/core.gov"
					OUTPUT_FILE="$GOV_GO"
					;;
				"control")
					CONTENT_FILE="${DIR}/${BASE}.con"
					FALLBACK_FILE="${DIR}/core.con"
					OUTPUT_FILE="$CON_GO"
					;;
				"retroarch")
					CONTENT_FILE="${DIR}/${BASE}.rac"
					FALLBACK_FILE="${DIR}/core.rac"
					OUTPUT_FILE="$RAC_GO"
					;;
			esac

			if [ -e "$CONTENT_FILE" ]; then
				cat "$CONTENT_FILE" >"$OUTPUT_FILE"
			elif [ -e "$FALLBACK_FILE" ]; then
				cat "$FALLBACK_FILE" >"$OUTPUT_FILE"
			else
				LOG_INFO "$0" 0 "FRONTEND" "No ${TYPE} file found for launched content"
			fi
		done

		# We'll set a few extra things here so that the user doesn't get
		# a stupid "yOu UsEd tHe ReSeT bUtToN" message because ultimately
		# we don't really care in this particular instance...
		ENSURE_REMOVED "/tmp/safe_quit"
		[ ! -e "/tmp/done_reset" ] && printf 1 >"/tmp/done_reset"
		[ ! -e "/tmp/chime_done" ] && printf 1 >"/tmp/chime_done"
		SET_VAR "config" "system/used_reset" 0

		# Reset audio control status
		RESET_AMIXER

		# Okay we're all set, time to launch whatever we were playing last
		/opt/muos/script/mux/launch.sh
	fi
fi

echo launcher >"$ACT_GO"
