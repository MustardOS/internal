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

RG_DPAD="/sys/class/power_supply/axp2202-battery/nds_pwrkey"
TUI_DPAD="/tmp/trimui_inputd/input_dpad_to_joystick"

mkdir -p "$SAVE"
chmod +x "$EMUDIR"/$APP_BIN

cd "$EMUDIR" || exit

# Switch analogue<>dpad for stickless devices
[ "$(GET_VAR "device" "board/stick")" -eq 0 ] && STICK_ROT=2 || STICK_ROT=0
case "$(GET_VAR "device" "board/name")" in
	rg*) echo "$STICK_ROT" >"$RG_DPAD" ;;
	tui*) [ ! -f $TUI_DPAD ] && touch $TUI_DPAD ;;
	*) ;;
esac

HOME="$EMUDIR" ./$APP_BIN --logfile="$LOGPATH" --joystick=0 --config="$CONFIG"

# Switch analogue<>dpad back so we can navigate muX
[ "$(GET_VAR "device" "board/stick")" -eq 0 ]
case "$(GET_VAR "device" "board/name")" in
	rg*) echo "0" >"$RG_DPAD" ;;
	tui*) [ -f $TUI_DPAD ] && rm $TUI_DPAD ;;
	*) ;;
esac
