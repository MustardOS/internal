#!/bin/sh

. /opt/muos/script/var/func.sh

LOG_INFO "$0" 0 "LAUNCH" "$(printf "Content launch script started (PID: %s)" "$$")"

ROM_MOUNT="$(GET_VAR "device" "storage/rom/mount")"
BOARD_NAME="$(GET_VAR "device" "board/name")"
LED_NORMAL="$(GET_VAR "device" "led/normal")"
GOVERNOR="$(GET_VAR "device" "cpu/governor")"
RUMBLE="$(GET_VAR "device" "board/rumble")"
NET_STATE="$(GET_VAR "device" "network/state")"
DPAD_SWAP=$(GET_VAR "device" "board/swap")

USE_ACTIVITY="$(GET_VAR "config" "settings/advanced/activity")"
USE_LEDS="$(GET_VAR "config" "settings/advanced/led")"
DEV_MODE="$(GET_VAR "config" "boot/device_mode")"
USE_SYNCTHING="$(GET_VAR "config" "web/syncthing")"
SYNCTHING_AUTOSCAN="$(GET_VAR "config" "syncthing/auto_scan")"

SCREEN_INT_W="$(GET_VAR "device" "screen/internal/width")"
SCREEN_INT_H="$(GET_VAR "device" "screen/internal/height")"
SCREEN_EXT_W="$(GET_VAR "device" "screen/external/width")"
SCREEN_EXT_H="$(GET_VAR "device" "screen/external/height")"

LED_STATE="$MUOS_RUN_DIR/work_led_state"

OVL_GO="/tmp/ovl_go"
ROM_GO="/tmp/rom_go"
CON_GO="/tmp/con_go"
FLT_GO="/tmp/flt_go"
RAC_GO="/tmp/rac_go"
GOV_GO="/tmp/gov_go"
SAA_GO="/tmp/saa_go"
SAG_GO="/tmp/sag_go"
SAR_GO="/tmp/sar_go"
SHD_GO="/tmp/shd_go"

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

DISCORD_DIR="$ROM_MOUNT/MUOS/discord"
PC_IP="$DISCORD_DIR/pc_ip.txt"

if [ -s "$PC_IP" ]; then
	LOG_INFO "$0" 0 "LAUNCH" "$(printf "Sending Discord presence (start) to %s for '%s'" "$(cat "$PC_IP")" "$NAME")"
	python "$DISCORD_DIR/discord_presence_handheld.py" "$(cat "$PC_IP")" "On my $BOARD_NAME with MustardOS!" "Playing $NAME"
fi

case "$BOARD_NAME" in
	rg*)
		LOG_DEBUG "$0" 0 "LAUNCH" "$(printf "Applying LED state '%s' to '%s' and '%s'" "$USE_LEDS" "$LED_NORMAL" "$LED_STATE")"
		echo "$USE_LEDS" >"$LED_NORMAL"
		echo "$USE_LEDS" >"$LED_STATE"
		;;
	*) ;;
esac

LOG_DEBUG "$0" 0 "LAUNCH" "$(printf "Applying CPU governor from '%s' to '%s'" "$GOV_GO" "$GOVERNOR")"
cat "$GOV_GO" >"$GOVERNOR"
ENSURE_REMOVED "$GOV_GO"

ENSURE_REMOVED "$SAA_GO"
ENSURE_REMOVED "$SAG_GO"
ENSURE_REMOVED "$SAR_GO"

# Set the chosen colour filter of content to our stage overlay path.
cat "$FLT_GO" >"$MUOS_RUN_DIR/overlay.filter"

# Set the chosen shader of content.
cat "$SHD_GO" >"$MUOS_RUN_DIR/overlay.shader"

# Construct the path to the assigned launcher INI file based on device storage,
# assignment name ($ASSIGN), and launcher name ($LAUNCH).  This is created within
# the launching/assigning of the system and core.
ASSIGN_INI=$(printf "$MUOS_SHARE_DIR/info/assign/%s/%s.ini" "$ASSIGN" "$LAUNCH")
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

ENSURE_REMOVED "$ROM_GO"

LAUNCH_DONE=$(PARSE_INI "$ASSIGN_INI" "launch" "done") # Optional cleanup script after successful run
[ -n "$LAUNCH_DONE" ] && LOG_DEBUG "$0" 0 "LAUNCH" "$(printf "Resolved launch done: '%s'" "$LAUNCH_DONE")"

# Ensure the main launcher was provided, could probably provide some visual feedback
# on the frontend side of things but we'll deal with that later...
if [ -z "$LAUNCH_EXEC" ]; then
	LOG_ERROR "$0" 0 "LAUNCH" "$(printf "Missing launcher exec in '%s'" "$ASSIGN_INI")"
	echo "Missing launcher exec in $ASSIGN_INI" >&2
