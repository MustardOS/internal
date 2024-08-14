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

if [ -d "$ROMPATH/.$NAME" ]; then
	SUBFOLDER=".$NAME"
else
	SUBFOLDER="$NAME"
fi

SCVM="$ROMPATH/$SUBFOLDER/$NAME.scummvm"

cp "$ROMPATH/$NAME.scummvm" "$SCVM"

RA_CONF="$(GET_VAR "device" "storage/rom/mount")/MUOS/retroarch/retroarch.cfg"

sed -i -e '/^system_directory/d' \
	-e '/^input_remapping_directory/d' \
	-e '/^rgui_config_directory/d' \
	-e '/^savefile_directory/d' \
	-e '/^savestate_directory/d' \
	-e '/^screenshot_directory/d' "$RA_CONF"

{
	echo "system_directory = \"$(GET_VAR "global" "storage/bios")/MUOS/bios\""
	echo "input_remapping_directory = \"$(GET_VAR "global" "storage/config")/MUOS/info/config/remaps\""
	echo "rgui_config_directory = \"$(GET_VAR "global" "storage/config")/MUOS/info/config\""
	echo "savefile_directory = \"$(GET_VAR "global" "storage/save")/MUOS/save/file\""
	echo "savestate_directory = \"$(GET_VAR "global" "storage/save")/MUOS/save/state\""
	echo "screenshot_directory = \"$(GET_VAR "global" "storage/screenshot")/MUOS/screenshot\""
} >>"$RA_CONF"

retroarch -v -f -c "$RA_CONF" -L "$(GET_VAR "device" "storage/rom/mount")/MUOS/core/scummvm_libretro.so" "$SCVM" &
RA_PID=$!

wait $RA_PID
