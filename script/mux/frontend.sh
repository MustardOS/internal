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
					break
				fi
				if [ "$(cat "$NET_START")" = "ignore" ]; then
					LOG_SUCCESS "$0" 0 "FRONTEND" "Ignoring network connection"
					/opt/muos/extra/muxstart 0 "Ignoring network connection... Booting content!"
					break
				fi
				if [ "$(cat "$NET_START")" = "menu" ]; then
					LOG_SUCCESS "$0" 0 "FRONTEND" "Booting to main menu"
					/opt/muos/extra/muxstart 0 "Booting to main menu!"
					break
				fi
				sleep 1
			done
		fi
		if [ "$(cat "$(GET_VAR "device" "network/state")")" = "up" ] || [ "$(cat "$NET_START")" = "ignore" ] || [ "$(GET_VAR "global" "network/enabled")" -eq 0 ] || [ "$(GET_VAR "global" "settings/advanced/retrowait")" -eq 0 ]; then
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

EXEC_MUX() {
	MUX_PROCESS="$1"
	shift
	SET_VAR "system" "foreground_process" "$MUX_PROCESS"
	nice --20 "/opt/muos/extra/$MUX_PROCESS" "$@"
}

PARSE_ACTION() {
	GOBACK="$1"
	MODULE="$2"

	[ -n "$GOBACK" ] && echo "$GOBACK" >"$ACT_GO"
	EXEC_MUX "$MODULE"
}

PROCESS_CONTENT_ACTION() {
	ACTION="$1"
	MODULE="$2"

	if [ -s "$ACTION" ]; then
		{
			IFS= read -r ROM_NAME
			IFS= read -r ROM_DIR
			IFS= read -r ROM_SYS
			IFS= read -r FORCED_FLAG
		} <"$ACTION"

		rm "$ACTION"
		echo "$MODULE" >"$ACT_GO"

		[ "$FORCED_FLAG" -eq 1 ] && echo "option" >"$ACT_GO"
	fi
}

