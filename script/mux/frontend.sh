#!/bin/sh

case ":$LD_LIBRARY_PATH:" in
	*":/opt/muos/extra/lib:"*) ;;
	*) export LD_LIBRARY_PATH="/opt/muos/extra/lib:$LD_LIBRARY_PATH" ;;
esac

. /opt/muos/script/var/func.sh

if [ "$(GET_VAR device led/rgb)" -eq 1 ]; then
	RGBCONF_SCRIPT="/run/muos/storage/theme/active/rgb/rgbconf.sh"
	if [ -f "$RGBCONF_SCRIPT" ]; then
		"$RGBCONF_SCRIPT"
	else
		/opt/muos/device/current/script/led_control.sh 1 0 0 0 0 0 0 0
	fi
fi

/opt/muos/device/current/input/combo/audio.sh I
/opt/muos/device/current/input/combo/bright.sh I

DEVICE_BOARD="$(GET_VAR "device" "board/name")"

ACT_GO=/tmp/act_go
APP_GO=/tmp/app_go
ASS_GO=/tmp/ass_go
GOV_GO=/tmp/gov_go
GVR_GO=/tmp/gvr_go
IDX_GO=/tmp/idx_go
PIK_GO=/tmp/pik_go
ROM_GO=/tmp/rom_go
RES_GO=/tmp/res_go

EX_CARD=/tmp/explore_card
EX_NAME=/tmp/explore_name
EX_DIR=/tmp/explore_dir

CL_DIR=/tmp/collection_dir
CL_AMW=/tmp/add_mode_work

MUX_AUTH=/tmp/mux_auth

DEF_ACT=$(GET_VAR "global" "settings/general/startup")
printf '%s\n' "$DEF_ACT" >$ACT_GO
if [ "$DEF_ACT" = "explore" ]; then printf '%s\n' "explore_alt" >$ACT_GO; fi

echo "root" >$EX_CARD

if [ "$(GET_VAR "global" "settings/advanced/random_theme")" -eq 1 ]; then
	LOG_INFO "$0" 0 "FRONTEND" "Changing to a random theme"
	/opt/muos/script/package/theme.sh install "?R"
fi

LAST_PLAY=$(cat "/opt/muos/config/lastplay.txt")
LAST_INDEX=0

