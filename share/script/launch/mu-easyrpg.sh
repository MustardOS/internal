#!/bin/sh

. /opt/muos/script/var/func.sh
. /opt/muos/script/var/launch.sh

SETUP_SDL_ENVIRONMENT

SET_VAR "system" "foreground_process" "muxretro"

FRESH_ARG=""
[ -e "/tmp/ra_no_load" ] && FRESH_ARG="--fresh"

if [ "$(echo "$FILE" | awk -F. '{print $NF}')" = "zip" ]; then
	LAUNCH_PATH="$FILE"
	rm -Rf "$FILE.save"
else
	F_PATH=$(dirname "$FILE")
	ERPC=$(sed <"$FILE.cfg" 's/[[:space:]]*$//')

	SUB_FOLDER="$NAME"
	[ -d "$F_PATH/.$NAME" ] && SUB_FOLDER=".$NAME"

	LAUNCH_PATH="$F_PATH/$SUB_FOLDER/$ERPC"
fi

/opt/muos/frontend/muxretro "$MUOS_SHARE_DIR/core/easyrpg_libretro.so" "$LAUNCH_PATH" $FRESH_ARG
