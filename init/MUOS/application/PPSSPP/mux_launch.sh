#!/bin/sh
# HELP: PPSSPP
# ICON: ppsspp
# GRID: PPSSPP

. /opt/muos/script/var/func.sh

echo app >/tmp/act_go

PPSSPP_DIR="$(GET_VAR "device" "storage/rom/mount")/MUOS/emulator/ppsspp"

HOME="$PPSSPP_DIR"
export HOME

XDG_CONFIG_HOME="$HOME/.config"
export XDG_CONFIG_HOME

SETUP_SDL_ENVIRONMENT

case "$(GET_VAR "device" "board/name")" in
	rg*)
		PPSSPP_DIR="${PPSSPP_DIR}/rg"

		sed -i '/^GraphicsBackend\|^FailedGraphicsBackends\|^DisabledGraphicsBackends/d' \
			"$PPSSPP_DIR/.config/ppsspp/PSP/SYSTEM/ppsspp.ini"

		rm -f "$PPSSPP_DIR/.config/ppsspp/PSP/SYSTEM/FailedGraphicsBackends.txt"
		;;
	tui*)
		PPSSPP_DIR="${PPSSPP_DIR}/tui"

		export LD_LIBRARY_PATH="$PPSSPP_DIR/lib:$LD_LIBRARY_PATH"
		echo 1000000 >"$(GET_VAR "device" "cpu/min_freq")"
		;;
esac

rm -rf "$PPSSPP_DIR/.config/ppsspp/PSP/SYSTEM/CACHE/"*
cd "$PPSSPP_DIR" || exit

SET_VAR "system" "foreground_process" "PPSSPP"

./PPSSPP

unset SDL_ASSERT SDL_HQ_SCALER SDL_ROTATION SDL_BLITTER_DISABLED
