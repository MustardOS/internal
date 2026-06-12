#!/bin/sh

. /opt/muos/script/var/func.sh

LOG_INFO "$0" 0 "LAUNCH" "$(printf "Content launch script started (PID: %s)" "$$")"

ROM_MOUNT=$(GET_VAR "device" "storage/rom/mount")
BOARD_NAME=$(GET_VAR "device" "board/name")
LED_NORMAL=$(GET_VAR "device" "led/normal")
GOVERNOR=$(GET_VAR "device" "cpu/governor")
RUMBLE_PATH=$(GET_VAR "device" "board/rumble")
NET_STATE=$(GET_VAR "device" "network/state")
DPAD_SWAP=$(GET_VAR "device" "board/swap")
USE_ACTIVITY=$(GET_VAR "config" "settings/advanced/activity")
USE_LEDS=$(GET_VAR "config" "settings/advanced/led")
DEV_MODE=$(GET_VAR "config" "boot/device_mode")
USE_SYNCTHING=$(GET_VAR "config" "web/syncthing")
SYNCTHING_AUTOSCAN=$(GET_VAR "config" "syncthing/auto_scan")
SCREEN_INT_W=$(GET_VAR "device" "screen/internal/width")
SCREEN_INT_H=$(GET_VAR "device" "screen/internal/height")
SCREEN_EXT_W=$(GET_VAR "device" "screen/external/width")
SCREEN_EXT_H=$(GET_VAR "device" "screen/external/height")
LED_STATE="$MUOS_RUN_DIR/work_led_state"

RUN_DISCORD_PRESENCE() {
	DISCORD_MODE=$1
	DISCORD_DIR="$ROM_MOUNT/MUOS/discord"
	PC_IP_FILE="$DISCORD_DIR/pc_ip.txt"

	[ -s "$PC_IP_FILE" ] || return 0

	PC_ADDR=$(READ_FIRST_LINE "$PC_IP_FILE")
	[ -n "$PC_ADDR" ] || return 0

	case "$DISCORD_MODE" in
		start)
			LOG_INFO "$0" 0 "LAUNCH" "$(printf "Sending Discord presence (start) to %s for '%s'" "$PC_ADDR" "$NAME")"
			python "$DISCORD_DIR/discord_presence_handheld.py" "$PC_ADDR" "On my $BOARD_NAME with MustardOS!" "Playing $NAME"
			;;
		clear)
			LOG_INFO "$0" 0 "LAUNCH" "$(printf "Clearing Discord presence on %s" "$PC_ADDR")"
			python "$DISCORD_DIR/discord_presence_handheld.py" "$PC_ADDR" --clear
			;;
	esac
}

CLEANUP_AFTER_LAUNCH() {
	REMOVE_RUNTIME_FILES

	LOG_DEBUG "$0" 0 "LAUNCH" "Unsetting content environment variables"
	CONTENT_UNSET

	LOG_DEBUG "$0" 0 "LAUNCH" "$(printf "Disabling rumble via '%s'" "$RUMBLE_PATH")"
	RUMBLE "$RUMBLE_PATH" "0.0"

	LOG_DEBUG "$0" 0 "LAUNCH" "Triggering filesystem sync"
	sync &

	LOG_DEBUG "$0" 0 "LAUNCH" "Restoring default CPU governor"
	SET_DEFAULT_GOVERNOR

	LOG_DEBUG "$0" 0 "LAUNCH" "Killing any leftover gptokeyb processes"
	killall -9 "gptokeyb" "gptokeyb2" >/dev/null 2>&1

	RESTORE_DPAD_AND_LEDS "$BOARD_NAME" "$DPAD_SWAP" "$LED_NORMAL" "$LED_STATE"
	RESTORE_FRAMEBUFFER_MODE "$DEV_MODE" "$SCREEN_INT_W" "$SCREEN_INT_H" "$SCREEN_EXT_W" "$SCREEN_EXT_H"
	RUN_SYNCTHING_SCAN "$USE_SYNCTHING" "$SYNCTHING_AUTOSCAN" "$NET_STATE"
	RUN_DISCORD_PRESENCE clear
}

if [ ! -s "$ROM_GO" ]; then
	LOG_WARN "$0" 0 "LAUNCH" "No ROM_GO launch request found"
	REMOVE_RUNTIME_FILES
	exit 0
