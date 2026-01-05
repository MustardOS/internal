#!/bin/sh

. /opt/muos/script/var/func.sh

ROM_MOUNT="$(GET_VAR "device" "storage/rom/mount")"
BOARD_NAME="$(GET_VAR "device" "board/name")"
LED_NORMAL="$(GET_VAR "device" "led/normal")"
GOVERNOR="$(GET_VAR "device" "cpu/governor")"
SCREEN="$(GET_VAR "device" "screen/device")"
RUMBLE="$(GET_VAR "device" "board/rumble")"
NET_STATE="$(GET_VAR "device" "network/state")"

USE_ACTIVITY="$(GET_VAR "config" "settings/advanced/activity")"
USE_LEDS="$(GET_VAR "config" "settings/advanced/led")"
DEV_MODE="$(GET_VAR "config" "boot/device_mode")"
USE_SYNCTHING="$(GET_VAR "config" "web/syncthing")"
SYNCTHING_AUTOSCAN="$(GET_VAR "config" "syncthing/auto_scan")"

SCREEN_INT_W="$(GET_VAR "device" "screen/internal/width")"
SCREEN_INT_H="$(GET_VAR "device" "screen/internal/height")"
SCREEN_EXT_W="$(GET_VAR "device" "screen/external/width")"
SCREEN_EXT_H="$(GET_VAR "device" "screen/external/height")"

ROM_GO="/tmp/rom_go"
CON_GO="/tmp/con_go"
GOV_GO="/tmp/gov_go"
SAA_GO="/tmp/saa_go"
SAG_GO="/tmp/sag_go"

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

printf "%s\n%s\n%s" "$NAME" "$ASSIGN" "$CORE" >"/tmp/ovl_go"

DISCORD_DIR="$ROM_MOUNT/MUOS/discord"
PC_IP="$DISCORD_DIR/pc_ip.txt"

[ -s "$PC_IP" ] && python "$DISCORD_DIR/discord_presence_handheld.py" "$(cat "$PC_IP")" "On my $BOARD_NAME with MustardOS!" "Playing $NAME"

case "$BOARD_NAME" in
	rg*)
		echo "$USE_LEDS" >"$LED_NORMAL"
		echo "$USE_LEDS" >/tmp/work_led_state
		;;
	*) ;;
esac

cat "$GOV_GO" >"$GOVERNOR"
ENSURE_REMOVED "$GOV_GO"

ENSURE_REMOVED "$SAA_GO"
ENSURE_REMOVED "$SAG_GO"

cat /dev/zero >"$SCREEN" 2>/dev/null

# Construct the path to the assigned launcher INI file based on device storage,
# assignment name ($ASSIGN), and launcher name ($LAUNCH).  This is created within
# the launching/assigning of the system and core.
ASSIGN_INI=$(printf "$MUOS_SHARE_DIR/info/assign/%s/%s.ini" "$ASSIGN" "$LAUNCH")

# Extract launcher stage commands from the INI file constructed above.
# These are either the internal launch scripts or custom scripts if it
# is a customised launch package if a user decides to create one...
LAUNCH_PREP=$(PARSE_INI "$ASSIGN_INI" "launch" "prep") # Optional preparation step before content run

# Override launch script priority: ROM -> CORE -> DIR
OVERRIDE_ROOT="$MUOS_SHARE_DIR/info/override"

if [ -f "$OVERRIDE_ROOT/${NAME}.sh" ]; then
	LAUNCH_EXEC="$OVERRIDE_ROOT/${NAME}.sh"
elif [ -f "$OVERRIDE_ROOT/${LAUNCH}.sh" ]; then
	LAUNCH_EXEC="$OVERRIDE_ROOT/${LAUNCH}.sh"
elif [ -f "$OVERRIDE_ROOT/${R_DIR##*/}.sh" ]; then
	LAUNCH_EXEC="$OVERRIDE_ROOT/${R_DIR##*/}.sh"
else
	LAUNCH_EXEC=$(PARSE_INI "$ASSIGN_INI" "launch" "exec") # REQUIRED main launcher to run the content
fi

ENSURE_REMOVED "$ROM_GO"

LAUNCH_DONE=$(PARSE_INI "$ASSIGN_INI" "launch" "done") # Optional cleanup script after successful run

# Ensure the main launcher was provided, could probably provide some visual feedback
# on the frontend side of things but we'll deal with that later...
if [ -z "$LAUNCH_EXEC" ]; then
	echo "Missing launcher exec in $ASSIGN_INI" >&2
else
	[ -n "$LAUNCH_PREP" ] && "$LAUNCH_PREP" "$NAME" "$CORE" "$ROM"

	[ "${USE_ACTIVITY:-0}" -eq 1 ] && /opt/muos/script/mux/track.sh "$NAME" "$CORE" "$ROM" start
	"$LAUNCH_EXEC" "$NAME" "$CORE" "$ROM"
	[ "${USE_ACTIVITY:-0}" -eq 1 ] && /opt/muos/script/mux/track.sh "$NAME" "$CORE" "$ROM" stop

	[ -n "$LAUNCH_DONE" ] && "$LAUNCH_DONE" "$NAME" "$CORE" "$ROM"
fi

for RF in ra_no_load ra_autoload_once.cfg; do
	ENSURE_REMOVED "/tmp/$RF"
done

unset SDL_ASSERT SDL_HQ_SCALER SDL_ROTATION SDL_BLITTER_DISABLED

# Disable any rumble just in case some core gets stuck!
echo 0 >"$RUMBLE"

# Filesystem sync
sync &

SET_DEFAULT_GOVERNOR
[ -e "$CON_GO" ] && ENSURE_REMOVED "$CON_GO"

killall -9 "gptokeyb" "gptokeyb2" >/dev/null 2>&1

case "$BOARD_NAME" in
	rg*)
		echo 0 >"/sys/class/power_supply/axp2202-battery/nds_pwrkey"
		echo 1 >"$LED_NORMAL"
		echo 1 >/tmp/work_led_state
		;;
	tui*)
		DPAD_FILE="/tmp/trimui_inputd/input_dpad_to_joystick"
		ENSURE_REMOVED "$DPAD_FILE"
		;;
	*) ;;
esac

cat /dev/zero >"$SCREEN" 2>/dev/null

SCREEN_TYPE="internal"
[ "$DEV_MODE" -eq 1 ] && SCREEN_TYPE="external"

if [ "$SCREEN_TYPE" = "internal" ]; then
	FB_SWITCH "$SCREEN_INT_W" "$SCREEN_INT_H" 32
else
	FB_SWITCH "$SCREEN_EXT_W" "$SCREEN_EXT_H" 32
fi

if [ "$USE_SYNCTHING" -eq 1 ] &&
	[ "$SYNCTHING_AUTOSCAN" -eq 1 ] &&
	[ "$(cat "$NET_STATE")" = "up" ]; then
	SYNCTHING_API=$(sed -n 's:.*<apikey>\([^<]*\)</apikey>.*:\1:p' "$MUOS_STORE_DIR/syncthing/config.xml")
	curl -X POST -H "X-API-Key: $SYNCTHING_API" "localhost:7070/rest/db/scan"
fi

[ -s "$PC_IP" ] && python "$DISCORD_DIR/discord_presence_handheld.py" "$(cat "$PC_IP")" --clear
