#!/bin/sh
# HELP: Dingux Commander
# ICON: dingux

. /opt/muos/script/var/func.sh

echo app >/tmp/act_go

SDL_HQ_SCALER="$(GET_VAR "device" "sdl/scaler")"
SDL_ROTATION="$(GET_VAR "device" "sdl/rotation")"
SDL_BLITTER_DISABLED="$(GET_VAR "device" "sdl/blitter_disabled")"
export SDL_HQ_SCALER SDL_ROTATION SDL_BLITTER_DISABLED

DINGUX_DIR="$(GET_VAR "device" "storage/rom/mount")/MUOS/application/.dingux"
cd "$DINGUX_DIR" || exit

SET_VAR "system" "foreground_process" "dingux"

(
	while ! pgrep -f "dingux" >/dev/null; do
		sleep 0.25
	done
	sleep 1
	evemu-event "$(GET_VAR "device" "input/ev1")" --type "$(GET_VAR "device" "input/type/dpad/right")" --code "$(GET_VAR "device" "input/code/dpad/right")" --value 1
	evemu-event "$(GET_VAR "device" "input/ev1")" --type "$(GET_VAR "device" "input/type/dpad/left")" --code "$(GET_VAR "device" "input/code/dpad/left")" --value -1
) &

SDL_ASSERT=always_ignore SDL_GAMECONTROLLERCONFIG=$(grep "muOS-Keys" "/usr/lib/gamecontrollerdb.txt") ./dingux --config "$DINGUX_DIR/dingux.cfg"

unset SDL_HQ_SCALER SDL_ROTATION SDL_BLITTER_DISABLED
