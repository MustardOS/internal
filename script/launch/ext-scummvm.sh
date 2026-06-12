#!/bin/sh

. /opt/muos/script/var/func.sh
. /opt/muos/script/var/launch.sh

SETUP_STAGE_OVERLAY
SETUP_SDL_ENVIRONMENT skip_blitter

SET_VAR "system" "foreground_process" "scummvm"

F_PATH=$(dirname "$FILE")
SCVM=$(tr -d '[:space:]' <"$F_PATH/$NAME.scummvm" | head -n 1)

if [ -d "$F_PATH/.$NAME" ]; then
	SUBFOLDER="/.$NAME"
elif [ -d "$F_PATH/_$NAME" ]; then
	SUBFOLDER="/_$NAME"
else
	case "$F_PATH" in
		*/"$NAME" | */"$NAME".scummvm) SUBFOLDER="" ;;
		*) SUBFOLDER="/$NAME" ;;
	esac
fi

EMUDIR="$MUOS_SHARE_DIR/emulator/scummvm"
CONFIG="$EMUDIR/.config/scummvm/scummvm.ini"
LOGPATH="$(GET_VAR "device" "storage/rom/mount")/MUOS/log/scummvm/log.txt"
SAVE="$MUOS_STORE_DIR/save/file/ScummVM-Ext"

mkdir -p "$(GET_VAR "device" "storage/rom/mount")/MUOS/log/scummvm"

mkdir -p "$SAVE"
chmod +x "$EMUDIR"/scummvm

cd "$EMUDIR" || exit

EXTRACT_GAMEID() {
	GAMEID=$(awk -v target_path="$F_PATH$SUBFOLDER" '
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

	printf "%s" "$GAMEID" >"$F_PATH/$NAME.scummvm"
}

case "$SCVM" in
	grim*)
		# Legacy Grim Fandango entry found.
		# Copy grim specific config into scummvm.ini
		GRIMINI="$(dirname "$CONFIG")/grimm.ini"
		sed -i "s|^path=.*$|path=$F_PATH$SUBFOLDER|" "$GRIMINI"
		if ! grep -q "\[grim-win\]" "$CONFIG"; then
			cat "$GRIMINI" >>"$CONFIG"
		fi
		EXTRACT_GAMEID
		;;
	*:* | "")
		# Legacy ScummVM entry found or game .scummvm file is blank.
		# Auto Detect gameid based on game files and add to scummvm.ini
		HOME="$EMUDIR" ./scummvm --logfile="$LOGPATH" --joystick=0 --config="$CONFIG" -p "$F_PATH$SUBFOLDER" --add
		EXTRACT_GAMEID
		;;
	*)
		# Game .scummvm file contains gameid entry.
		if ! grep -q "^\[$SCVM\]" "$CONFIG"; then
			# gameid missing from scummvm.ini, adding.
			HOME="$EMUDIR" ./scummvm --logfile="$LOGPATH" --joystick=0 --config="$CONFIG" -p "$F_PATH$SUBFOLDER" --add
		fi
		;;
esac

DPAD_SWAP=$(GET_VAR "device" "board/swap")

# Switch analogue<>dpad for stickless devices
[ "$(GET_VAR "device" "board/stick")" -eq 0 ] && STICK_ROT=2 || STICK_ROT=0
case "$(GET_VAR "device" "board/name")" in
	rg*) printf "%s" "$STICK_ROT" >"$DPAD_SWAP" ;;
	tui*) [ ! -f "$DPAD_SWAP" ] && touch "$DPAD_SWAP" ;;
	*) ;;
esac

# Read $SCVM again.
SCVM=$(tr -d '[:space:]' <"$F_PATH/$NAME.scummvm" | head -n 1)

# Launch game.
HOME="$EMUDIR" ./scummvm --logfile="$LOGPATH" --joystick=0 --config="$CONFIG" -p "$F_PATH$SUBFOLDER" "$SCVM"

# Reset analogue<>dpad so we can navigate muOS
RESET_DPAD_MODE
