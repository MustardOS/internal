#!/bin/sh

. /opt/muos/script/var/func.sh

NAME=$1
CORE=$2
FILE=${3%/}

(
	LOG_INFO "$0" 0 "Content Launch" "DETAIL"
	LOG_INFO "$0" 0 "NAME" "$NAME"
	LOG_INFO "$0" 0 "CORE" "$CORE"
	LOG_INFO "$0" 0 "FILE" "$FILE"
) &

HOME="$(GET_VAR "device" "board/home")"
export HOME

SETUP_SDL_ENVIRONMENT

SET_VAR "system" "foreground_process" "retroarch"

RA_ARGS=$(CONFIGURE_RETROARCH)
IS_SWAP=$(DETECT_CONTROL_SWAP)

F_PATH=$(echo "$FILE" | awk -F'/' '{NF--; print}' OFS='/')
mkdir -p "$F_PATH/.$NAME"

# Compensate for Windows wild cuntery
dos2unix -n "$F_PATH/$NAME.doom" "$F_PATH/$NAME.doom"

PRBC="$F_PATH/.$NAME/prboom.cfg"
cp -f "$F_PATH/$NAME.doom" "$PRBC"
cp -f "$MUOS_STORE_DIR/bios/prboom.wad" "$F_PATH/.$NAME/prboom.wad"

IWAD=$(awk -F'"' '/parentwad/ {print $2}' "$F_PATH/$NAME.doom")
cp -f "$F_PATH/.IWAD/$IWAD" "$F_PATH/.$NAME/$IWAD"

nice --20 retroarch -v -f $RA_ARGS -L "$MUOS_SHARE_DIR/core/prboom_libretro.so" "$F_PATH/.$NAME/$IWAD"

[ "$IS_SWAP" -eq 1 ] && DETECT_CONTROL_SWAP
