#!/bin/sh

. /opt/muos/script/var/func.sh

NAME=$1
CORE=$2
FILE=${3%/}

LOG_INFO "$0" 0 "Content Launch" "DETAIL"
LOG_INFO "$0" 0 "NAME" "$NAME"
LOG_INFO "$0" 0 "CORE" "$CORE"
LOG_INFO "$0" 0 "FILE" "$FILE"

HOME="$(GET_VAR "device" "board/home")"
export HOME

if [ "$(cat "$(GET_VAR "device" "screen/hdmi")")" -eq 1 ] && [ "$(GET_VAR "device" "board/hdmi")" -eq 1 ]; then
	SDL_HQ_SCALER=2
	SDL_ROTATION=0
	SDL_BLITTER_DISABLED=1
else
	SDL_HQ_SCALER="$(GET_VAR "device" "sdl/scaler")"
	SDL_ROTATION="$(GET_VAR "device" "sdl/rotation")"
	SDL_BLITTER_DISABLED="$(GET_VAR "device" "sdl/blitter_disabled")"
fi

export SDL_HQ_SCALER SDL_ROTATION SDL_BLITTER_DISABLED

SET_VAR "system" "foreground_process" "retroarch"

F_PATH=$(echo "$FILE" | awk -F'/' '{NF--; print}' OFS='/')

RA_CONF=/run/muos/storage/info/config/retroarch.cfg

# Include default button mappings from retroarch.device.cfg. (Settings
# in the retroarch.cfg will take precedence. Modified settings will save
# to the main retroarch.cfg, not the included retroarch.device.cfg.)
sed -n -e '/^#include /!p' \
	-e '$a#include "/opt/muos/device/current/control/retroarch.device.cfg"' \
	-e '$a#include "/opt/muos/device/current/control/retroarch.resolution.cfg"' \
	-i "$RA_CONF"

if [ "$(GET_VAR "kiosk" "content/retroarch")" -eq 1 ] 2>/dev/null; then
	sed -i 's/^kiosk_mode_enable = "false"$/kiosk_mode_enable = "true"/' "$RA_CONF"
else
	sed -i 's/^kiosk_mode_enable = "true"$/kiosk_mode_enable = "false"/' "$RA_CONF"
fi

/opt/muos/script/mux/track.sh "$NAME" "$CORE" "$FILE" start

if [ "$(echo "$FILE" | awk -F. '{print $NF}')" = "zip" ]; then
	retroarch -v -f -c "$RA_CONF" -L "$(GET_VAR "device" "storage/rom/mount")/MUOS/core/$CORE" "$FILE" &
	RA_PID=$!

	rm -Rf "$FILE.save"
else
	ERPC=$(sed <"$FILE.cfg" 's/[[:space:]]*$//')

	if [ -d "$F_PATH/.$NAME" ]; then
		SUBFOLDER=".$NAME"
	else
		SUBFOLDER="$NAME"
	fi

	retroarch -v -f -c "$RA_CONF" -L "$(GET_VAR "device" "storage/rom/mount")/MUOS/core/easyrpg_libretro.so" "$F_PATH/$SUBFOLDER/$ERPC" &
	RA_PID=$!
fi

wait $RA_PID

/opt/muos/script/mux/track.sh "$NAME" "$CORE" "$FILE" stop

unset SDL_HQ_SCALER SDL_ROTATION SDL_BLITTER_DISABLED
