#!/bin/sh
# HELP: Dingux Commander
# ICON: dingux
# GRID: Dingux

. /opt/muos/script/var/func.sh

echo app >/tmp/act_go

GOV_GO="/tmp/gov_go"
[ -e "$GOV_GO" ] && cat "$GOV_GO" >"$(GET_VAR "device" "cpu/governor")"

CON_GO="/tmp/con_go"
SETUP_SDL_ENVIRONMENT

SET_VAR "system" "foreground_process" "dingux"

DINGUX_DIR="$(GET_VAR "device" "storage/rom/mount")/MUOS/application/Dingux Commander"
cd "$DINGUX_DIR" || exit

(
	while ! pgrep -f "dingux" >/dev/null; do
		/opt/muos/bin/toybox sleep 0.25
	done

	/opt/muos/bin/toybox sleep 1

	evemu-event "$(GET_VAR "device" "input/general")" --type "$(GET_VAR "device" "input/type/dpad/right")" --code "$(GET_VAR "device" "input/code/dpad/right")" --value 1
	evemu-event "$(GET_VAR "device" "input/general")" --type "$(GET_VAR "device" "input/type/dpad/left")" --code "$(GET_VAR "device" "input/code/dpad/left")" --value -1
) &

./dingux --config "$DINGUX_DIR/dingux.cfg"

[ -e "$GOV_GO" ] && rm -f "$GOV_GO"
[ -e "$CON_GO" ] && rm -f "$CON_GO"

SET_DEFAULT_GOVERNOR
unset SDL_ASSERT SDL_HQ_SCALER SDL_ROTATION SDL_BLITTER_DISABLED
