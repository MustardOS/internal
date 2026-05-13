#!/bin/sh
# HELP: Script Creation Utility for Maniac Mansion Virtual Machine (ScummVM)
# ICON: scummvm
# GRID: ScummVM

. /opt/muos/script/var/func.sh

APP_BIN="scummvm"
SETUP_APP "$APP_BIN" ""

SETUP_STAGE_OVERLAY

# -----------------------------------------------------------------------------

EMUDIR="$MUOS_SHARE_DIR/emulator/$APP_BIN"
CONFIG="$EMUDIR/.config/$APP_BIN/$APP_BIN.ini"
LOGPATH="$(GET_VAR "device" "storage/rom/mount")/MUOS/log/$APP_BIN.log"
SAVE="$MUOS_STORE_DIR/save/file/ScummVM-Ext"

mkdir -p "$SAVE"
chmod +x "$EMUDIR"/$APP_BIN

cd "$EMUDIR" || exit

DPAD_SWAP=$(GET_VAR "device" "board/swap")

# Switch analogue<>dpad for stickless devices
[ "$(GET_VAR "device" "board/stick")" -eq 0 ] && STICK_ROT=2 || STICK_ROT=0
case "$(GET_VAR "device" "board/name")" in
	rg*) echo "$STICK_ROT" >"$DPAD_SWAP" ;;
	tui*) [ ! -f "$DPAD_SWAP" ] && touch "$DPAD_SWAP" ;;
	*) ;;
esac

# This is needed for Bluetooth mouse to work for some unknown reason
unset SDL_BLITTER_DISABLED

HOME="$EMUDIR" ./$APP_BIN --logfile="$LOGPATH" --joystick=0 --config="$CONFIG"

# Switch analogue<>dpad back so we can navigate muX
[ "$(GET_VAR "device" "board/stick")" -eq 0 ]
case "$(GET_VAR "device" "board/name")" in
	rg*) echo 0 >"$DPAD_SWAP" ;;
	tui*) [ -f "$DPAD_SWAP" ] && rm -f "$DPAD_SWAP" ;;
	*) ;;
esac