LOG_INFO "$0" 0 "FRONTEND" "Setting default CPU governor"
DEF_GOV=$(GET_VAR "device" "cpu/default")
printf '%s\n' "$DEF_GOV" >/sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
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

		if [ "$(GET_VAR "global" "network/enabled")" -eq 1 ] && [ "$(GET_VAR "global" "settings/advanced/retrowait")" -eq 1 ]; then
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
						sleep 1
					done

					LOG_SUCCESS "$0" 0 "FRONTEND" "Connectivity verified!"
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

				sleep 1
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
cp /opt/muos/*.log "$(GET_VAR "device" "storage/rom/mount")/MUOS/log/boot/." &

PROCESS_CONTENT_ACTION() {
	ACTION="$1"
	MODULE="$2"

	[ ! -s "$ACTION" ] && return

	{
		IFS= read -r ROM_NAME
		IFS= read -r ROM_DIR
		IFS= read -r ROM_SYS
		IFS= read -r FORCED_FLAG
	} <"$ACTION"

	rm "$ACTION"
	echo "$MODULE" >"$ACT_GO"

	[ "$FORCED_FLAG" -eq 1 ] && echo "option" >"$ACT_GO"
}

LAST_INDEX_CHECK() {
	LAST_INDEX=0
	if [ -s "$IDX_GO" ] && [ ! -s "$CL_AMW" ]; then
		read -r LAST_INDEX <"$IDX_GO"
		LAST_INDEX=${LAST_INDEX:-0}
		rm -f "$IDX_GO"
	fi
}

while :; do
	CHECK_BGM ignore &
	pkill -9 -f "gptokeyb" &

	# Reset DPAD<>ANALOGUE switch for H700 devices
	[ "$DEVICE_BOARD" = "rg*" ] && echo 0 >"/sys/class/power_supply/axp2202-battery/nds_pwrkey"

	# Process content association and governor actions
	PROCESS_CONTENT_ACTION "$ASS_GO" "assign"
	PROCESS_CONTENT_ACTION "$GOV_GO" "governor"

	# Content Loader
	[ -s "$ROM_GO" ] && /opt/muos/script/mux/launch.sh

	[ -s "$ACT_GO" ] && {
		IFS= read -r ACTION <"$ACT_GO"

		case "$ACTION" in
			"launcher")
				touch /tmp/pdi_go
				[ -s "$MUX_AUTH" ] && rm "$MUX_AUTH"
				EXEC_MUX "launcher" "muxlaunch"
				;;

			"option") EXEC_MUX "explore" "muxoption" -c "$ROM_NAME" -d "$ROM_DIR" -s "$ROM_SYS" ;;
			"assign") EXEC_MUX "option" "muxassign" -a 0 -c "$ROM_NAME" -d "$ROM_DIR" -s "$ROM_SYS" ;;
			"governor") EXEC_MUX "option" "muxgov" -a 0 -c "$ROM_NAME" -d "$ROM_DIR" -s "$ROM_SYS" ;;
			"search")
				[ -s "$EX_DIR" ] && IFS= read -r EX_DIR_CONTENT <"$EX_DIR"
				EXEC_MUX "option" "muxsearch" -d "$EX_DIR_CONTENT"
				if [ -s "$RES_GO" ]; then
					IFS= read -r RES_CONTENT <"$RES_GO"
					printf "%s" "${RES_CONTENT##*/}" >"$EX_NAME"
					printf "%s" "${RES_CONTENT%/*}" >"$EX_DIR"
					printf "%s" "$(echo "$RES_CONTENT" | sed 's|.*/\([^/]*\)/ROMS.*|\1|')" >"$EX_CARD"
					EXEC_MUX "option" "muxplore" -i 0 -d "$(cat "$EX_DIR")"
				fi
				;;

			"app")
				if [ "$(GET_VAR "global" "settings/advanced/lock")" -eq 1 ]; then
					EXEC_MUX "launcher" "muxpass" -t launch
					[ "$?" -eq 1 ] && EXEC_MUX "launcher" "muxapp"
				else
					EXEC_MUX "launcher" "muxapp"
					if [ -s "$APP_GO" ]; then
						IFS= read -r RUN_APP <"$APP_GO"
						rm "$APP_GO"
						case "$RUN_APP" in
							*"Archive Manager"*)
								echo archive >$ACT_GO
								;;
							*"Task Toolkit"*)
								echo task >$ACT_GO
								;;
							*)
								STOP_BGM
								"$RUN_APP"
								;;
						esac
					fi
				fi
				;;

			"config")
				if [ "$(GET_VAR "global" "settings/advanced/lock")" -eq 1 ]; then
					if [ -e "$MUX_AUTH" ]; then
						EXEC_MUX "launcher" "muxconfig"
					else
						EXEC_MUX "muxpass" -t setting
						if [ "$?" -eq 1 ]; then
							EXEC_MUX "launcher" "muxconfig"
							touch "$MUX_AUTH"
						fi
					fi
				else
					EXEC_MUX "launcher" "muxconfig"
				fi
				;;

			"hdmi")
				EXEC_MUX "tweakgen" "muxhdmi"
				if [ "$(GET_VAR "global" "settings/hdmi/enabled")" -eq 1 ]; then
					/opt/muos/device/current/script/hdmi.sh start
				else
					/opt/muos/device/current/script/hdmi.sh stop
				fi
				;;

			"picker")
				[ -s "$PIK_GO" ] && IFS= read -r PIK_CONTENT <"$PIK_GO"
				EXPLORE_DIR=""
				[ -s "$EX_DIR" ] && IFS= read -r EXPLORE_DIR <"$EX_DIR"
				EXEC_MUX "custom" "muxpicker" -m "$PIK_CONTENT" -d "$EXPLORE_DIR"
				;;

			"explore")
				LAST_INDEX_CHECK
				[ -s "$EX_DIR" ] && IFS= read -r EXPLORE_DIR <"$EX_DIR"
				EXEC_MUX "launcher" "muxassign" -a 1 -c "$ROM_NAME" -d "$EXPLORE_DIR" -s none
				EXEC_MUX "launcher" "muxgov" -a 1 -c "$ROM_NAME" -d "$EXPLORE_DIR" -s none
				EXEC_MUX "launcher" "muxplore" -d "$EXPLORE_DIR" -i "$LAST_INDEX"
				;;

			"collection")
				LAST_INDEX_CHECK
				ADD_MODE=0
				if [ -s "$CL_AMW" ]; then
					ADD_MODE=1
					LAST_INDEX=0
				fi
				[ -s "$CL_DIR" ] && IFS= read -r COLLECTION_DIR <"$CL_DIR"
				find "/run/muos/storage/info/collection" -maxdepth 2 -type f -size 0 -delete
				EXEC_MUX "launcher" "muxcollect" -a "$ADD_MODE" -d "$COLLECTION_DIR" -i "$LAST_INDEX"
				;;

			"history")
				LAST_INDEX_CHECK
				find "/run/muos/storage/info/history" -maxdepth 1 -type f -size 0 -delete
				EXEC_MUX "launcher" "muxhistory" -i "$LAST_INDEX"
				;;

			"credits")
				/opt/muos/bin/nosefart /opt/muos/media/support.nsf &
				EXEC_MUX "info" "muxcredits"
				pkill -9 -f "nosefart" &
				;;

			"info") EXEC_MUX "launcher" "muxinfo" ;;
			"archive") EXEC_MUX "app" "muxarchive" ;;
			"task") EXEC_MUX "app" "muxtask" ;;
			"tweakgen") EXEC_MUX "config" "muxtweakgen" ;;
			"custom") EXEC_MUX "config" "muxcustom" ;;
			"network") EXEC_MUX "config" "muxnetwork" ;;
			"language") EXEC_MUX "config" "muxlanguage" ;;
			"webserv") EXEC_MUX "config" "muxwebserv" ;;
			"rtc") EXEC_MUX "config" "muxrtc" ;;
			"storage") EXEC_MUX "config" "muxstorage" ;;
			"power") EXEC_MUX "tweakgen" "muxpower" ;;
			"tweakadv") EXEC_MUX "tweakgen" "muxtweakadv" ;;
			"visual") EXEC_MUX "tweakgen" "muxvisual" ;;
			"net_profile") EXEC_MUX "network" "muxnetprofile" ;;
			"net_scan") EXEC_MUX "network" "muxnetscan" ;;
			"timezone") EXEC_MUX "rtc" "muxtimezone" ;;
			"tester") EXEC_MUX "info" "muxtester" ;;
			"system") EXEC_MUX "info" "muxsysinfo" ;;

			"reboot") /opt/muos/script/mux/quit.sh reboot frontend ;;
			"shutdown") /opt/muos/script/mux/quit.sh poweroff frontend ;;

			*) printf "Unknown Module: %s\n" "$ACTION" >&2 ;;
		esac
	}

done
