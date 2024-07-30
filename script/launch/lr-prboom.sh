#!/bin/sh

. /opt/muos/script/var/func.sh

. /opt/muos/script/var/device/storage.sh
. /opt/muos/script/var/device/sdl.sh

. /opt/muos/script/var/global/setting_general.sh
. /opt/muos/script/var/global/storage.sh

NAME=$1
CORE=$2
ROM=$3

export HOME=/root

export SDL_HQ_SCALER="$DC_SDL_SCALER"
export SDL_ROTATION="$DC_SDL_ROTATION"
export SDL_BLITTER_DISABLED="$DC_SDL_BLITTER_DISABLED"

echo "retroarch" >/tmp/fg_proc

ROMPATH=$(echo "$ROM" | awk -F'/' '{NF--; print}' OFS='/')

mkdir -p "$ROMPATH/.$NAME"

PRBC="$ROMPATH/.$NAME/prboom.cfg"

# Compensate for Windows wild cuntery
dos2unix -n "$ROMPATH/$NAME.doom" "$ROMPATH/$NAME.doom"

IWAD=$(awk -F'"' '/parentwad/ {print $2}' "$ROMPATH/$NAME.doom")

cp -f "$ROMPATH/$NAME.doom" "$PRBC"
cp -f "$GC_STO_CONFIG/MUOS/bios/prboom.wad" "$ROMPATH/.$NAME/prboom.wad"
cp -f "$ROMPATH/.IWAD/$IWAD" "$ROMPATH/.$NAME/$IWAD"

RA_CONF="$DC_STO_ROM_MOUNT/MUOS/retroarch/retroarch.cfg"

sed -i -e '/^system_directory/d' \
	-e '/^input_remapping_directory/d' \
	-e '/^rgui_config_directory/d' \
	-e '/^savefile_directory/d' \
	-e '/^savestate_directory/d' \
	-e '/^screenshot_directory/d' "$RA_CONF"

{
	echo "system_directory = \"$GC_STO_CONFIG/MUOS/bios\""
	echo "input_remapping_directory = \"$GC_STO_CONFIG/MUOS/info/config/remaps\""
	echo "rgui_config_directory = \"$GC_STO_CONFIG/MUOS/info/config\""
	echo "savefile_directory = \"$GC_STO_CONFIG/MUOS/save/file\""
	echo "savestate_directory = \"$GC_STO_CONFIG/MUOS/save/state\""
	echo "screenshot_directory = \"$GC_STO_CONFIG/MUOS/screenshot\""
} >>"$RA_CONF"

retroarch -v -f -c "$RA_CONF" -L "$DC_STO_ROM_MOUNT/MUOS/core/prboom_libretro.so" "$ROMPATH/.$NAME/$IWAD" &
RA_PID=$!

wait $RA_PID
