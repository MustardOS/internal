#!/bin/sh

. /opt/muos/script/var/func.sh

ROM_MOUNT=$(GET_VAR "device" "storage/rom/mount")
BOARD_NAME=$(GET_VAR "device" "board/name")
DPAD_SWAP=$(GET_VAR "device" "board/swap")

STARTUP=$(GET_VAR "config" "settings/general/startup")
AUDIO_READY=$(GET_VAR "config" "settings/advanced/audio_ready")
BOARD_STICK=$(GET_VAR "device" "board/stick")

AUDIO_WAIT_MAX=100

RUN_CONTENT_LOADER() {
	[ -s "$ROM_GO" ] || return 0

	LOG_INFO "$0" 0 "FRONTEND" "Content loader triggered"
	/opt/muos/script/mux/launch.sh

	ENSURE_REMOVED_SYNC "$ROM_GO"

	[ -s "$ACT_GO" ] || SAFE_WRITE "launcher" "$ACT_GO"
}

SKIP=0

if [ -n "$1" ]; then
	ACT="$1"
	SKIP=1
else
	ACT="$STARTUP"
fi

SAFE_WRITE "$ACT" "$ACT_GO"
SAFE_WRITE "root" "$EX_CARD"

LOG_INFO "$0" 0 "FRONTEND" "Setting default CPU governor"
SET_DEFAULT_GOVERNOR

if IS_ONE "$AUDIO_READY"; then
	WAIT_FOR_AUDIO_READY "$AUDIO_WAIT_MAX"
fi

LED_CONTROL_CHANGE restore

if [ "$SKIP" = "0" ]; then
	LOG_INFO "$0" 0 "FRONTEND" "Checking for last/resume startup"
	case "$STARTUP" in
		last | resume) /opt/muos/script/mux/resume.sh ;;
	esac
fi

if [ "$(GET_DEBUG)" -gt 0 ]; then
	BL_PATH="$ROM_MOUNT/MUOS/log/boot"
	mkdir -p "$BL_PATH"
	cp "$MUOS_LOG_DIR"/*.log "$BL_PATH"/. 2>/dev/null
fi

LOG_INFO "$0" 0 "FRONTEND" "Starting Frontend Launcher"
SHOW_SPLASH clear

while :; do
	# Unset SDL controller env vars exported by SETUP_APP so muX modules start fresh
	unset SDL_GAMECONTROLLERCONFIG_FILE SDL_GAMECONTROLLERCONFIG

	# Reset audio control status
	LOG_INFO "$0" 0 "FRONTEND" "Audio Mixer Reset"
	RESET_MIXER

	killall -9 "gptokeyb" "gptokeyb2" >/dev/null 2>&1

	# Reset ANALOGUE<>DIGITAL switch for the DPAD
	RESET_DPAD_MODE "$BOARD_STICK" "$BOARD_NAME" "$DPAD_SWAP"
	RUN_CONTENT_LOADER

	[ -s "$ACT_GO" ] || {
		sleep 0.1
		continue
	}

	IFS= read -r ACTION <"$ACT_GO"
	[ -n "$ACTION" ] || ACTION="launcher"

	LOG_INFO "$0" 0 "FRONTEND" "Loading '$ACTION' action"

	case "$ACTION" in
		launcher)
			LOG_INFO "$0" 0 "FRONTEND" "Clearing content and auto-assign flags"
			RESET_LAUNCHER_FLAGS

			LOG_INFO "$0" 0 "FRONTEND" "Resetting governor to default"
			SET_DEFAULT_GOVERNOR

			touch "/tmp/pdi_go"
			EXEC_MUX "launcher" "muxfrontend"
			;;

		explore)
			EXEC_MUX "explore" "muxfrontend"
			;;

		app)
			if [ -s "$APP_GO" ]; then
				IFS= read -r RUN_APP <"$APP_GO"
				ENSURE_REMOVED_SYNC "$APP_GO"

				if [ -n "$RUN_APP" ] && [ -x "$RUN_APP/mux_launch.sh" ]; then
					SETUP_APP
					"$RUN_APP"/mux_launch.sh "$RUN_APP"
					CONTENT_UNSET
				else
					LOG_WARN "$0" 0 "FRONTEND" "Invalid app launcher: $RUN_APP"
					CONTENT_UNSET
				fi

				LOG_INFO "$0" 0 "FRONTEND" "Clearing governor and control flags"
				RESET_APP_FLAGS

				LOG_INFO "$0" 0 "FRONTEND" "Resetting governor to default"
				SET_DEFAULT_GOVERNOR

				SAFE_WRITE "appmenu" "$ACT_GO"
			else
				LOG_WARN "$0" 0 "FRONTEND" "app action fired with no APP_GO; falling back to appmenu"
				SAFE_WRITE "appmenu" "$ACT_GO"
			fi
			;;

		appmenu)
			LOG_INFO "$0" 0 "FRONTEND" "Clearing governor and control flags"
			RESET_APP_FLAGS

			LOG_INFO "$0" 0 "FRONTEND" "Resetting governor to default"
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
			LOG_WARN "$0" 0 "FRONTEND" "Unknown action: $ACTION"
			printf 'Unknown module: %s\n' "$ACTION" >&2
			EXEC_MUX "$ACTION" "muxfrontend"
			;;
	esac
done
