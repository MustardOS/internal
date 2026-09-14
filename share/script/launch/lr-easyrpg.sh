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

if [ "$(echo "$FILE" | awk -F. '{print $NF}')" = "zip" ]; then
	LAUNCH_PATH="$FILE"
	rm -Rf "$FILE.save"
else
	F_PATH=$(echo "$FILE" | awk -F'/' '{NF--; print}' OFS='/')
	ERPC=$(sed <"$FILE.cfg" 's/[[:space:]]*$//')

	SUB_FOLDER="$NAME"
	[ -d "$F_PATH/.$NAME" ] && SUB_FOLDER=".$NAME"

	LAUNCH_PATH="$F_PATH/$SUB_FOLDER/$ERPC"
fi

nice --20 retroarch -v -f $RA_ARGS -L "$MUOS_SHARE_DIR/core/easyrpg_libretro.so" "$LAUNCH_PATH"

[ "$IS_SWAP" -eq 1 ] && DETECT_CONTROL_SWAP
