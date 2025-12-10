#!/bin/sh

. /opt/muos/script/var/func.sh

NAME=$1
CORE=$2
FILE=${3%/}

LOG_INFO "$0" 0 "Content Launch" "DETAIL"
LOG_INFO "$0" 0 "NAME" "$NAME"
LOG_INFO "$0" 0 "CORE" "$CORE"
LOG_INFO "$0" 0 "FILE" "$FILE"

HOME="$(GET_VAR "device" "board/home")"
export HOME

SETUP_SDL_ENVIRONMENT skip_blitter

SET_VAR "system" "foreground_process" "scummvm"

F_PATH=$(echo "$FILE" | awk -F'/' '{NF--; print}' OFS='/')
SCVM=$(tr -d '[:space:]' <"$F_PATH/$NAME.scummvm" | head -n 1)

if [ -d "$F_PATH/.$NAME" ]; then
	SUBFOLDER=".$NAME"
elif [ -d "$F_PATH/_$NAME" ]; then
	SUBFOLDER="_$NAME"
else
	SUBFOLDER="$NAME"
fi

EMUDIR="$MUOS_SHARE_DIR/emulator/scummvm"
CONFIG="$EMUDIR/.config/scummvm/scummvm.ini"
LOGPATH="$(GET_VAR "device" "storage/rom/mount")/MUOS/log/scummvm/log.txt"
SAVE="$MUOS_STORE_DIR/save/file/ScummVM-Ext"

RG_DPAD="/sys/class/power_supply/axp2202-battery/nds_pwrkey"
TUI_DPAD="/tmp/trimui_inputd/input_dpad_to_joystick"

# Create log folder if it doesn't exist
mkdir -p "$(GET_VAR "device" "storage/rom/mount")/MUOS/log/scummvm"

mkdir -p "$SAVE"
chmod +x "$EMUDIR"/scummvm

cd "$EMUDIR" || exit

extract_gameid() {
	# Extract gameid from scummvm.ini
	GAMEID=$(awk -v target_path="$F_PATH/$SUBFOLDER" '
        /^\[.*\]/ {
            section=$0
            gsub(/^\[/, "", section)
            gsub(/\]$/, "", section)
        }
        $0 == "path=" target_path {
            print section
            exit
        }
    ' "$CONFIG")

	# Write gameid to .scummvm file.
	echo "$GAMEID" >"$F_PATH/$NAME.scummvm"
}

case "$SCVM" in
	grim*)
		# Legacy Grim Fandango entry found.
		# Copy grim specific config into scummvm.ini
		GRIMINI="$(dirname "$CONFIG")/grimm.ini"
		sed -i "s|^path=.*$|path=$F_PATH/$SUBFOLDER|" "$GRIMINI"
		if ! grep -q "\[grim-win\]" "$CONFIG"; then
			cat "$GRIMINI" >>"$CONFIG"
		fi
		extract_gameid
		;;
	*:* | "")
		# Legacy ScummVM entry found or game .scummvm file is blank.
		# Auto Detect gameid based on game files and add to scummvm.ini
		HOME="$EMUDIR" ./scummvm --logfile="$LOGPATH" --joystick=0 --config="$CONFIG" -p "$F_PATH/$SUBFOLDER" --add
		extract_gameid
		;;
	*)
		# Game .scummvm file contains gameid entry.
		if ! grep -q "^\[$SCVM\]" "$CONFIG"; then
			# gameid missing from scummvm.ini, adding.
			HOME="$EMUDIR" ./scummvm --logfile="$LOGPATH" --joystick=0 --config="$CONFIG" -p "$F_PATH/$SUBFOLDER" --add
		fi
		;;
esac

# Switch analogue<>dpad for stickless devices
[ "$(GET_VAR "device" "board/stick")" -eq 0 ] && STICK_ROT=2 || STICK_ROT=0
case "$(GET_VAR "device" "board/name")" in
	rg*) echo "$STICK_ROT" >"$RG_DPAD" ;;
	tui*) [ ! -f $TUI_DPAD ] && touch $TUI_DPAD ;;
	*) ;;
esac

# Read $SCVM again.
SCVM=$(tr -d '[:space:]' <"$F_PATH/$NAME.scummvm" | head -n 1)

# Launch game.
HOME="$EMUDIR" ./scummvm --logfile="$LOGPATH" --joystick=0 --config="$CONFIG" -p "$F_PATH/$SUBFOLDER" "$SCVM"

# Switch analogue<>dpad back so we can navigate muX
[ "$(GET_VAR "device" "board/stick")" -eq 0 ]
case "$(GET_VAR "device" "board/name")" in
	rg*) echo "0" >"$RG_DPAD" ;;
	tui*) [ -f $TUI_DPAD ] && rm $TUI_DPAD ;;
	*) ;;
esac
