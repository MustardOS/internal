#!/bin/sh

. /opt/muos/script/var/func.sh

NAME=$1
CORE=$2
ROM=$3

export HOME=$(GET_VAR "device" "board/home")

export SDL_HQ_SCALER="$(GET_VAR "device" "sdl/scaler")"
export SDL_ROTATION="$(GET_VAR "device" "sdl/rotation")"
export SDL_BLITTER_DISABLED="$(GET_VAR "device" "sdl/blitter_disabled")"

SET_VAR "system" "foreground_process" "retroarch"

ROMPATH=$(echo "$ROM" | awk -F'/' '{NF--; print}' OFS='/')

RA_CONF=/run/muos/storage/info/config/retroarch.cfg

if [ "$(echo "$ROM" | awk -F. '{print $NF}')" = "zip" ]; then
	retroarch -v -f -c "$RA_CONF" -L "$(GET_VAR "device" "storage/rom/mount")/MUOS/core/$CORE" "$ROM" &
	RA_PID=$!

	rm -Rf "$ROM.save"
else
	ERPC=$(sed <"$ROM.cfg" 's/[[:space:]]*$//')

	if [ -d "$ROMPATH/.$NAME" ]; then
		SUBFOLDER=".$NAME"
	else
		SUBFOLDER="$NAME"
	fi

	# Include default button mappings from retroarch.device.cfg. (Settings
	# in the retroarch.cfg will take precedence. Modified settings will save
	# to the main retroarch.cfg, not the included retroarch.device.cfg.)
	sed -n -e '/^#include /!p' \
		-e '$a#include "/opt/muos/device/current/control/retroarch.device.cfg"' \
		-i "$RA_CONF"

	retroarch -v -f -c "$RA_CONF" -L "$(GET_VAR "device" "storage/rom/mount")/MUOS/core/easyrpg_libretro.so" "$ROMPATH/$SUBFOLDER/$ERPC" &
	RA_PID=$!
fi

wait $RA_PID
