#!/bin/sh

. /opt/muos/script/var/func.sh

ACT_GO="/tmp/act_go"
ROM_GO="/tmp/rom_go"
MUX_LAUNCHER_AUTH="/tmp/mux_launcher_auth"

if [ "$(GET_VAR "config" "settings/advanced/lock")" -eq 1 ] && [ ! -e "$MUX_LAUNCHER_AUTH" ]; then
	EXEC_MUX "" "muxpass" -t launch
	[ "$EXIT_STATUS" -eq 1 ] && touch "$MUX_LAUNCHER_AUTH"
	if [ "$EXIT_STATUS" = 2 ]; then
		rm "$ROM_GO"
		echo explore >"$ACT_GO"
		exit
	fi
fi

NAME=$(sed -n '1p' "$ROM_GO")
CORE=$(sed -n '2p' "$ROM_GO" | tr -d '\n')
ASSIGN=$(sed -n '3p' "$ROM_GO")
LAUNCH=$(sed -n '6p' "$ROM_GO")
R_DIR=$(sed -n '7p' "$ROM_GO")$(sed -n '8p' "$ROM_GO")
ROM="$R_DIR"/$(sed -n '9p' "$ROM_GO")

PC_IP="$(GET_VAR "device" "storage/rom/mount")/MUOS/discord/pc_ip.txt"
if [ -s "$PC_IP" ]; then
	python "$(GET_VAR "device" "storage/rom/mount")/MUOS/discord/discord_presence_handheld.py" "$(cat "$PC_IP")" \
		"On my $(GET_VAR "device" "board/name") with muOS $(cat /opt/muos/config/system/version)!" "Playing $NAME"
fi

rm "$ROM_GO"

GPTOKEYB_BIN=gptokeyb2
GPTOKEYB_DIR="$(GET_VAR "device" "storage/rom/mount")/MUOS/emulator/gptokeyb"
GPTOKEYB_CONTROLLERCONFIG="/usr/lib/gamecontrollerdb.txt"
GPTOKEYB_CONFDIR="/opt/muos/share/gptokeyb"

if [ -f "$GPTOKEYB_CONFDIR/$CORE.gptk" ]; then
	SDL_GAMECONTROLLERCONFIG_FILE="$GPTOKEYB_CONTROLLERCONFIG" \
		"$GPTOKEYB_DIR/$GPTOKEYB_BIN" -c "$GPTOKEYB_CONFDIR/$CORE.gptk" &
fi

GET_VAR "config" "settings/advanced/led" >"$(GET_VAR "device" "led/normal")"
GET_VAR "config" "settings/advanced/led" >/tmp/work_led_state

GOV_GO="/tmp/gov_go"
cat "$GOV_GO" >"$(GET_VAR "device" "cpu/governor")"
rm -f "$GOV_GO"

# Filesystem sync
sync &

cat /dev/zero >"$(GET_VAR "device" "screen/device")" 2>/dev/null

# Construct the path to the assigned launcher INI file based on device storage,
# assignment name ($ASSIGN), and launcher name ($LAUNCH).  This is created within
# the launching/assigning of the system and core.
ASSIGN_INI=$(printf "%s/MUOS/info/assign/%s/%s.ini" "$(GET_VAR "device" "storage/rom/mount")" "$ASSIGN" "$LAUNCH")

# Extract launcher stage commands from the INI file constructed above.
# These are either the internal launch scripts or custom scripts if it
# is a customised launch package if a user decides to create one...
LAUNCH_PREP=$(PARSE_INI "$ASSIGN_INI" "launch" "prep") # Optional preparation step before content run
LAUNCH_EXEC=$(PARSE_INI "$ASSIGN_INI" "launch" "exec") # REQUIRED main launcher to run the content
LAUNCH_DONE=$(PARSE_INI "$ASSIGN_INI" "launch" "done") # Optional cleanup script after successful run

# Ensure the main launcher was provided, could probably provide some visual feedback
# on the frontend side of things but we'll deal with that later...
if [ -z "$LAUNCH_EXEC" ]; then
	echo "Missing launcher exec in $ASSIGN_INI" >&2
else
	if [ -n "$LAUNCH_PREP" ]; then "$LAUNCH_PREP" "$NAME" "$CORE" "$ROM"; fi
	"$LAUNCH_EXEC" "$NAME" "$CORE" "$ROM"
	if [ -n "$LAUNCH_DONE" ]; then "$LAUNCH_DONE" "$NAME" "$CORE" "$ROM"; fi
fi

# Filesystem sync
sync &

SET_DEFAULT_GOVERNOR

killall -q "$GPTOKEYB_BIN"

echo 1 >"$(GET_VAR "device" "led/normal")"
echo 1 >/tmp/work_led_state

cat /dev/zero >"$(GET_VAR "device" "screen/device")" 2>/dev/null

# Disable any rumble just in case some core gets stuck!
echo 0 >"$(GET_VAR "device" "board/rumble")"

case "$(GET_VAR "device" "board/name")" in
	rg*) echo 0 >"/sys/class/power_supply/axp2202-battery/nds_pwrkey" ;;
	*) ;;
esac

SCREEN_TYPE="internal"
[ "$(GET_VAR "config" "boot/device_mode")" -eq 1 ] && SCREEN_TYPE="external"
FB_SWITCH "$(GET_VAR "device" "screen/$SCREEN_TYPE/width")" "$(GET_VAR "device" "screen/$SCREEN_TYPE/height")" 32

if [ "$(GET_VAR "config" "web/syncthing")" -eq 1 ] && [ "$(cat "$(GET_VAR "device" "network/state")")" = "up" ]; then
	SYNCTHING_API=$(sed -n 's:.*<apikey>\([^<]*\)</apikey>.*:\1:p' /run/muos/storage/syncthing/config.xml)
	curl -X POST -H "X-API-Key: $SYNCTHING_API" "localhost:7070/rest/db/scan"
fi

if [ -s "$PC_IP" ]; then
	python "$(GET_VAR "device" "storage/rom/mount")/MUOS/discord/discord_presence_handheld.py" "$(cat "$PC_IP")" --clear
fi