while :; do
	CHECK_BGM ignore

	# Reset DPAD<>ANALOGUE switch for H700 devices
	case "$(GET_VAR "device" "board/name")" in
		rg*) echo 0 >"/sys/class/power_supply/axp2202-battery/nds_pwrkey" ;;
		*) ;;
	esac

	# Process Content Association
	PROCESS_CONTENT_ACTION "$ASS_GO" "assign"

	# Process Content Governor
	PROCESS_CONTENT_ACTION "$GOV_GO" "governor"

	# Content Loader
	[ -s "$ROM_GO" ] && /opt/muos/script/mux/launch.sh list

	# Application Loader
	if [ -s "$APP_GO" ]; then
		IFS= read -r RUN_APP <"$APP_GO"
		case "$RUN_APP" in
			*"Archive Manager"* | *"Task Toolkit"*) ;;
			*) STOP_BGM ;;
		esac
		"$RUN_APP"
		rm "$APP_GO"
		CHECK_BGM ignore
		continue
	fi

	# Get Last Content Index
	LAST_INDEX=0
	if [ -s "$ACT_GO" ]; then
		IFS= read -r ACTION <"$ACT_GO"
		case "$ACTION" in
			"explore" | "collection" | "history")
				if [ -s "$IDX_GO" ] && [ ! -s "$CL_AMW" ]; then
					IFS= read -r LAST_INDEX <"$IDX_GO"
					rm "$IDX_GO"
				fi
				;;
		esac
	fi

	# Kill PortMaster GPTOKEYB just in case!
	killall -q gptokeyb.armhf gptokeyb.aarch64 &

	if [ -s "$ACT_GO" ]; then
		IFS= read -r ACTION <"$ACT_GO"

		case "$ACTION" in
			"launcher")
				touch /tmp/pdi_go

				echo launcher >"$ACT_GO"
				[ -s "$MUX_AUTH" ] && rm "$MUX_AUTH"

				EXEC_MUX "muxlaunch"
				;;

			"option")
				echo explore >"$ACT_GO"
				EXEC_MUX "muxoption" -c "$ROM_NAME" -d "$ROM_DIR" -s "$ROM_SYS"
				;;

			"search")
				[ -s "$EX_DIR" ] && IFS= read -r EX_DIR_CONTENT <"$EX_DIR"
				echo option >"$ACT_GO"

				EXEC_MUX "muxsearch" -d "$EX_DIR_CONTENT"

				if [ -s "$RES_GO" ]; then
					IFS= read -r RES_CONTENT <"$RES_GO"
					basename "$RES_CONTENT" >"$EX_NAME"
					dirname "$RES_CONTENT" >"$EX_DIR"
					printf "%s" "$(echo "$RES_CONTENT" | sed 's|.*/\([^/]*\)/ROMS.*|\1|')" >"$EX_CARD"
					EXEC_MUX "muxplore" -i 0 -m "$(cat "$EX_CARD")"
				fi
				;;

			"assign")
				echo option >"$ACT_GO"
				EXEC_MUX "muxassign" -a 0 -c "$ROM_NAME" -d "$ROM_DIR" -s "$ROM_SYS"
				;;

			"governor")
				echo option >"$ACT_GO"
				EXEC_MUX "muxgov" -a 0 -c "$ROM_NAME" -d "$ROM_DIR" -s "$ROM_SYS"
				;;

			"app")
				echo launcher >"$ACT_GO"
				if [ "$(GET_VAR "global" "settings/advanced/lock")" -eq 1 ]; then
					EXEC_MUX "muxpass" -t launch
					[ "$?" -eq 1 ] && EXEC_MUX "muxapp"
				else
					EXEC_MUX "muxapp"
				fi
				;;

			"config")
				echo launcher >"$ACT_GO"
				if [ "$(GET_VAR "global" "settings/advanced/lock")" -eq 1 ]; then
					if [ -e "$MUX_AUTH" ]; then
						EXEC_MUX "muxconfig"
					else
						EXEC_MUX "muxpass" -t setting
						if [ "$?" -eq 1 ]; then
							EXEC_MUX "muxconfig"
							touch "$MUX_AUTH"
						fi
					fi
				else
					EXEC_MUX "muxconfig"
				fi
				;;

			"hdmi")
				echo tweakgen >"$ACT_GO"
				EXEC_MUX "muxhdmi"

				while [ ! -f "/tmp/hdmi_init_done" ]; do sleep 0.25; done
				rm -f "/tmp/hdmi_init_done"
				;;

			"picker")
				[ -s "$PIK_GO" ] && IFS= read -r PIK_CONTENT <"$PIK_GO"
				echo custom >"$ACT_GO"

				EXEC_MUX "muxpicker" -m "$PIK_CONTENT"
				;;

			"explore")
				[ -s "$EX_DIR" ] && IFS= read -r EXPLORE_DIR <"$EX_DIR"
				echo launcher >"$ACT_GO"

				EXEC_MUX "muxassign" -a 1 -c "$ROM_NAME" -d "$EXPLORE_DIR" -s none
				EXEC_MUX "muxgov" -a 1 -c "$ROM_NAME" -d "$EXPLORE_DIR" -s none
				EXEC_MUX "muxplore" -d "$EXPLORE_DIR" -i "$LAST_INDEX"
				;;

			"collection")
				ADD_MODE=0
				if [ -s "$CL_AMW" ]; then
					ADD_MODE=1
					LAST_INDEX=0
				fi

				[ -s "$CL_DIR" ] && IFS= read -r COLLECTION_DIR <"$CL_DIR"
				echo launcher >"$ACT_GO"

				find "/run/muos/storage/info/collection" -maxdepth 2 -type f -size 0 -delete
				EXEC_MUX "muxcollect" -a "$ADD_MODE" -d "$COLLECTION_DIR" -i "$LAST_INDEX"
				;;

			"history")
				find "/run/muos/storage/info/history" -maxdepth 1 -type f -size 0 -delete
				echo launcher >"$ACT_GO"
				EXEC_MUX "muxhistory" -i "$LAST_INDEX"
				;;

			"info")			PARSE_ACTION	"launcher"	"muxinfo"		;;
			"tweakgen")		PARSE_ACTION	"config"	"muxtweakgen"	;;
			"custom")		PARSE_ACTION	"config"	"muxcustom"		;;
			"network")		PARSE_ACTION	"config"	"muxnetwork"	;;
			"language")		PARSE_ACTION	"config"	"muxlanguage"	;;
			"webserv")		PARSE_ACTION	"config"	"muxwebserv"	;;
			"rtc")			PARSE_ACTION	"config"	"muxrtc"		;;
			"storage")		PARSE_ACTION	"config"	"muxstorage"	;;
			"power")		PARSE_ACTION	"tweakgen"	"muxpower"		;;
			"tweakadv")		PARSE_ACTION	"tweakgen"	"muxtweakadv"	;;
			"visual")		PARSE_ACTION	"tweakgen"	"muxvisual"		;;
			"net_profile")	PARSE_ACTION	"network"	"muxnetprofile"	;;
			"net_scan")		PARSE_ACTION	"network"	"muxnetscan"	;;
			"timezone")		PARSE_ACTION	"rtc"		"muxtimezone"	;;
			"system")		PARSE_ACTION	"info"		"muxsysinfo"	;;
			"credits")		PARSE_ACTION	"info"		"muxcredits"	;;

			"reboot")	/opt/muos/script/mux/quit.sh reboot   frontend ;;
			"shutdown")	/opt/muos/script/mux/quit.sh poweroff frontend ;;

			*) printf "Unknown Module: %s\n" "$ACTION" >&2 ;;
		esac
	fi
done
