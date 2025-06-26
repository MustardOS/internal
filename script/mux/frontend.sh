#!/bin/sh

. /opt/muos/script/var/func.sh

DEVICE_BOARD="$(GET_VAR "device" "board/name")"

ACT_GO=/tmp/act_go
APP_GO=/tmp/app_go
GOV_GO=/tmp/gov_go
ROM_GO=/tmp/rom_go

EX_CARD=/tmp/explore_card

MUX_AUTH=/tmp/mux_auth
MUX_LAUNCHER_AUTH=/tmp/mux_launcher_auth

SKIP=0

if [ -n "$1" ]; then
	ACT="$1"
	SKIP=1
else
	ACT=$(GET_VAR "config" "settings/general/startup")
fi
printf '%s\n' "$ACT" >"$ACT_GO"

echo "root" >$EX_CARD

LAST_PLAY=$(cat "/opt/muos/config/boot/last_play")

LOG_INFO "$0" 0 "FRONTEND" "Setting default CPU governor"
SET_DEFAULT_GOVERNOR

if [ $SKIP -eq 0 ]; then
	LOG_INFO "$0" 0 "FRONTEND" "Checking for last or resume startup"
	if [ "$(GET_VAR "config" "settings/general/startup")" = "last" ] || [ "$(GET_VAR "config" "settings/general/startup")" = "resume" ]; then
		GO_LAST_BOOT=1

		if [ -n "$LAST_PLAY" ]; then
			LOG_INFO "$0" 0 "FRONTEND" "Checking for network and retrowait"

			if [ "$(GET_VAR "config" "settings/advanced/retrowait")" -eq 1 ]; then
				NET_START="/tmp/net_start"
				OIP=0

				while :; do
					NW_MSG=$(printf "Waiting for network to connect... (%s)\n\nPress START to continue loading\nPress SELECT to go to main menu" "$OIP")
					/opt/muos/frontend/muxmessage 0 "$NW_MSG"
					OIP=$((OIP + 1))

					if [ "$(cat "$(GET_VAR "device" "network/state")")" = "up" ]; then
						LOG_SUCCESS "$0" 0 "FRONTEND" "Network connected"
						/opt/muos/frontend/muxmessage 0 "Network connected"

						PIP=0
						while ! ping -c 1 -W 5 8.8.8.8 >/dev/null 2>&1; do
							PIP=$((PIP + 1))
							LOG_INFO "$0" 0 "FRONTEND" "Verifying connectivity..."
							/opt/muos/frontend/muxmessage 0 "Verifying connectivity... (%s)" "$PIP"
							/opt/muos/bin/toybox sleep 1
						done

						LOG_SUCCESS "$0" 0 "FRONTEND" "Connectivity verified! Booting content!"
						/opt/muos/frontend/muxmessage 0 "Connectivity verified! Booting content!"

						GO_LAST_BOOT=1
						break
					fi

					if [ "$(cat "$NET_START")" = "ignore" ]; then
						LOG_SUCCESS "$0" 0 "FRONTEND" "Ignoring network connection"
						/opt/muos/frontend/muxmessage 0 "Ignoring network connection... Booting content!"

						GO_LAST_BOOT=1
						break
					fi

					if [ "$(cat "$NET_START")" = "menu" ]; then
						LOG_SUCCESS "$0" 0 "FRONTEND" "Booting to main menu"
						/opt/muos/frontend/muxmessage 0 "Booting to main menu!"

						GO_LAST_BOOT=0
						break
					fi

					/opt/muos/bin/toybox sleep 1
				done
			fi

			if [ $GO_LAST_BOOT -eq 1 ]; then
				LOG_INFO "$0" 0 "FRONTEND" "Booting to last launched content"
				cat "$LAST_PLAY" >"$ROM_GO"

				CONTENT_GOV="$(basename "$LAST_PLAY" .cfg).gov"
				if [ -e "$CONTENT_GOV" ]; then
					printf "%s" "$(cat "$CONTENT_GOV")" >$GOV_GO
				else
					CONTENT_GOV="$(dirname "$LAST_PLAY")/core.gov"
					if [ -e "$CONTENT_GOV" ]; then
						printf "%s" "$(cat "$CONTENT_GOV")" >$GOV_GO
					else
						LOG_INFO "$0" 0 "FRONTEND" "No governor found for launched content"
					fi
				fi

				/opt/muos/script/mux/launch.sh last
			fi
		fi

		echo launcher >$ACT_GO
	fi
fi

cp /opt/muos/log/*.log "$(GET_VAR "device" "storage/rom/mount")/MUOS/log/boot/." &

LOG_INFO "$0" 0 "FRONTEND" "Starting frontend launcher"

while :; do
	pkill -9 -f "gptokeyb" &

	# Reset DPAD<>ANALOGUE switch for H700 devices
	[ "$DEVICE_BOARD" = "rg*" ] && echo 0 >"/sys/class/power_supply/axp2202-battery/nds_pwrkey"

	# Content Loader
	[ -s "$ROM_GO" ] && /opt/muos/script/mux/launch.sh

	[ -s "$ACT_GO" ] && {
		IFS= read -r ACTION <"$ACT_GO"

		LOG_INFO "$0" 0 "FRONTEND" "$(printf "Loading '%s' Action" "$ACTION")"

		case "$ACTION" in
			"launcher")
				touch /tmp/pdi_go
				[ -s "$MUX_AUTH" ] && rm "$MUX_AUTH"
				[ -s "$MUX_LAUNCHER_AUTH" ] && rm "$MUX_LAUNCHER_AUTH"
				EXEC_MUX "launcher" "muxfrontend"
				;;

			"explore") EXEC_MUX "explore" "muxfrontend" ;;

			"app")
				if [ -s "$APP_GO" ]; then
					IFS= read -r RUN_APP <"$APP_GO"
					rm "$APP_GO"
					"$(GET_VAR "device" "storage/rom/mount")/MUOS/application/${RUN_APP}/mux_launch.sh"
					echo appmenu >$ACT_GO
				fi
				;;

			"appmenu") EXEC_MUX "app" "muxfrontend" ;;

			"collection") EXEC_MUX "collection" "muxfrontend" ;;

			"history") EXEC_MUX "history" "muxfrontend" ;;

			"info") EXEC_MUX "info" "muxfrontend" ;;

			"credits")
				/opt/muos/bin/nosefart /opt/muos/share/media/support.nsf &
				EXEC_MUX "info" "muxcredits"
				pkill -9 -f "nosefart" &
				;;

			"reboot")
				PLAY_SOUND reboot
				/opt/muos/script/mux/quit.sh reboot frontend
				;;

			"shutdown")
				PLAY_SOUND shutdown
				/opt/muos/script/mux/quit.sh poweroff frontend
				;;

			*)
				printf "Unknown Module: %s\n" "$ACTION" >&2
				EXEC_MUX "$ACTION" "muxfrontend"
				;;
		esac
	}

done