else
	if [ -n "$LAUNCH_PREP" ]; then
		LOG_INFO "$0" 0 "LAUNCH" "$(printf "Running prep script '%s'" "$LAUNCH_PREP")"
		"$LAUNCH_PREP" "$NAME" "$CORE" "$ROM"
	fi

	[ "${USE_ACTIVITY:-0}" -eq 1 ] && LOG_INFO "$0" 0 "LAUNCH" "$(printf "Activity tracker start for '%s'" "$NAME")"
	[ "${USE_ACTIVITY:-0}" -eq 1 ] && /opt/muos/script/mux/track.sh "$NAME" "$CORE" "$ROM" start
	LOG_INFO "$0" 0 "LAUNCH" "$(printf "Executing launcher '%s' for '%s'" "$LAUNCH_EXEC" "$NAME")"
	"$LAUNCH_EXEC" "$NAME" "$CORE" "$ROM"
	LAUNCH_RC=$?
	if [ "$LAUNCH_RC" -eq 0 ]; then
		LOG_SUCCESS "$0" 0 "LAUNCH" "$(printf "Launcher exited successfully for '%s'" "$NAME")"
	else
		LOG_WARN "$0" 0 "LAUNCH" "$(printf "Launcher exited with code %s for '%s'" "$LAUNCH_RC" "$NAME")"
	fi
	[ "${USE_ACTIVITY:-0}" -eq 1 ] && LOG_INFO "$0" 0 "LAUNCH" "$(printf "Activity tracker stop for '%s'" "$NAME")"
	[ "${USE_ACTIVITY:-0}" -eq 1 ] && /opt/muos/script/mux/track.sh "$NAME" "$CORE" "$ROM" stop

	if [ -n "$LAUNCH_DONE" ]; then
		LOG_INFO "$0" 0 "LAUNCH" "$(printf "Running done script '%s'" "$LAUNCH_DONE")"
		"$LAUNCH_DONE" "$NAME" "$CORE" "$ROM"
	fi
fi

for RF in ra_no_load ra_autoload_once.cfg; do
	ENSURE_REMOVED "/tmp/$RF"
done

LOG_DEBUG "$0" 0 "LAUNCH" "Unsetting content environment variables"
CONTENT_UNSET

# Disable any rumble just in case some core gets stuck!
LOG_DEBUG "$0" 0 "LAUNCH" "$(printf "Disabling rumble via '%s'" "$RUMBLE")"
RUMBLE "$RUMBLE" "0.0"

# Filesystem sync
LOG_DEBUG "$0" 0 "LAUNCH" "Triggering filesystem sync"
sync &

LOG_DEBUG "$0" 0 "LAUNCH" "Restoring default CPU governor"
SET_DEFAULT_GOVERNOR

ENSURE_REMOVED "$CON_GO"
ENSURE_REMOVED "$FLT_GO"
ENSURE_REMOVED "$OVL_GO"
ENSURE_REMOVED "$RAC_GO"
ENSURE_REMOVED "$SHD_GO"

ENSURE_REMOVED "$MUOS_RUN_DIR/overlay.filter"
ENSURE_REMOVED "$MUOS_RUN_DIR/overlay.shader"

LOG_DEBUG "$0" 0 "LAUNCH" "Killing any leftover gptokeyb processes"
killall -9 "gptokeyb" "gptokeyb2" >/dev/null 2>&1

if [ "$(GET_VAR "device" "board/stick")" -eq 0 ]; then
	case "$BOARD_NAME" in
		rg*)
			LOG_DEBUG "$0" 0 "LAUNCH" "Resetting DPAD swap and LED state for rg* board"
			echo 0 >"$DPAD_SWAP"
			echo 1 >"$LED_NORMAL"
			echo 1 >"$LED_STATE"
			;;
		tui*) ENSURE_REMOVED "$DPAD_SWAP" ;;
		*) ;;
	esac
fi

SCREEN_TYPE="internal"
[ "$DEV_MODE" -eq 1 ] && SCREEN_TYPE="external"

if [ "$SCREEN_TYPE" = "internal" ]; then
	LOG_DEBUG "$0" 0 "LAUNCH" "$(printf "Switching framebuffer to internal %sx%s@32" "$SCREEN_INT_W" "$SCREEN_INT_H")"
	FB_SWITCH "$SCREEN_INT_W" "$SCREEN_INT_H" 32
else
	LOG_DEBUG "$0" 0 "LAUNCH" "$(printf "Switching framebuffer to external %sx%s@32" "$SCREEN_EXT_W" "$SCREEN_EXT_H")"
	FB_SWITCH "$SCREEN_EXT_W" "$SCREEN_EXT_H" 32
fi

if [ "$USE_SYNCTHING" -eq 1 ] &&
	[ "$SYNCTHING_AUTOSCAN" -eq 1 ] &&
	[ "$(cat "$NET_STATE")" = "up" ]; then
	LOG_INFO "$0" 0 "LAUNCH" "Triggering Syncthing folder rescan"
	SYNCTHING_API=$(sed -n 's:.*<apikey>\([^<]*\)</apikey>.*:\1:p' "$MUOS_STORE_DIR/syncthing/config.xml")
	curl -X POST -H "X-API-Key: $SYNCTHING_API" "localhost:7070/rest/db/scan"
fi

if [ -s "$PC_IP" ]; then
	LOG_INFO "$0" 0 "LAUNCH" "$(printf "Clearing Discord presence on %s" "$(cat "$PC_IP")")"
	python "$DISCORD_DIR/discord_presence_handheld.py" "$(cat "$PC_IP")" --clear
fi

LOG_INFO "$0" 0 "LAUNCH" "Content launch script complete"