fi

{
	read -r NAME
	read -r CORE
	read -r ASSIGN
	read -r _
	read -r _
	read -r LAUNCH
	read -r R_DIR1
	read -r R_DIR2
	read -r ROM_NAME
} <"$ROM_GO"

R_DIR="$R_DIR1$R_DIR2"
ROM="$R_DIR/$ROM_NAME"

if [ -z "$NAME" ] || [ -z "$CORE" ] || [ -z "$ASSIGN" ] || [ -z "$LAUNCH" ] || [ -z "$ROM_NAME" ]; then
	LOG_ERROR "$0" 0 "LAUNCH" "Invalid ROM_GO launch request"
	ENSURE_REMOVED_SYNC "$ROM_GO"
	REMOVE_RUNTIME_FILES
	exit 1
fi

LOG_DEBUG "$0" 0 "LAUNCH" "Parsed ROM_GO file:"
LOG_DEBUG "$0" 0 "LAUNCH" "$(printf "\tNAME = '%s'" "$NAME")"
LOG_DEBUG "$0" 0 "LAUNCH" "$(printf "\tCORE = '%s'" "$CORE")"
LOG_DEBUG "$0" 0 "LAUNCH" "$(printf "\tASSIGN = '%s'" "$ASSIGN")"
LOG_DEBUG "$0" 0 "LAUNCH" "$(printf "\tLAUNCH = '%s'" "$LAUNCH")"
LOG_DEBUG "$0" 0 "LAUNCH" "$(printf "\tR_DIR = '%s'" "$R_DIR")"
LOG_DEBUG "$0" 0 "LAUNCH" "$(printf "\tROM_NAME = '%s'" "$ROM_NAME")"
LOG_DEBUG "$0" 0 "LAUNCH" "$(printf "\tROM = '%s'" "$ROM")"

printf "%s\n%s\n%s" "$NAME" "$ASSIGN" "$CORE" >"$OVL_GO"
[ -e "$OVERLAY_NOP" ] && rm -f "$OVERLAY_NOP"

RUN_DISCORD_PRESENCE start

case "$BOARD_NAME" in
	rg*)
		LOG_DEBUG "$0" 0 "LAUNCH" "$(printf "Applying LED state '%s' to '%s' and '%s'" "$USE_LEDS" "$LED_NORMAL" "$LED_STATE")"
		printf "%s" "$USE_LEDS" >"$LED_NORMAL"
		printf "%s" "$USE_LEDS" >"$LED_STATE"
		;;
	*) ;;
esac

APPLY_OPTIONAL_FILE "$GOV_GO" "$GOVERNOR" "CPU Governor"

ENSURE_REMOVED_SYNC "$GOV_GO"
ENSURE_REMOVED_SYNC "$SAA_GO"
ENSURE_REMOVED_SYNC "$SAG_GO"
ENSURE_REMOVED_SYNC "$SAR_GO"

# Set the chosen colour filter of content to our stage overlay path.
APPLY_OPTIONAL_FILE "$FLT_GO" "$MUOS_RUN_DIR/overlay.filter" "Overlay Filter"

# Set the chosen shader of content.
APPLY_OPTIONAL_FILE "$SHD_GO" "$MUOS_RUN_DIR/overlay.shader" "Overlay Shader"

# Construct the path to the assigned launcher INI file based on device storage,
# assignment name ($ASSIGN), and launcher name ($LAUNCH).  This is created within
# the launching/assigning of the system and core.
ASSIGN_INI=$(printf '%s/info/assign/%s/%s.ini' "$MUOS_SHARE_DIR" "$ASSIGN" "$LAUNCH")
LOG_DEBUG "$0" 0 "LAUNCH" "$(printf "Resolved assign INI: '%s'" "$ASSIGN_INI")"

# Extract launcher stage commands from the INI file constructed above.
# These are either the internal launch scripts or custom scripts if it
# is a customised launch package if a user decides to create one...
LAUNCH_PREP=$(PARSE_INI "$ASSIGN_INI" "launch" "prep") # Optional preparation step before content run
[ -n "$LAUNCH_PREP" ] && LOG_DEBUG "$0" 0 "LAUNCH" "$(printf "Resolved launch prep: '%s'" "$LAUNCH_PREP")"

