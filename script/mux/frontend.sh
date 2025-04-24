#!/bin/sh

case ":$LD_LIBRARY_PATH:" in
	*":/opt/muos/extra/lib:"*) ;;
	*) export LD_LIBRARY_PATH="/opt/muos/extra/lib:$LD_LIBRARY_PATH" ;;
esac

. /opt/muos/script/var/func.sh

DEVICE_BOARD="$(GET_VAR "device" "board/name")"

ACT_GO=/tmp/act_go
APP_GO=/tmp/app_go
GVR_GO=/tmp/gvr_go
ROM_GO=/tmp/rom_go
RES_GO=/tmp/res_go

EX_CARD=/tmp/explore_card
EX_NAME=/tmp/explore_name
EX_DIR=/tmp/explore_dir

CL_DIR=/tmp/collection_dir
CL_AMW=/tmp/add_mode_work

MUX_AUTH=/tmp/mux_auth
MUX_LAUNCHER_AUTH=/tmp/mux_launcher_auth

DEF_ACT=$(GET_VAR "global" "settings/general/startup")
printf '%s\n' "$DEF_ACT" >$ACT_GO

echo "root" >$EX_CARD

LAST_PLAY=$(cat "/opt/muos/config/lastplay.txt")
LAST_INDEX=0

LOG_INFO "$0" 0 "FRONTEND" "Setting default CPU governor"
DEF_GOV=$(GET_VAR "device" "cpu/default")
printf '%s' "$DEF_GOV" >"$(GET_VAR "device" "cpu/governor")"
if [ "$DEF_GOV" = ondemand ]; then
	GET_VAR "device" "cpu/sampling_rate_default" >"$(GET_VAR "device" "cpu/sampling_rate")"
	GET_VAR "device" "cpu/up_threshold_default" >"$(GET_VAR "device" "cpu/up_threshold")"
	GET_VAR "device" "cpu/sampling_down_factor_default" >"$(GET_VAR "device" "cpu/sampling_down_factor")"
	GET_VAR "device" "cpu/io_is_busy_default" >"$(GET_VAR "device" "cpu/io_is_busy")"
fi

LOG_INFO "$0" 0 "FRONTEND" "Checking for last or resume startup"
if [ "$(GET_VAR "global" "settings/general/startup")" = "last" ] || [ "$(GET_VAR "global" "settings/general/startup")" = "resume" ]; then
	GO_LAST_BOOT=1

	if [ -n "$LAST_PLAY" ]; then
		LOG_INFO "$0" 0 "FRONTEND" "Checking for network and retrowait"

		if [ "$(GET_VAR "global" "settings/advanced/retrowait")" -eq 1 ]; then
			NET_START="/tmp/net_start"
			OIP=0

			while :; do
				NW_MSG=$(printf "Waiting for network to connect... (%s)\n\nPress START to continue loading\nPress SELECT to go to main menu" "$OIP")
				/opt/muos/extra/muxstart 0 "$NW_MSG"
				OIP=$((OIP + 1))

				if [ "$(cat "$(GET_VAR "device" "network/state")")" = "up" ]; then
					LOG_SUCCESS "$0" 0 "FRONTEND" "Network connected"
					/opt/muos/extra/muxstart 0 "Network connected"

					PIP=0
					while ! ping -c 1 -W 5 8.8.8.8 >/dev/null 2>&1; do
						PIP=$((PIP + 1))
						LOG_INFO "$0" 0 "FRONTEND" "Verifying connectivity..."
						/opt/muos/extra/muxstart 0 "Verifying connectivity... (%s)" "$PIP"
						/opt/muos/bin/toybox sleep 1
					done

					LOG_SUCCESS "$0" 0 "FRONTEND" "Connectivity verified! Booting content!"
					/opt/muos/extra/muxstart 0 "Connectivity verified! Booting content!"

					GO_LAST_BOOT=1
					break
				fi

				if [ "$(cat "$NET_START")" = "ignore" ]; then
					LOG_SUCCESS "$0" 0 "FRONTEND" "Ignoring network connection"
					/opt/muos/extra/muxstart 0 "Ignoring network connection... Booting content!"

					GO_LAST_BOOT=1
					break
				fi

				if [ "$(cat "$NET_START")" = "menu" ]; then
					LOG_SUCCESS "$0" 0 "FRONTEND" "Booting to main menu"
					/opt/muos/extra/muxstart 0 "Booting to main menu!"

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
				printf "%s" "$(cat "$CONTENT_GOV")" >$GVR_GO
			else
				CONTENT_GOV="$(dirname "$LAST_PLAY")/core.gov"
				if [ -e "$CONTENT_GOV" ]; then
					printf "%s" "$(cat "$CONTENT_GOV")" >$GVR_GO
				else
					LOG_INFO "$0" 0 "FRONTEND" "No governor found for launched content"
				fi
			fi

			/opt/muos/script/mux/launch.sh last
		fi
	fi

	echo launcher >$ACT_GO
fi

LOG_INFO "$0" 0 "FRONTEND" "Starting frontend launcher"

cp /opt/muos/log/*.log "$(GET_VAR "device" "storage/rom/mount")/MUOS/log/boot/." &

while :; do
	CHECK_BGM ignore &
	pkill -9 -f "gptokeyb" &

	# Reset DPAD<>ANALOGUE switch for H700 devices
	[ "$DEVICE_BOARD" = "rg*" ] && echo 0 >"/sys/class/power_supply/axp2202-battery/nds_pwrkey"

	# Content Loader
	[ -s "$ROM_GO" ] && /opt/muos/script/mux/launch.sh

	[ -s "$ACT_GO" ] && {
		IFS= read -r ACTION <"$ACT_GO"

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
					STOP_BGM
					"$(GET_VAR "device" "storage/rom/mount")/MUOS/application/${RUN_APP}/mux_launch.sh"
					echo appmenu >$ACT_GO
				fi
				;;

			"appmenu")  EXEC_MUX "app" "muxfrontend" ;;

			"collection")  EXEC_MUX "collection" "muxfrontend" ;;

			"history") EXEC_MUX "history" "muxfrontend" ;;

			"info") EXEC_MUX "info" "muxfrontend" ;;

			"credits")
				STOP_BGM
				/opt/muos/bin/nosefart /opt/muos/share/media/support.nsf &
				EXEC_MUX "info" "muxcredits"
				pkill -9 -f "nosefart" &
				START_BGM
				;;

			"reboot") /opt/muos/script/mux/quit.sh reboot frontend ;;
			"shutdown") /opt/muos/script/mux/quit.sh poweroff frontend ;;

			*) 
				printf "Unknown Module: %s\n" "$ACTION" >&2 
				printf '%s\n' "$DEF_ACT" >$ACT_GO
				;;
		esac
	}

done
