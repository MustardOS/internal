#!/bin/sh

. /opt/muos/script/var/func.sh

ROM_MOUNT=$(GET_VAR "device" "storage/rom/mount")
BOARD_NAME=$(GET_VAR "device" "board/name")
DPAD_SWAP=$(GET_VAR "device" "board/swap")

STARTUP=$(GET_VAR "config" "settings/general/startup")
AUDIO_READY=$(GET_VAR "config" "settings/advanced/audio_ready")
BOARD_STICK=$(GET_VAR "device" "board/stick")

ACT_GO="/tmp/act_go"
APP_GO="/tmp/app_go"
GOV_GO="/tmp/gov_go"
CON_GO="/tmp/con_go"
FLT_GO="/tmp/flt_go"
RAC_GO="/tmp/rac_go"
ROM_GO="/tmp/rom_go"
SAA_GO="/tmp/saa_go"
SAG_GO="/tmp/sag_go"
SAR_GO="/tmp/sar_go"
SHD_GO="/tmp/shd_go"

EX_CARD="/tmp/explore_card"

SKIP=0

if [ -n "$1" ]; then
	ACT="$1"
	SKIP=1
else
	ACT="$STARTUP"
fi

printf '%s\n' "$ACT" >"$ACT_GO"
printf "root\n" >"$EX_CARD"

LOG_INFO "$0" 0 "FRONTEND" "Setting default CPU governor"
SET_DEFAULT_GOVERNOR

if [ "$AUDIO_READY" -eq 1 ]; then
	LOG_INFO "$0" 0 "BOOTING" "Waiting for PipeWire Initialisation"
	until [ "$(GET_VAR "device" "audio/ready")" -eq 1 ]; do sleep 0.1; done
fi

LOG_INFO "$0" 0 "BOOTING" "Restoring Saved Volume"
RESTORE_AUDIO_VOLUME || LOG_WARN "$0" 0 "BOOTING" "Unable to restore saved volume"

LED_CONTROL_CHANGE restore

if [ "$SKIP" -eq 0 ]; then
	LOG_INFO "$0" 0 "FRONTEND" "Checking for last or resume startup"

	case "$STARTUP" in
		last | resume) /opt/muos/script/mux/resume.sh ;;
	esac
fi

if [ "$DEBUG_MODE" -eq 1 ]; then
	BL_PATH="$ROM_MOUNT/MUOS/log/boot"
	mkdir -p "$BL_PATH"
	cp "$MUOS_LOG_DIR"/*.log "$BL_PATH"/.
fi

LOG_INFO "$0" 0 "FRONTEND" "Starting Frontend Launcher"
SHOW_SPLASH clear

while :; do
	# Reset audio control status
	LOG_INFO "$0" 0 "FRONTEND" "Audio Mixer Reset"
	RESET_MIXER

	killall -9 "gptokeyb" "gptokeyb2" >/dev/null 2>&1

	# Reset ANALOGUE<>DIGITAL switch for the DPAD
	if [ "$BOARD_STICK" -eq 0 ]; then
		case "$BOARD_NAME" in
			rg*) printf "0" >"$DPAD_SWAP" ;;
			tui*) ENSURE_REMOVED "$DPAD_SWAP" ;;
		esac
	fi

	# Content Loader
	LOG_INFO "$0" 0 "FRONTEND" "Checking for Content Loader"
	[ -s "$ROM_GO" ] && /opt/muos/script/mux/launch.sh

	[ -s "$ACT_GO" ] || continue

	IFS= read -r ACTION <"$ACT_GO"

	LOG_INFO "$0" 0 "FRONTEND" "$(printf "Loading '%s' Action" "$ACTION")"

	case "$ACTION" in
		launcher)
			LOG_INFO "$0" 0 "FRONTEND" "Clearing Content Setting files"
			ENSURE_REMOVED "$GOV_GO"
			ENSURE_REMOVED "$CON_GO"
			ENSURE_REMOVED "$FLT_GO"
			ENSURE_REMOVED "$SHD_GO"
			ENSURE_REMOVED "$RAC_GO"

			LOG_INFO "$0" 0 "FRONTEND" "Clearing Auto Assign flags"
			ENSURE_REMOVED "$SAA_GO"
			ENSURE_REMOVED "$SAG_GO"
			ENSURE_REMOVED "$SAR_GO"

			LOG_INFO "$0" 0 "FRONTEND" "Setting Governor back to default"
			SET_DEFAULT_GOVERNOR

			touch "/tmp/pdi_go"

			EXEC_MUX "launcher" "muxfrontend"
			;;

		explore) EXEC_MUX "explore" "muxfrontend" ;;

		app)
			if [ -s "$APP_GO" ]; then
				IFS= read -r RUN_APP <"$APP_GO"
				ENSURE_REMOVED "$APP_GO"

				SETUP_APP
				"$RUN_APP"/mux_launch.sh "$RUN_APP"

				CONTENT_UNSET
				printf "appmenu\n" >"$ACT_GO"

				LOG_INFO "$0" 0 "FRONTEND" "Clearing Governor and Control Scheme files"
				ENSURE_REMOVED "$GOV_GO"
				ENSURE_REMOVED "$CON_GO"

				LOG_INFO "$0" 0 "FRONTEND" "Setting Governor back to default"
				SET_DEFAULT_GOVERNOR
			fi
			;;

		appmenu)
			LOG_INFO "$0" 0 "FRONTEND" "Clearing Governor and Control Scheme files"
			ENSURE_REMOVED "$GOV_GO"
			ENSURE_REMOVED "$CON_GO"

			LOG_INFO "$0" 0 "FRONTEND" "Setting Governor back to default"
			SET_DEFAULT_GOVERNOR

			EXEC_MUX "app" "muxfrontend"
			;;

		collection) EXEC_MUX "collection" "muxfrontend" ;;
		history) EXEC_MUX "history" "muxfrontend" ;;
		info) EXEC_MUX "info" "muxfrontend" ;;

		credits) /opt/muos/frontend/mucredits ;;
		reboot) /opt/muos/script/mux/quit.sh reboot frontend ;;
		shutdown) /opt/muos/script/mux/quit.sh poweroff frontend ;;

		*)
			printf "Unknown Module: %s\n" "$ACTION" >&2
			EXEC_MUX "$ACTION" "muxfrontend"
			;;
	esac
done