# Override launch script priority: ROM -> CORE -> DIR
OVERRIDE_ROOT="$MUOS_SHARE_DIR/info/override"

if [ -f "$OVERRIDE_ROOT/${NAME}.sh" ]; then
	LAUNCH_EXEC="$OVERRIDE_ROOT/${NAME}.sh"
	LOG_INFO "$0" 0 "LAUNCH" "$(printf "Using ROM override launcher: '%s'" "$LAUNCH_EXEC")"
elif [ -f "$OVERRIDE_ROOT/${LAUNCH}.sh" ]; then
	LAUNCH_EXEC="$OVERRIDE_ROOT/${LAUNCH}.sh"
	LOG_INFO "$0" 0 "LAUNCH" "$(printf "Using CORE override launcher: '%s'" "$LAUNCH_EXEC")"
elif [ -f "$OVERRIDE_ROOT/${R_DIR##*/}.sh" ]; then
	LAUNCH_EXEC="$OVERRIDE_ROOT/${R_DIR##*/}.sh"
	LOG_INFO "$0" 0 "LAUNCH" "$(printf "Using DIR override launcher: '%s'" "$LAUNCH_EXEC")"
else
	LAUNCH_EXEC=$(PARSE_INI "$ASSIGN_INI" "launch" "exec") # REQUIRED main launcher to run the content
	LOG_DEBUG "$0" 0 "LAUNCH" "$(printf "Using INI-defined launcher: '%s'" "$LAUNCH_EXEC")"
fi

ENSURE_REMOVED_SYNC "$ROM_GO"

LAUNCH_DONE=$(PARSE_INI "$ASSIGN_INI" "launch" "done") # Optional cleanup script after successful run
[ -n "$LAUNCH_DONE" ] && LOG_DEBUG "$0" 0 "LAUNCH" "$(printf "Resolved launch done: '%s'" "$LAUNCH_DONE")"

# Ensure the main launcher was provided, could probably provide some visual feedback
# on the frontend side of things but we'll deal with that later...
if [ -z "$LAUNCH_EXEC" ]; then
	LOG_ERROR "$0" 0 "LAUNCH" "$(printf "Missing launcher exec in '%s'" "$ASSIGN_INI")"
	printf 'Missing launcher exec in %s\n' "$ASSIGN_INI" >&2
else
	if [ -n "$LAUNCH_PREP" ]; then
		LOG_INFO "$0" 0 "LAUNCH" "$(printf "Running prep script '%s'" "$LAUNCH_PREP")"
		"$LAUNCH_PREP" "$NAME" "$CORE" "$ROM"
	fi

	if IS_ONE "$USE_ACTIVITY"; then
		LOG_INFO "$0" 0 "LAUNCH" "$(printf "Activity tracker start for '%s'" "$NAME")"
		/opt/muos/script/mux/track.sh "$NAME" "$CORE" "$ROM" start
	fi

	LOG_INFO "$0" 0 "LAUNCH" "$(printf "Executing launcher '%s' for '%s'" "$LAUNCH_EXEC" "$NAME")"
	"$LAUNCH_EXEC" "$NAME" "$CORE" "$ROM"
	LAUNCH_RC=$?

	if [ "$LAUNCH_RC" -eq 0 ]; then
		LOG_SUCCESS "$0" 0 "LAUNCH" "$(printf "Launcher exited successfully for '%s'" "$NAME")"
	else
		LOG_WARN "$0" 0 "LAUNCH" "$(printf "Launcher exited with code %s for '%s'" "$LAUNCH_RC" "$NAME")"
	fi

	if IS_ONE "$USE_ACTIVITY"; then
		LOG_INFO "$0" 0 "LAUNCH" "$(printf "Activity tracker stop for '%s'" "$NAME")"
		/opt/muos/script/mux/track.sh "$NAME" "$CORE" "$ROM" stop
	fi

	if [ -n "$LAUNCH_DONE" ]; then
		LOG_INFO "$0" 0 "LAUNCH" "$(printf "Running done script '%s'" "$LAUNCH_DONE")"
		"$LAUNCH_DONE" "$NAME" "$CORE" "$ROM"
	fi
fi

CLEANUP_AFTER_LAUNCH

LOG_INFO "$0" 0 "LAUNCH" "Content launch script complete"
