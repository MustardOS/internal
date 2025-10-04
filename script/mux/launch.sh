#!/bin/sh

. /opt/muos/script/var/func.sh

ROM_GO="/tmp/rom_go"
CON_GO="/tmp/con_go"

NAME=$(sed -n '1p' "$ROM_GO")
CORE=$(sed -n '2p' "$ROM_GO")
ASSIGN=$(sed -n '3p' "$ROM_GO")
LAUNCH=$(sed -n '6p' "$ROM_GO")
R_DIR=$(sed -n '7p' "$ROM_GO")$(sed -n '8p' "$ROM_GO")
ROM="$R_DIR"/$(sed -n '9p' "$ROM_GO")

PC_IP="$(GET_VAR "device" "storage/rom/mount")/MUOS/discord/pc_ip.txt"
if [ -s "$PC_IP" ]; then
	python "$(GET_VAR "device" "storage/rom/mount")/MUOS/discord/discord_presence_handheld.py" \
		"$(cat "$PC_IP")" "On my $(GET_VAR "device" "board/name") with MustardOS!" "Playing $NAME"
fi

rm "$ROM_GO"

case "$(GET_VAR "device" "board/name")" in
	rg*)
		GET_VAR "config" "settings/advanced/led" >"$(GET_VAR "device" "led/normal")"
		GET_VAR "config" "settings/advanced/led" >/tmp/work_led_state
		;;
	*) ;;
esac

GOV_GO="/tmp/gov_go"
cat "$GOV_GO" >"$(GET_VAR "device" "cpu/governor")"
rm -f "$GOV_GO"

cat /dev/zero >"$(GET_VAR "device" "screen/device")" 2>/dev/null

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

LAUNCH_DONE=$(PARSE_INI "$ASSIGN_INI" "launch" "done") # Optional cleanup script after successful run

# Ensure the main launcher was provided, could probably provide some visual feedback
# on the frontend side of things but we'll deal with that later...
if [ -z "$LAUNCH_EXEC" ]; then
	echo "Missing launcher exec in $ASSIGN_INI" >&2
else
	if [ -n "$LAUNCH_PREP" ]; then "$LAUNCH_PREP" "$NAME" "$CORE" "$ROM"; fi

	/opt/muos/script/mux/track.sh "$NAME" "$CORE" "$ROM" start
	"$LAUNCH_EXEC" "$NAME" "$CORE" "$ROM"
	/opt/muos/script/mux/track.sh "$NAME" "$CORE" "$ROM" stop

	if [ -n "$LAUNCH_DONE" ]; then "$LAUNCH_DONE" "$NAME" "$CORE" "$ROM"; fi
fi

for RF in ra_no_load ra_autoload_once.cfg; do
	[ -e "/tmp/$RF" ] && ENSURE_REMOVED "/tmp/$RF"
done

unset SDL_ASSERT SDL_HQ_SCALER SDL_ROTATION SDL_BLITTER_DISABLED

# Disable any rumble just in case some core gets stuck!
echo 0 >"$(GET_VAR "device" "board/rumble")"

# Filesystem sync
sync &

SET_DEFAULT_GOVERNOR
[ -e "$CON_GO" ] && rm -f "$CON_GO"

killall -9 "gptokeyb" "gptokeyb2" >/dev/null 2>&1

case "$(GET_VAR "device" "board/name")" in
	rg*)
		echo 0 >"/sys/class/power_supply/axp2202-battery/nds_pwrkey"
		echo 1 >"$(GET_VAR "device" "led/normal")"
		echo 1 >/tmp/work_led_state
		;;
	tui*)
		DPAD_FILE="/tmp/trimui_inputd/input_dpad_to_joystick"
		[ -e "$DPAD_FILE" ] && rm -f "$DPAD_FILE"
		;;
	*) ;;
esac

cat /dev/zero >"$(GET_VAR "device" "screen/device")" 2>/dev/null

SCREEN_TYPE="internal"
[ "$(GET_VAR "config" "boot/device_mode")" -eq 1 ] && SCREEN_TYPE="external"
FB_SWITCH "$(GET_VAR "device" "screen/$SCREEN_TYPE/width")" "$(GET_VAR "device" "screen/$SCREEN_TYPE/height")" 32

if [ "$(GET_VAR "config" "web/syncthing")" -eq 1 ] && [ "$(GET_VAR "config" "syncthing/auto_scan")" -eq 1 ] && [ "$(cat "$(GET_VAR "device" "network/state")")" = "up" ]; then
	SYNCTHING_API=$(sed -n 's:.*<apikey>\([^<]*\)</apikey>.*:\1:p' "$MUOS_STORE_DIR/syncthing/config.xml")
	curl -X POST -H "X-API-Key: $SYNCTHING_API" "localhost:7070/rest/db/scan"
fi

if [ -s "$PC_IP" ]; then
	python "$(GET_VAR "device" "storage/rom/mount")/MUOS/discord/discord_presence_handheld.py" "$(cat "$PC_IP")" --clear
fi
