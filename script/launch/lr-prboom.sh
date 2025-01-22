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

SDL_HQ_SCALER="$(GET_VAR "device" "sdl/scaler")"
SDL_ROTATION="$(GET_VAR "device" "sdl/rotation")"
SDL_BLITTER_DISABLED="$(GET_VAR "device" "sdl/blitter_disabled")"
export SDL_HQ_SCALER SDL_ROTATION SDL_BLITTER_DISABLED

SET_VAR "system" "foreground_process" "retroarch"

F_PATH=$(echo "$FILE" | awk -F'/' '{NF--; print}' OFS='/')

mkdir -p "$F_PATH/.$NAME"

PRBC="$F_PATH/.$NAME/prboom.cfg"

# Compensate for Windows wild cuntery
dos2unix -n "$F_PATH/$NAME.doom" "$F_PATH/$NAME.doom"

IWAD=$(awk -F'"' '/parentwad/ {print $2}' "$F_PATH/$NAME.doom")

cp -f "$F_PATH/$NAME.doom" "$PRBC"
cp -f "/run/muos/storage/bios/prboom.wad" "$F_PATH/.$NAME/prboom.wad"
cp -f "$F_PATH/.IWAD/$IWAD" "$F_PATH/.$NAME/$IWAD"

RA_CONF=/run/muos/storage/info/config/retroarch.cfg

# Include default button mappings from retroarch.device.cfg. (Settings in the
# retroarch.cfg will take precedence. Modified settings will save to the main
# retroarch.cfg, not the included retroarch.device.cfg.)
sed -n -e '/^#include /!p' \
	-e '$a#include "/opt/muos/device/current/control/retroarch.device.cfg"' \
	-e '$a#include "/opt/muos/device/current/control/retroarch.resolution.cfg"' \
	-i "$RA_CONF"

if [ "$(GET_VAR "kiosk" "content/retroarch")" -eq 1 ] 2>/dev/null; then
	sed -i 's/^kiosk_mode_enable = "false"$/kiosk_mode_enable = "true"/' "$RA_CONF"
else
	sed -i 's/^kiosk_mode_enable = "true"$/kiosk_mode_enable = "false"/' "$RA_CONF"
fi

retroarch -v -f -c "$RA_CONF" -L "$(GET_VAR "device" "storage/rom/mount")/MUOS/core/prboom_libretro.so" "$F_PATH/.$NAME/$IWAD" &
RA_PID=$!

wait $RA_PID
unset SDL_HQ_SCALER SDL_ROTATION SDL_BLITTER_DISABLED
