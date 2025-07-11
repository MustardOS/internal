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

case "$(GET_VAR "device" "board/name")" in
	rg*)
		PPSSPP_DIR="${PPSSPP_DIR}/rg"

		if [ "$(GET_VAR "config" "boot/device_mode")" -eq 1 ]; then
			SDL_HQ_SCALER=2
			SDL_ROTATION=0
			SDL_BLITTER_DISABLED=1
		else
			SDL_HQ_SCALER="$(GET_VAR "device" "sdl/scaler")"
			SDL_ROTATION="$(GET_VAR "device" "sdl/rotation")"
			SDL_BLITTER_DISABLED="$(GET_VAR "device" "sdl/blitter_disabled")"
		fi

		export SDL_HQ_SCALER SDL_ROTATION SDL_BLITTER_DISABLED

		sed -i '/^GraphicsBackend\|^FailedGraphicsBackends\|^DisabledGraphicsBackends/d' \
			"$PPSSPP_DIR/.config/ppsspp/PSP/SYSTEM/ppsspp.ini"
   		rm -f "$PPSSPP_DIR/.config/ppsspp/PSP/SYSTEM/FailedGraphicsBackends.txt"
		;;
	tui*)
		PPSSPP_DIR="${PPSSPP_DIR}/tui"

		echo 1 >/sys/module/pvrsrvkm/parameters/DisableClockGating
		echo 1 >/sys/module/pvrsrvkm/parameters/EnableFWContextSwitch
		echo 1 >/sys/module/pvrsrvkm/parameters/EnableSoftResetContextSwitch
		echo 0 >/sys/module/pvrsrvkm/parameters/PVRDebugLevel

		export LD_LIBRARY_PATH="$PPSSPP_DIR/lib:$LD_LIBRARY_PATH"
		rm -rf "$PPSSPP_DIR/.config/ppsspp/PSP/SYSTEM/CACHE/"*

		echo 1000000 >"$(GET_VAR "device" "cpu/min_freq")"
		;;
esac


cd "$PPSSPP_DIR" || exit

SET_VAR "system" "foreground_process" "PPSSPP"

SDL_ASSERT=always_ignore SDL_GAMECONTROLLERCONFIG=$(grep "muOS-Keys" "/usr/lib/gamecontrollerdb.txt") ./PPSSPP

unset SDL_HQ_SCALER SDL_ROTATION SDL_BLITTER_DISABLED
